#!/usr/bin/env bats
# ADR 0010: the os-release hook script links only missing or Arch-default files.

setup() {
  script="$BATS_TEST_DIRNAME/../packages/pyre-release/pyre-os-release"
  export PYRE_ROOT="$BATS_TEST_TMPDIR/root"
  mkdir -p "$PYRE_ROOT/etc"
  etc="$PYRE_ROOT/etc/os-release"
}

@test "link replaces the Arch default symlink, and a second run is a no-op" {
  ln -s ../usr/lib/os-release "$etc"
  run "$script" link
  [ "$status" -eq 0 ]
  [ "$(readlink "$etc")" = ../usr/lib/pyre/os-release ]
  run "$script" link
  [ "$status" -eq 0 ]
  [ "$(readlink "$etc")" = ../usr/lib/pyre/os-release ]
}

@test "link creates the symlink when /etc/os-release is missing" {
  run "$script" link
  [ "$status" -eq 0 ]
  [ "$(readlink "$etc")" = ../usr/lib/pyre/os-release ]
}

@test "link never touches an admin-written file" {
  printf 'ID=custom\n' > "$etc"
  run "$script" link
  [ "$status" -eq 0 ]
  [ ! -L "$etc" ]
  [ "$(cat "$etc")" = ID=custom ]
}

@test "link never touches a symlink pointing elsewhere" {
  ln -s /somewhere/else "$etc"
  run "$script" link
  [ "$(readlink "$etc")" = /somewhere/else ]
}

@test "unlink restores the Arch symlink only from the PyreOS link, idempotently" {
  ln -s ../usr/lib/pyre/os-release "$etc"
  run "$script" unlink
  [ "$status" -eq 0 ]
  [ "$(readlink "$etc")" = ../usr/lib/os-release ]
  run "$script" unlink
  [ "$(readlink "$etc")" = ../usr/lib/os-release ]
}

@test "unlink leaves an admin file alone" {
  printf 'ID=custom\n' > "$etc"
  run "$script" unlink
  [ "$(cat "$etc")" = ID=custom ]
}

@test "rejects unknown actions" {
  run "$script" bogus
  [ "$status" -eq 2 ]
}
