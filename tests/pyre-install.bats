#!/usr/bin/env bats
# pyre-install: the config parser and checks, the archinstall JSON (ADR 0011),
# and the desktop steps (ADR 0013).

setup() {
  lib="$BATS_TEST_DIRNAME/../src/installer/lib"
  # shellcheck source=/dev/null
  source "$lib/common.sh"
  # shellcheck source=/dev/null
  source "$lib/config.sh"
  # shellcheck source=/dev/null
  source "$lib/archinstall.sh"
  # shellcheck source=/dev/null
  source "$lib/boot.sh"
  # shellcheck source=/dev/null
  source "$lib/desktop.sh"
  cfg="$BATS_TEST_TMPDIR/install.toml"
  cat >"$cfg" <<'EOF'
# test install
disk = "/dev/vda"
erase_disk = true
username = "pyre"
password = 'p@ss "word"'
luks_passphrase = "correct horse"   # trailing comment
hostname = "testbox"
kernel_params = "console=ttyS0,115200 console=tty0"
EOF
}

@test "config_load reads basic, literal and boolean values over the defaults" {
  config_load "$cfg"
  [ "${CFG[disk]}" = /dev/vda ]
  [ "${CFG[erase_disk]}" = true ]
  [ "${CFG[password]}" = 'p@ss "word"' ]
  [ "${CFG[luks_passphrase]}" = "correct horse" ]
  [ "${CFG[hostname]}" = testbox ]
  [ "${CFG[timezone]}" = UTC ]
  [ "${CFG[locale]}" = en_US.UTF-8 ]
  [ "${CFG[finish]}" = none ]
  config_check
}

@test "config_load rejects unknown keys and unsupported syntax" {
  printf 'colour = "red"\n' >"$BATS_TEST_TMPDIR/a.toml"
  run config_load "$BATS_TEST_TMPDIR/a.toml"
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown key: colour"* ]]

  printf 'password = "esc\\"aped"\n' >"$BATS_TEST_TMPDIR/b.toml"
  run config_load "$BATS_TEST_TMPDIR/b.toml"
  [ "$status" -ne 0 ]
  [[ "$output" == *"b.toml:1:"* ]]

  printf '[section]\n' >"$BATS_TEST_TMPDIR/c.toml"
  run config_load "$BATS_TEST_TMPDIR/c.toml"
  [ "$status" -ne 0 ]
}

@test "config_check reports every missing or malformed value" {
  config_defaults
  CFG[username]=root
  CFG[hostname]="bad_host"
  CFG[locale]="en_US"
  CFG[finish]=later
  run config_check
  [ "$status" -eq 1 ]
  [[ "$output" == *"disk is required"* ]]
  [[ "$output" == *"password is required"* ]]
  [[ "$output" == *"luks_passphrase is required"* ]]
  [[ "$output" == *"username must not be root"* ]]
  [[ "$output" == *"hostname must be a single DNS label"* ]]
  [[ "$output" == *"locale must be a UTF-8 locale"* ]]
  [[ "$output" == *"finish must be"* ]]
}

@test "only real whole disks that are not the live medium are installable" {
  installable_disk /dev/vda /dev/sr0
  installable_disk /dev/nvme0n1
  ! installable_disk /dev/sda /dev/sda
  ! installable_disk /dev/zram0
  ! installable_disk /dev/loop0
  ! installable_disk /dev/sr0
}

@test "archinstall_config lays out the ADR 0008 disk on a 40 GiB disk" {
  config_load "$cfg"
  json="$(archinstall_config $((40 * 1024 * 1024 * 1024)) 512 esp-id root-id)"
  jq -e '.disk_config.config_type == "manual_partitioning"' <<<"$json"
  jq -e '.disk_config.device_modifications[0] | .device == "/dev/vda" and .wipe == true' <<<"$json"
  parts="$(jq -c '.disk_config.device_modifications[0].partitions' <<<"$json")"
  jq -e '.[0] | .fs_type == "fat32" and .mountpoint == "/boot" and .start.value == 1
    and .size.value == 2048 and .size.unit == "MiB" and (.flags | index("esp"))' <<<"$parts"
  jq -e '.[1] | .fs_type == "btrfs" and .mountpoint == null and .start.value == 2049
    and .size.value == (40960 - 2050)
    and .mount_options == ["compress=zstd:3", "noatime"]' <<<"$parts"
  jq -e '[.[1].btrfs[] | "\(.name)=\(.mountpoint)"] ==
    ["@=/", "@home=/home", "@log=/var/log", "@pkg=/var/cache/pacman/pkg", "@snapshots=/.snapshots"]' <<<"$parts"
  jq -e '.disk_config.disk_encryption | .encryption_type == "luks"
    and .partitions == ["root-id"] and .iter_time == 2000' <<<"$json"
  jq -e '.hostname == "testbox" and .kernels == ["linux", "linux-lts"]
    and .locale_config.sys_lang == "en_US.UTF-8" and .network_config.type == "nm"
    and .packages[0] == "pyre-desktop" and (.packages | index("pipewire-jack")) and (has("bootloader_config") | not) and (has("swap") | not)' <<<"$json"
  jq -e '.services == ["firewalld.service", "greetd.service", "bluetooth.service", "power-profiles-daemon.service"]' <<<"$json"
}

@test "archinstall_config ends the last partition at least 1 MiB before the disk end" {
  config_load "$cfg"
  bytes=$((50000 * 1000 * 1000))   # not a whole number of MiB
  json="$(archinstall_config "$bytes" 4096 a b)"
  end="$(jq '.disk_config.device_modifications[0].partitions[1] | .start.value + .size.value' <<<"$json")"
  (( end <= bytes / 1048576 - 1 ))
  jq -e '.disk_config.device_modifications[0].partitions[1].size.sector_size.value == 4096' <<<"$json"
}

@test "archinstall_config refuses a disk too small for the layout" {
  config_load "$cfg"
  run archinstall_config $((8 * 1024 * 1024 * 1024)) 512 a b
  [ "$status" -ne 0 ]
  [[ "$output" == *"disk too small"* ]]
}

@test "archinstall_creds carries the user and the LUKS passphrase only" {
  config_load "$cfg"
  json="$(archinstall_creds)"
  jq -e '.encryption_password == "correct horse"' <<<"$json"
  jq -e '.users == [{username: "pyre", "!password": "p@ss \"word\"", sudo: true}]' <<<"$json"
  jq -e 'keys == ["encryption_password", "users"]' <<<"$json"
}

@test "kernel_cmdline unlocks the root volume with sd-encrypt and appends extras" {
  config_defaults
  [ "$(kernel_cmdline 1234)" = "rd.luks.name=1234=root root=/dev/mapper/root rootflags=subvol=@ rw rootfstype=btrfs zswap.enabled=0 quiet splash" ]
  CFG[kernel_params]="console=ttyS0,115200"
  [[ "$(kernel_cmdline 1234)" == *" quiet splash console=ttyS0,115200" ]]
}

@test "kernel_cmdline resumes from the swapfile only when given its offset" {
  config_defaults
  [[ "$(kernel_cmdline 1234)" != *resume* ]]
  [[ "$(kernel_cmdline 1234 "")" != *resume* ]]
  [[ "$(kernel_cmdline 1234 533760)" == *" zswap.enabled=0 resume=/dev/mapper/root resume_offset=533760 quiet splash" ]]
}

@test "hibernation defaults to off, adds the @swap subvolume, and needs room for the swapfile" {
  config_load "$cfg"
  [ "${CFG[hibernation]}" = false ]
  json="$(archinstall_config $((40 * 1024 * 1024 * 1024)) 512 a b)"
  jq -e '[.disk_config.device_modifications[0].partitions[1].btrfs[].name] | index("@swap") | not' <<<"$json"

  printf 'MemTotal:       16303476 kB\nMemFree:         1000000 kB\n' >"$BATS_TEST_TMPDIR/meminfo"
  export PYRE_MEMINFO="$BATS_TEST_TMPDIR/meminfo"
  [ "$(swap_mib)" -eq 15922 ]
  CFG[hibernation]=true
  config_check
  json="$(archinstall_config $((40 * 1024 * 1024 * 1024)) 512 a b)"
  jq -e '.disk_config.device_modifications[0].partitions[1].btrfs[-1] == {name: "@swap", mountpoint: "/swap"}' <<<"$json"
  jq -e 'has("swap") | not' <<<"$json"
  # 16 GiB for the system plus the swapfile no longer fit on a 32 GiB disk.
  run archinstall_config $((32 * 1024 * 1024 * 1024)) 512 a b
  [ "$status" -ne 0 ]
  [[ "$output" == *"disk too small: need at least $((2048 + 16384 + 15922 + 2)) MiB"* ]]

  CFG[hibernation]=maybe
  run config_check
  [ "$status" -ne 0 ]
  [[ "$output" == *"hibernation must be true or false"* ]]
}

@test "the swapfile's fstab line ranks it below zram" {
  [ "$(swapfile_fstab)" = "/swap/swapfile  none  swap  defaults,pri=0  0 0" ]
}

@test "other_esps lists FAT ESPs on other disks only" {
  config_load "$cfg"
  esp=c12a7328-f81f-11d2-ba4b-00a0c93ec93b
  lsblk_out="$(printf '%s\n' \
    'NAME="/dev/vda" PKNAME="" PARTTYPE="" FSTYPE=""' \
    "NAME=\"/dev/vda1\" PKNAME=\"/dev/vda\" PARTTYPE=\"$esp\" FSTYPE=\"vfat\"" \
    'NAME="/dev/vda2" PKNAME="/dev/vda" PARTTYPE="0fc63daf-8483-4772-8e79-3d69d8477de4" FSTYPE="crypto_LUKS"' \
    'NAME="/dev/nvme0n1p1" PKNAME="/dev/nvme0n1" PARTTYPE="de94bba4-06d1-4d40-a16a-bfd50179d6ac" FSTYPE="ntfs"' \
    'NAME="/dev/nvme0n1p2" PKNAME="/dev/nvme0n1" PARTTYPE="C12A7328-F81F-11D2-BA4B-00A0C93EC93B" FSTYPE="vfat"' \
    'NAME="/dev/nvme0n1p4" PKNAME="/dev/nvme0n1" PARTTYPE="ebd0a0a2-b9e5-4433-87c0-68b6b72699c7" FSTYPE="ntfs"' \
    "NAME=\"/dev/sdb1\" PKNAME=\"/dev/sdb\" PARTTYPE=\"$esp\" FSTYPE=\"\"")"
  [ "$(other_esps <<<"$lsblk_out")" = /dev/nvme0n1p2 ]
  [ -z "$(other_esps </dev/null)" ]
}

@test "the ISO's offline package list covers everything the installer installs" {
  offline="$BATS_TEST_DIRNAME/../iso/offline.x86_64"
  config_load "$cfg"
  mapfile -t listed < <(grep -Ev '^[[:space:]]*(#|$)' "$offline")
  mapfile -t needed < <(archinstall_config $((40 * 1024 * 1024 * 1024)) 512 a b | jq -r '.packages[], .kernels[]')
  needed+=("${BOOT_STACK[@]}" snap-pac base sudo linux-firmware mkinitcpio btrfs-progs networkmanager wpa_supplicant)
  # shellcheck disable=SC2207 # space-separated package lists
  needed+=($(sed -n 's/^packages *= *//p' "$BATS_TEST_DIRNAME"/../src/hw/rules/*.rule))
  for pkg in "${needed[@]}"; do
    [[ " ${listed[*]} " == *" $pkg "* ]] || { echo "missing from iso/offline.x86_64: $pkg"; return 1; }
  done
}

@test "autologin defaults to off and must be a boolean" {
  config_load "$cfg"
  [ "${CFG[autologin]}" = false ]
  CFG[autologin]=yes
  run config_check
  [ "$status" -ne 0 ]
  [[ "$output" == *"autologin must be true or false"* ]]
}

@test "greetd_config starts noctalia-greeter, with an initial session only for autologin" {
  config_load "$cfg"
  out="$(greetd_config)"
  grep -qx 'command = "noctalia-greeter-session"' <<<"$out"
  grep -qx 'user = "greeter"' <<<"$out"
  ! grep -q initial_session <<<"$out"

  CFG[autologin]=true
  out="$(greetd_config)"
  grep -qx '\[initial_session\]' <<<"$out"
  grep -qx 'command = "niri-session"' <<<"$out"
  grep -qx 'user = "pyre"' <<<"$out"
}

@test "only an autologin install gets the passwordless default keyring" {
  config_load "$cfg"
  calls="$BATS_TEST_TMPDIR/calls"
  in_target() { printf '%s\n' "$*" >>"$calls"; cat >/dev/null 2>&1 </dev/stdin || true; }
  seed_autologin_keyring </dev/null
  [ ! -e "$calls" ]

  CFG[autologin]=true
  seed_autologin_keyring </dev/null
  grep -qx 'runuser -u pyre -- install -d -m 700 /home/pyre/.local/share/keyrings' "$calls"
  grep -qx 'runuser -u pyre -- sh -c umask 077 && cat >"$1" sh /home/pyre/.local/share/keyrings/Default_keyring.keyring' "$calls"
  grep -qx 'runuser -u pyre -- sh -c cat >"$1" sh /home/pyre/.local/share/keyrings/default' "$calls"
  out="$(keyring_file)"
  [ "$(sed -n 1p <<<"$out")" = "[keyring]" ]
  grep -qx 'display-name=Default keyring' <<<"$out"
  grep -qEx 'ctime=[0-9]+' <<<"$out"
  ! grep -qi -e password -e secret <<<"$out"
}

@test "every user stub includes a default that pyre-desktop ships" {
  root="$BATS_TEST_DIRNAME/.."
  grep -qx 'include "/usr/share/pyre/defaults/niri/pyre.kdl"' "$root/skel/.config/niri/config.kdl"
  [ -f "$root/defaults/niri/pyre.kdl" ] && grep -qx 'include "binds.kdl"' "$root/defaults/niri/pyre.kdl"
  [ -f "$root/defaults/niri/binds.kdl" ]
  grep -qF '"/usr/share/pyre/defaults/noctalia/pyre.toml"' "$root/skel/.config/noctalia/config.toml"
  [ -f "$root/defaults/noctalia/pyre.toml" ]
  grep -qx 'include=/usr/share/pyre/defaults/foot/foot.ini' "$root/skel/.config/foot/foot.ini"
  [ -f "$root/defaults/foot/foot.ini" ]
  grep -qF '/usr/share/pyre/defaults/bash/rc' "$root/defaults/bash/bashrc"
  [ -f "$root/defaults/bash/rc" ]
}

@test "keyring_pam adds gnome-keyring after the last auth and session lines, once" {
  pam="$BATS_TEST_TMPDIR/greetd"
  printf '%s\n' '#%PAM-1.0' 'auth       required     pam_securetty.so' 'auth       include      system-local-login' \
    'account    include      system-local-login' 'session    include      system-local-login' >"$pam"
  out="$(keyring_pam "$pam")"
  [ "$(sed -n 4p <<<"$out")" = "auth       optional     pam_gnome_keyring.so" ]
  [ "$(sed -n 7p <<<"$out")" = "session    optional     pam_gnome_keyring.so auto_start" ]
  [ "$(wc -l <<<"$out")" -eq 7 ]
  printf '%s\n' "$out" >"$pam"
  [ "$(keyring_pam "$pam")" = "$out" ]
}

@test "pyre_repo accepts http(s) and file URLs only" {
  config_load "$cfg"
  for url in "http://10.0.2.2:8080/repo" "https://example.org/pyre/\$arch" "file:///srv/pyre"; do
    CFG[pyre_repo]="$url"
    config_check
  done
  for url in "ftp://x" "http://a b" "javascript:x"; do
    CFG[pyre_repo]="$url"
    run config_check
    [ "$status" -ne 0 ]
  done
}

@test "configure_pyre_repo adds [pyre] only when a server is known, once" {
  # shellcheck source=/dev/null
  source "$lib/repo.sh"
  config_load "$cfg"
  TARGET="$BATS_TEST_TMPDIR/target"
  mkdir -p "$TARGET/etc/pacman.d"
  printf '[core]\nInclude = /etc/pacman.d/mirrorlist\n' >"$TARGET/etc/pacman.conf"
  printf '# no server yet\n#Server = https://example.invalid/pyre\n' >"$TARGET/etc/pacman.d/pyre-mirrorlist"

  configure_pyre_repo
  ! grep -q '^\[pyre\]' "$TARGET/etc/pacman.conf"

  CFG[pyre_repo]="http://10.0.2.2:8080/repo"
  configure_pyre_repo
  configure_pyre_repo
  [ "$(grep -c '^\[pyre\]' "$TARGET/etc/pacman.conf")" -eq 1 ]
  grep -qx 'SigLevel = Required DatabaseOptional' "$TARGET/etc/pacman.conf"
  grep -qx 'Server = http://10.0.2.2:8080/repo' "$TARGET/etc/pacman.d/pyre-mirrorlist"
  # [core] stays first.
  [ "$(grep -m1 '^\[' "$TARGET/etc/pacman.conf")" = "[core]" ]
}

@test "configure_pyre_repo replaces a [pyre] section the live medium left in the target" {
  # shellcheck source=/dev/null
  source "$lib/repo.sh"
  config_load "$cfg"
  TARGET="$BATS_TEST_TMPDIR/target"
  mkdir -p "$TARGET/etc/pacman.d"
  printf '[core]\nInclude = /etc/pacman.d/mirrorlist\n\n[pyre]\nSigLevel = Optional TrustAll\nServer = file:///opt/pyre-offline\n\n[extra]\nInclude = /etc/pacman.d/mirrorlist\n' \
    >"$TARGET/etc/pacman.conf"
  printf '# no server yet\n' >"$TARGET/etc/pacman.d/pyre-mirrorlist"

  configure_pyre_repo
  ! grep -q -e '^\[pyre\]' -e pyre-offline "$TARGET/etc/pacman.conf"
  grep -q '^\[extra\]' "$TARGET/etc/pacman.conf"

  CFG[pyre_repo]="http://10.0.2.2:8080/repo"
  configure_pyre_repo
  [ "$(grep -c '^\[pyre\]' "$TARGET/etc/pacman.conf")" -eq 1 ]
  ! grep -q 'Optional TrustAll' "$TARGET/etc/pacman.conf"
  [ "$(grep '^\[' "$TARGET/etc/pacman.conf" | tail -n 1)" = "[pyre]" ]
}

@test "the shipped mirrorlist points [pyre] at the testing channel" {
  # shellcheck source=/dev/null
  source "$lib/repo.sh"
  config_load "$cfg"
  TARGET="$BATS_TEST_TMPDIR/target"
  mkdir -p "$TARGET/etc/pacman.d"
  printf '[core]\nInclude = /etc/pacman.d/mirrorlist\n' >"$TARGET/etc/pacman.conf"
  cp "$BATS_TEST_DIRNAME/../packages/pyre-release/pyre-mirrorlist" "$TARGET/etc/pacman.d/pyre-mirrorlist"

  configure_pyre_repo
  [ "$(grep -c '^\[pyre\]' "$TARGET/etc/pacman.conf")" -eq 1 ]
  [ "$(grep '^Server' "$TARGET/etc/pacman.d/pyre-mirrorlist")" = "Server = https://github.com/bayrock/pyre-os/releases/download/testing" ]
}

@test "restore_target_pacman_conf replaces the offline config archinstall copied, and refuses a bad one" {
  # shellcheck source=/dev/null
  source "$lib/repo.sh"
  TARGET="$BATS_TEST_TMPDIR/target"
  mkdir -p "$TARGET/etc"
  sed 's|@OFFLINE_REPO@|/opt/pyre-offline|g' "$lib/pacman-offline.conf" >"$TARGET/etc/pacman.conf"
  printf '[options]\nSigLevel = Required DatabaseOptional\n\n[core]\nInclude = /etc/pacman.d/mirrorlist\n\n[extra]\nInclude = /etc/pacman.d/mirrorlist\n' \
    >"$BATS_TEST_TMPDIR/live.conf"
  restore_target_pacman_conf "$BATS_TEST_TMPDIR/live.conf"
  ! grep -q pyre-offline "$TARGET/etc/pacman.conf"
  [ "$(grep -c '^Include = /etc/pacman.d/mirrorlist' "$TARGET/etc/pacman.conf")" -eq 2 ]

  sed 's|@OFFLINE_REPO@|/opt/pyre-offline|g' "$lib/pacman-offline.conf" >"$BATS_TEST_TMPDIR/bad.conf"
  run restore_target_pacman_conf "$BATS_TEST_TMPDIR/bad.conf"
  [ "$status" -ne 0 ]
}
