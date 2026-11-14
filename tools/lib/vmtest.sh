# shellcheck shell=bash disable=SC2154 # repo_root, tool and name come from the caller
# Shared VM test helpers for tools/test-e2e and tools/test-upgrade. Callers set
# repo_root, tool (the script name) and name (the VM under build/vm/) first.
# Every helper drives one VM: the keyboard through QMP, the serial console
# through its socket, and evidence into build/vm/<name>/.

vm_dir="$repo_root/build/vm/$name"
log="$vm_dir/serial.log"
user=pyre
password=pyre-test
passphrase=pyre-test-luks
hostname=pyreos-e2e
# The serial console carries the kernel log, and systemd logs to kmsg at info,
# so the unlock prompt and boot milestones are visible to this script. tty0
# stays /dev/console, where the LUKS passphrase is typed. Logins and probes
# use the serial console, because greetd owns tty1 on an installed system.
kernel_params="console=ttyS0,115200 console=tty0 loglevel=7 systemd.log_target=kmsg"
vm_pid=""
stage=""

die() {
  printf '%s: FAIL [%s] %s\n' "$tool" "$stage" "$*" >&2
  if [[ -S "$vm_dir/qmp.sock" ]]; then
    "$repo_root/tools/vm-ctl" --name "$name" screendump "$vm_dir/fail-$stage.png" >/dev/null 2>&1 &&
      printf '%s: screendump %s\n' "$tool" "$vm_dir/fail-$stage.png" >&2
  fi
  stop_vm
  exit 1
}

pass() {
  printf '   ok  %s\n' "$*"
}

# start_vm STAGE ARGS...: boot a new VM run with a fresh serial log. The GL
# display lets the greeter and niri start; there is no network unless a stage
# passes --net.
start_vm() {
  stage="$1"
  shift
  local net=(--no-net)
  [[ "${1:-}" == --net ]] && { net=(); shift; }
  printf '== %s\n' "$stage"
  rm -f -- "$log"
  "$repo_root/tools/run-vm" --name "$name" "${net[@]}" --display headless "$@" >/dev/null 2>&1 &
  vm_pid=$!
}

stop_vm() {
  [[ -n "$vm_pid" ]] || return 0
  "$repo_root/tools/vm-ctl" --name "$name" quit >/dev/null 2>&1 || true
  wait "$vm_pid" 2>/dev/null || true
  vm_pid=""
  [[ -f "$log" ]] && cp -- "$log" "$vm_dir/serial-$stage.log"
  return 0
}
trap stop_vm EXIT

# power_off [keyboard]: shut the guest down from the root shell and wait for
# QEMU to exit. The live ISO's root shell is on tty1, so its stage types the
# command on the keyboard; installed systems take it on the serial console.
# A guest reboot would stay inside the same QEMU process, so every stage
# powers off and the next one starts a new run on the same disk and NVRAM.
power_off() {
  local deadline=$((SECONDS + 120))
  if [[ "${1:-}" == keyboard ]]; then
    type_keys "poweroff"$'\n'
  else
    serial_keys "poweroff"$'\n'
  fi
  while kill -0 "$vm_pid" 2>/dev/null; do
    (( SECONDS < deadline )) || { echo "$tool: guest did not power off; forcing" >&2; break; }
    sleep 1
  done
  stop_vm
}

# wait_for REGEX SECONDS: wait for the serial log to match; fail on a panic.
wait_for() {
  local pattern="$1" deadline=$((SECONDS + $2))
  while (( SECONDS < deadline )); do
    grep -qaE 'Kernel panic|emergency mode|You are in emergency mode' "$log" 2>/dev/null &&
      die "the guest panicked or entered emergency mode"
    grep -qaE -- "$pattern" "$log" 2>/dev/null && return 0
    kill -0 "$vm_pid" 2>/dev/null || return 1
    sleep 1
  done
  return 1
}

type_keys() {
  "$repo_root/tools/vm-ctl" --name "$name" type "$1"
}

# serial_keys TEXT: type on the serial console (the getty or root shell there).
serial_keys() {
  "$repo_root/tools/vm-ctl" --name "$name" serial "$1"
}

send_keys() {
  "$repo_root/tools/vm-ctl" --name "$name" sendkey "$@"
}

# probe NAME 'COMMANDS': run COMMANDS in the root shell on the serial console
# and print their output.
probe() {
  local tag="$1" commands="$2"
  # Output goes through cat, so tools such as pacman see no terminal and print
  # no colors; a process substitution keeps the commands in this shell, where
  # earlier probes defined helpers.
  serial_keys "{ echo; echo E2E-BEGIN-$tag; $commands; echo E2E-END-$tag; } > >(cat) 2>&1"$'\n'
  wait_for "^E2E-END-$tag" 300 || die "probe $tag did not finish"
  sed -n "/^E2E-BEGIN-$tag/,/^E2E-END-$tag/p" "$log" | tr -d '\r' | sed '1d;$d'
}

# expect NAME 'COMMANDS' REGEX: probe and require REGEX in the output.
expect() {
  local out
  out="$(probe "$1" "$2")"
  grep -qE -- "$3" <<<"$out" || { printf '%s\n' "$out" | sed 's/^/     | /' >&2; die "$1: expected /$3/"; }
  pass "$1"
}

# Unlock LUKS when systemd-cryptsetup asks on tty0, then log in on the serial
# console and become root in a shell without line editing or echo, so typed
# probes never show up in the output.
unlock_and_login() {
  local try
  # With the boot splash (quiet splash), the kernel log may be off the serial
  # console, but the passphrase request is always echoed there.
  wait_for 'Cryptography Setup for root|Please enter passphrase for disk root' 180 ||
    die "no LUKS unlock request on the serial console"
  for try in 1 2 3; do
    sleep 3
    type_keys "$passphrase"$'\n'
    wait_for "Finished .*Cryptography Setup for root|Reached target .*Local Encrypted Volumes|$hostname login:" 30 && break
    (( try < 3 )) || die "LUKS did not unlock"
  done
  pass "LUKS unlocked"
  serial_login
}

# serial_login: at the serial getty, log in and become root in a shell
# without line editing or echo (the second half of unlock_and_login).
serial_login() {
  wait_for "$hostname login:" 180 || die "no login prompt"
  sleep 3
  serial_keys "$user"$'\n'
  sleep 2
  serial_keys "$password"$'\n'
  sleep 4
  serial_keys "sudo -s"$'\n'
  sleep 2
  serial_keys "$password"$'\n'
  sleep 2
  serial_keys "exec env TERM=dumb PS1= bash --noediting --norc"$'\n'
  sleep 1
  serial_keys "stty -echo"$'\n'
  sleep 1
  expect "root-shell" 'id -u' '^0$'
  # Keep the kernel log off the console from here on, so probe output is clean.
  probe quiet-console 'dmesg -n 1' >/dev/null
}

# install_from_iso ISO [LINE...]: an unattended offline install from ISO, with
# the fixed test settings plus each extra config LINE; then power off.
install_from_iso() {
  local iso="$1" line
  shift
  start_vm install --fresh "$iso"
  wait_for 'archiso login:' 240 || die "the live medium did not boot"
  sleep 5
  for line in 'disk = "/dev/vda"' 'erase_disk = true' "username = \"$user\"" "password = \"$password\"" \
    "luks_passphrase = \"$passphrase\"" "hostname = \"$hostname\"" "kernel_params = \"$kernel_params\"" "$@"; do
    type_keys "echo '$line' >> /root/e2e.toml"$'\n'
  done
  type_keys "pyre-install --config /root/e2e.toml > /dev/ttyS0 2>&1; echo E2E-INSTALL-EXIT=\$? > /dev/ttyS0"$'\n'
  wait_for '^E2E-INSTALL-EXIT=' 1800 || die "pyre-install did not finish"
  grep -qa '^E2E-INSTALL-EXIT=0' "$log" || die "pyre-install failed (see serial-install.log)"
  pass "pyre-install --config (offline)"
  power_off keyboard
}

# --- desktop helpers (P3) -----------------------------------------------------
# Screens come from niri's own screenshots, copied out through run-vm's 9p
# share: QMP screendump cannot read virgl scanouts, and niri needs virgl.
share="$vm_dir/share"
layout=2560x800   # two 1280x800 outputs side by side (run-vm --outputs 2)

# click X Y: left-click at X Y of the first output. The virtio tablet spans the
# whole output layout.
click() {
  "$repo_root/tools/vm-ctl" --name "$name" click --size "$layout" "$1" "$2"
}

# shot NAME: a niri screenshot of the focused output, saved as desktop-NAME.png.
shot() {
  probe "shot-$1" "shot $1" >/dev/null
  [[ -s "$share/desktop-$1.png" ]] || die "no screenshot desktop-$1.png"
  pass "screenshot desktop-$1.png"
}

# session_helpers: in the root shell, u runs a command as the user inside the
# niri session, and shot saves a screenshot to the share.
session_helpers() {
  # shellcheck disable=SC2016 # typed into the guest verbatim.
  expect session-env 'mkdir -p /mnt/share && mount -t 9p -o trans=virtio pyre-share /mnt/share; export XDG_RUNTIME_DIR=/run/user/$(id -u '"$user"') DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u '"$user"')/bus; eval "$(runuser -u '"$user"' -- systemctl --user show-environment | grep -E "^(WAYLAND_DISPLAY|NIRI_SOCKET|DISPLAY)=" | sed "s/^/export /")"; u() { runuser -u '"$user"' -- "$@"; }; shot() { local n before; before=$(ls /home/'"$user"'/Pictures/Screenshots 2>/dev/null | wc -l); u niri msg action screenshot-screen >/dev/null; for _ in 1 2 3 4 5 6 7 8 9 10; do n=$(ls /home/'"$user"'/Pictures/Screenshots | wc -l); [ "$n" -gt "$before" ] && break; sleep 0.5; done; cp "$(ls -t /home/'"$user"'/Pictures/Screenshots/*.png | head -n 1)" "/mnt/share/desktop-$1.png"; }; echo "niri=$NIRI_SOCKET"' '^niri=/run/user/[0-9]+/niri\.'
}

# noctalia_status: Noctalia's IPC status as one line of JSON.
noctalia_status() {
  probe "status-$1" 'u noctalia msg status | tr -d "[:space:]"; echo'
}

# greeter_login: once the greeter is up, log in through it with the password
# (its password field has the focus) and wait for niri and Noctalia.
# shellcheck disable=SC2016 # probes are typed into the guest verbatim.
greeter_login() {
  expect greeter-rendered 'for _ in $(seq 60); do journalctl -b -o cat _UID=$(id -u greeter) | grep -q "presented first frame" && break; sleep 1; done; journalctl -b -o cat _UID=$(id -u greeter) | grep -c "presented first frame"' '^[1-9]'
  sleep 3
  type_keys "$password"$'\n'
  expect session 'for _ in $(seq 60); do pgrep -u '"$user"' -x niri >/dev/null && pgrep -u '"$user"' -x noctalia >/dev/null && break; sleep 1; done; pgrep -u '"$user"' -x niri >/dev/null && pgrep -u '"$user"' -x noctalia >/dev/null && echo up' '^up$'
  sleep 5
  session_helpers
}
