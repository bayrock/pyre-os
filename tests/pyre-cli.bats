#!/usr/bin/env bats
# pyre: the dispatcher and the reconcile engine (ADR 0014), with fixture units.

setup() {
  cli="$BATS_TEST_DIRNAME/../src/cli"
  lib="$BATS_TEST_TMPDIR/lib"
  mkdir -p "$lib"
  cp -r "$cli/lib" "$cli/commands" "$lib/"
  mkdir -p "$lib/reconcile/user"
  # Every XDG base directory points into the test tree, never the real home.
  export PYRE_LIB="$lib" HOME="$BATS_TEST_TMPDIR/home" XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
  export XDG_CONFIG_HOME="$HOME/.config" XDG_DATA_HOME="$HOME/.local/share" XDG_CACHE_HOME="$HOME/.cache"
  export PYRE_ROOT="$BATS_TEST_TMPDIR/root" LOG="$BATS_TEST_TMPDIR/applied"
  mkdir -p "$HOME" "$PYRE_ROOT"
  state="$XDG_STATE_HOME/pyre/reconcile/user"
  # snapper is not called for fresh scopes; a stub records later calls.
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  printf '#!/bin/sh\necho "snapper $*" >> "%s"\n' "$LOG" >"$BATS_TEST_TMPDIR/bin/snapper"
  # The desktop tools the theme commands call are stubs by default, so no
  # test reaches the real session: gsettings logs, noctalia and pgrep find
  # nothing. Tests replace them as needed.
  printf '#!/bin/sh\necho "gsettings $*" >> "%s"\n' "$LOG" >"$BATS_TEST_TMPDIR/bin/gsettings"
  printf '#!/bin/sh\nexit 1\n' >"$BATS_TEST_TMPDIR/bin/noctalia"
  printf '#!/bin/sh\nexit 1\n' >"$BATS_TEST_TMPDIR/bin/pgrep"
  chmod +x "$BATS_TEST_TMPDIR/bin/snapper" "$BATS_TEST_TMPDIR/bin/gsettings" \
    "$BATS_TEST_TMPDIR/bin/noctalia" "$BATS_TEST_TMPDIR/bin/pgrep"
  unset DBUS_SESSION_BUS_ADDRESS
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

# unit NAME SINCE [FRESH]: a fixture unit that converges a marker file.
unit() {
  cat >"$lib/reconcile/user/$1" <<EOF
# about: fixture $1
since=$2
${3:+fresh=$3}
check() { [ -e "\$HOME/$1" ]; }
apply() { touch "\$HOME/$1"; echo "$1" >> "\$LOG"; }
EOF
}

pyre() {
  PYRE_LIB="$lib" "$cli/pyre" "$@"
}

@test "help lists every command; an unknown command exits 2" {
  run pyre help
  [ "$status" -eq 0 ]
  [[ "$output" == *"reconcile "* ]]
  run pyre no-such-command
  [ "$status" -eq 2 ]
}

@test "a fresh scope runs every unit except fresh=skip, then records the newest version" {
  unit 001-a 1
  unit 002-b 2 skip
  unit 003-c 3
  run pyre reconcile --user
  [ "$status" -eq 0 ]
  [ "$(cat "$LOG")" = "$(printf '001-a\n003-c')" ]
  [ "$(cat "$state")" = 3 ]
}

@test "a recorded scope runs only newer units, and a second run is a no-op" {
  unit 001-a 1
  pyre reconcile --user
  unit 002-b 2
  unit 003-c 3 skip
  run pyre reconcile --user
  [ "$status" -eq 0 ]
  [ "$(cat "$LOG")" = "$(printf '001-a\nsnapper -c home create --cleanup-algorithm number --description pyre: before user reconcile\n002-b\n003-c')" ]
  [ "$(cat "$state")" = 3 ]
  : >"$LOG"
  run pyre reconcile --user
  [ "$status" -eq 0 ]
  [[ "$output" == *"nothing to do"* ]]
  [ ! -s "$LOG" ]
}

@test "a unit whose state already holds is not applied" {
  unit 001-a 1
  touch "$HOME/001-a"
  run pyre reconcile --user
  [ "$status" -eq 0 ]
  [[ "$output" == *"001-a: ok"* ]]
  [ ! -s "$LOG" ]
}

@test "a failing unit stops the run and records nothing" {
  unit 001-a 1
  cat >"$lib/reconcile/user/002-broken" <<'EOF'
# about: never converges
since=2
check() { false; }
apply() { :; }
EOF
  unit 003-c 3
  run pyre reconcile --user
  [ "$status" -ne 0 ]
  [[ "$output" == *"stopped at 002-broken"* ]]
  [ ! -e "$state" ]
  [ ! -e "$HOME/003-c" ]
}

@test "--dry-run changes nothing" {
  unit 001-a 1
  run pyre reconcile --user --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"would apply"* ]]
  [ ! -e "$HOME/001-a" ]
  [ ! -e "$state" ]
}

@test "a corrupt state file is an error, not a fresh start" {
  unit 001-a 1
  mkdir -p "${state%/*}"
  echo garbage >"$state"
  run pyre reconcile --user
  [ "$status" -ne 0 ]
  [[ "$output" == *"corrupt reconcile state"* ]]
}

# boot_tree: a scratch root with one healthy kernel, its ESP copies pinned by
# hash in limine.conf as limine-entry-tool writes them.
boot_tree() {
  local esp="$PYRE_ROOT/boot/0123abcd/linux"
  mkdir -p "$PYRE_ROOT/usr/lib/modules/7.0.1-arch1-1" "$esp" "$PYRE_ROOT/etc/default" \
    "$PYRE_ROOT/etc/snapper/configs" "$PYRE_ROOT/var/lib/pyre/reconcile"
  echo linux >"$PYRE_ROOT/usr/lib/modules/7.0.1-arch1-1/pkgbase"
  echo kernel >"$esp/vmlinuz"
  echo initramfs >"$esp/initramfs"
  printf '/+PyreOS\n  //linux\n  module_path: boot():/0123abcd/linux/initramfs#%s\n  path: boot():/0123abcd/linux/vmlinuz#%s\n' \
    "$(b2sum "$esp/initramfs" | cut -d' ' -f1)" "$(b2sum "$esp/vmlinuz" | cut -d' ' -f1)" >"$PYRE_ROOT/boot/limine.conf"
  printf 'KERNEL_CMDLINE[default]+="root=/dev/mapper/root"\n' >"$PYRE_ROOT/etc/default/limine"
  touch "$PYRE_ROOT/etc/snapper/configs/root" "$PYRE_ROOT/etc/snapper/configs/home"
  printf '#!/bin/sh\nexit 0\n' >"$BATS_TEST_TMPDIR/bin/systemctl"
  chmod +x "$BATS_TEST_TMPDIR/bin/systemctl"
  cp -r "$cli/reconcile/system" "$lib/reconcile/"
}

@test "doctor --boot passes a healthy tree" {
  boot_tree
  run pyre doctor --boot
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok    linux 7.0.1-arch1-1: boot entry, kernel and initramfs match"* ]]
}

@test "doctor fails a stale kernel copy, a missing initramfs, and a missing entry" {
  boot_tree
  echo newer >"$PYRE_ROOT/boot/0123abcd/linux/vmlinuz"
  rm "$PYRE_ROOT/boot/0123abcd/linux/initramfs"
  run pyre doctor --boot
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL  linux: /0123abcd/linux/vmlinuz does not match its hash"* ]]
  [[ "$output" == *"FAIL  linux: /0123abcd/linux/initramfs is missing"* ]]
  : >"$PYRE_ROOT/boot/limine.conf"
  run pyre doctor --boot
  [[ "$output" == *"FAIL  no /boot/limine.conf"* ]]
  [[ "$output" == *"FAIL  linux 7.0.1-arch1-1: no boot entry"* ]]
}

@test "doctor warns about = in /etc/default/limine and about .pyre-new files" {
  boot_tree
  printf 'KERNEL_CMDLINE[default]="root=/dev/mapper/root"\n' >"$PYRE_ROOT/etc/default/limine"
  mkdir -p "$HOME/.config/foot"
  touch "$HOME/.config/foot/foot.ini" "$HOME/.config/foot/foot.ini.pyre-new"
  run pyre doctor
  [[ "$output" == *'warn  /etc/default/limine sets KERNEL_CMDLINE[default] with "="'* ]]
  [[ "$output" == *"diff $HOME/.config/foot/foot.ini $HOME/.config/foot/foot.ini.pyre-new"* ]]
}

@test "install and remove map bundle names to pyre-bundle packages, and refuse other names" {
  printf '#!/bin/sh\necho "pacman $*" >> "%s"\n' "$LOG" >"$BATS_TEST_TMPDIR/bin/pacman"
  chmod +x "$BATS_TEST_TMPDIR/bin/pacman"
  run pyre install dev media
  [ "$status" -eq 0 ]
  grep -qx 'pacman -S --needed pyre-bundle-dev pyre-bundle-media' "$LOG"
  run pyre remove office
  grep -qx 'pacman -Rs pyre-bundle-office' "$LOG"
  run pyre install '../etc'
  [ "$status" -ne 0 ]
  run pyre install 'dev;rm'
  [ "$status" -ne 0 ]
}

@test "booted_snapshot reads the snapshot number from the kernel command line" {
  source "$cli/lib/common.sh"
  echo "rd.luks.name=x=root rootflags=subvol=/@snapshots/7/snapshot rw" >"$BATS_TEST_TMPDIR/cmdline"
  [ "$(PYRE_CMDLINE="$BATS_TEST_TMPDIR/cmdline" booted_snapshot)" = 7 ]
  echo "rd.luks.name=x=root rootflags=subvol=@ rw" >"$BATS_TEST_TMPDIR/cmdline"
  [ -z "$(PYRE_CMDLINE="$BATS_TEST_TMPDIR/cmdline" booted_snapshot)" ]
}

# noctalia_stub: a fake noctalia whose color scheme lives in a file.
noctalia_stub() {
  scheme="$BATS_TEST_TMPDIR/scheme"
  printf 'builtin Noctalia\n' >"$scheme"
  cat >"$BATS_TEST_TMPDIR/bin/noctalia" <<STUB
#!/bin/bash
echo "noctalia \$*" >> "$LOG"
[ "\$1" = msg ] || exit 2
case "\$2" in
  color-scheme-get) cat "$scheme" ;;
  color-scheme-set) [ -e "$BATS_TEST_TMPDIR/down" ] && exit 1; echo "\$3 \$4" > "$scheme" ;;
  theme-mode-set|wallpaper-set) ;;
  *) exit 2 ;;
esac
STUB
  chmod +x "$BATS_TEST_TMPDIR/bin/noctalia"
  mkdir -p "$PYRE_ROOT/usr/share/pyre/themes"
  cp -r "$BATS_TEST_DIRNAME/../themes/." "$PYRE_ROOT/usr/share/pyre/themes/"
}

@test "theme list shows the installed themes and marks the active one" {
  noctalia_stub
  run pyre theme list
  [ "$status" -eq 0 ]
  [[ "$output" == "  ember"*"Ember"* ]]
  printf 'custom Ember\n' >"$scheme"
  run pyre theme list
  [[ "$output" == "* ember"* ]]
  run pyre theme current
  [ "$status" -eq 0 ]
  [ "$output" = ember ]
}

@test "theme set links the palette, tells Noctalia, and records the theme" {
  noctalia_stub
  run pyre theme set EMBER
  [ "$status" -eq 0 ]
  [ "$(readlink "$HOME/.config/noctalia/palettes/Ember.json")" = "$PYRE_ROOT/usr/share/pyre/themes/ember/palette.json" ]
  [ "$(cat "$scheme")" = "custom Ember" ]
  grep -qx 'noctalia msg theme-mode-set dark' "$LOG"
  grep -qx "noctalia msg wallpaper-set $PYRE_ROOT/usr/share/pyre/themes/ember/wallpapers/ember.jpg" "$LOG"
  [ "$(cat "$XDG_STATE_HOME/pyre/theme/current")" = ember ]
}

@test "theme set --keep-wallpaper changes the colors only" {
  noctalia_stub
  run pyre theme set --keep-wallpaper ember
  [ "$status" -eq 0 ]
  [ "$(cat "$scheme")" = "custom Ember" ]
  ! grep -q wallpaper-set "$LOG"
  run pyre theme set ember --bogus
  [ "$status" -ne 0 ]
}

@test "theme set refuses unknown names, a stopped Noctalia, and never replaces the user's palette file" {
  noctalia_stub
  run pyre theme set no-such-theme
  [ "$status" -ne 0 ]
  [[ "$output" == *"no theme named"* ]]

  touch "$BATS_TEST_TMPDIR/down"
  run pyre theme set ember
  [ "$status" -ne 0 ]
  [[ "$output" == *"is it running"* ]]
  [ ! -e "$XDG_STATE_HOME/pyre/theme/current" ]
  rm "$BATS_TEST_TMPDIR/down"

  rm "$HOME/.config/noctalia/palettes/Ember.json"
  printf 'mine\n' >"$HOME/.config/noctalia/palettes/Ember.json"
  run pyre theme set ember
  [ "$status" -ne 0 ]
  [ "$(cat "$HOME/.config/noctalia/palettes/Ember.json")" = mine ]
  run pyre theme current
  [ "$status" -ne 0 ]
}

@test "theme refresh writes the rendered colors as OSC sequences to every open foot terminal" {
  noctalia_stub
  mkdir -p "$XDG_STATE_HOME/pyre/theme" "$PYRE_ROOT/dev/pts"
  printf '# comment\n4;0 #362b24\n11 #1c1611\nbogus line\n17 #643d20\n' >"$XDG_STATE_HOME/pyre/theme/live-colors"
  : >"$PYRE_ROOT/dev/pts/3"
  : >"$PYRE_ROOT/dev/pts/7"
  # Two foot processes; the first holds a shell on pts/3, the second on pts/7
  # and a child without a terminal.
  printf '#!/bin/bash\ncase "$*" in\n  *-x\\ foot*) printf "100\\n200\\n" ;;\n  "-P 100") echo 101 ;;\n  "-P 200") printf "201\\n202\\n" ;;\nesac\n' >"$BATS_TEST_TMPDIR/bin/pgrep"
  printf '#!/bin/bash\ncase "$4" in 101) echo " pts/3" ;; 201) echo "pts/7" ;; *) echo "?" ;; esac\n' >"$BATS_TEST_TMPDIR/bin/ps"
  chmod +x "$BATS_TEST_TMPDIR/bin/pgrep" "$BATS_TEST_TMPDIR/bin/ps"

  run pyre theme refresh
  [ "$status" -eq 0 ]
  [[ "$output" == *"recolored 2 foot terminal(s)"* ]]
  want="$(printf '\033]4;0;#362b24\033\\\033]11;#1c1611\033\\\033]17;#643d20\033\\')"
  [ "$(cat "$PYRE_ROOT/dev/pts/3")" = "$want" ]
  [ "$(cat "$PYRE_ROOT/dev/pts/7")" = "$want" ]
}

@test "theme refresh is quiet and succeeds before Noctalia has rendered anything" {
  noctalia_stub
  run pyre theme refresh
  [ "$status" -eq 0 ]
  [[ "$output" == *"no rendered colors"* ]]
}

@test "theme refresh flips the GTK color scheme and restores it, and theme set migrates the old state file" {
  noctalia_stub
  printf "#!/bin/bash\necho \"gsettings \$*\" >> \"$LOG\"\n[ \"\$1\" = get ] && echo \"'prefer-dark'\"\nexit 0\n" >"$BATS_TEST_TMPDIR/bin/gsettings"
  chmod +x "$BATS_TEST_TMPDIR/bin/gsettings"
  mkdir -p "$XDG_STATE_HOME/pyre/theme"
  printf '11 #1c1611\n' >"$XDG_STATE_HOME/pyre/theme/live-colors"
  run pyre theme refresh
  [ "$status" -eq 0 ]
  [ "$(grep '^gsettings set' "$LOG" | tail -n 2 | tr '\n' '|')" = "gsettings set org.gnome.desktop.interface color-scheme prefer-light|gsettings set org.gnome.desktop.interface color-scheme prefer-dark|" ]

  rm -r "$XDG_STATE_HOME/pyre/theme"
  printf 'ember\n' >"$XDG_STATE_HOME/pyre/theme"
  run pyre theme set ember
  [ "$status" -eq 0 ]
  [ "$(cat "$XDG_STATE_HOME/pyre/theme/current")" = ember ]
}
