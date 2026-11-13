#!/usr/bin/env bats
# pyre: the dispatcher and the reconcile engine (ADR 0014), with fixture units.

setup() {
  cli="$BATS_TEST_DIRNAME/../src/cli"
  lib="$BATS_TEST_TMPDIR/lib"
  mkdir -p "$lib"
  cp -r "$cli/lib" "$cli/commands" "$lib/"
  mkdir -p "$lib/reconcile/user"
  export PYRE_LIB="$lib" HOME="$BATS_TEST_TMPDIR/home" XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
  export PYRE_ROOT="$BATS_TEST_TMPDIR/root" LOG="$BATS_TEST_TMPDIR/applied"
  mkdir -p "$HOME" "$PYRE_ROOT"
  state="$XDG_STATE_HOME/pyre/reconcile/user"
  # snapper is not called for fresh scopes; a stub records later calls.
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  printf '#!/bin/sh\necho "snapper $*" >> "%s"\n' "$LOG" >"$BATS_TEST_TMPDIR/bin/snapper"
  chmod +x "$BATS_TEST_TMPDIR/bin/snapper"
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
