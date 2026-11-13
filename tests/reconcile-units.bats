#!/usr/bin/env bats
# Every shipped reconcile unit, run twice in a scratch tree: the first run
# converges, and the second finds the state already holds (ADR 0007).

setup() {
  repo="$BATS_TEST_DIRNAME/.."
  export PYRE_ROOT="$BATS_TEST_TMPDIR/root" HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$PYRE_ROOT" "$HOME"
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

# converge_twice UNIT: check fails, apply converges, and a second check holds
# without another apply.
converge_twice() {
  (
    # shellcheck source=/dev/null
    source "$1"
    ! check || { echo "check already passed before apply"; exit 1; }
    apply
    check || { echo "check failed after apply"; exit 1; }
    check || { echo "second check failed"; exit 1; }
  )
}

@test "every unit has an about line, a since version and check/apply" {
  for unit in "$repo"/src/cli/reconcile/*/[0-9][0-9][0-9]-*; do
    grep -q '^# about: ' "$unit" || { echo "no about: $unit"; return 1; }
    grep -qE '^since=[1-9][0-9]*$' "$unit" || { echo "no since: $unit"; return 1; }
    grep -q '^check()' "$unit" && grep -q '^apply()' "$unit" || { echo "no check/apply: $unit"; return 1; }
  done
}

@test "unit versions within a scope are unique" {
  for scope in "$repo"/src/cli/reconcile/*; do
    dups="$(sed -n 's/^since=//p' "$scope"/[0-9][0-9][0-9]-* | sort | uniq -d)"
    [ -z "$dups" ] || { echo "duplicate since in $scope: $dups"; return 1; }
  done
}

@test "system/001-snapper-home-access adds wheel to ALLOW_GROUPS, once" {
  mkdir -p "$PYRE_ROOT/etc/snapper/configs"
  conf="$PYRE_ROOT/etc/snapper/configs/home"
  printf 'SUBVOLUME="/home"\nALLOW_USERS=""\nALLOW_GROUPS="admins"\nSYNC_ACL="no"\n' >"$conf"
  # snapper stub: apply each KEY=VALUE to the config file.
  cat >"$BATS_TEST_TMPDIR/bin/snapper" <<EOF
#!/bin/bash
shift 3; shift  # --no-dbus -c home set-config
for kv in "\$@"; do sed -i "s|^\${kv%%=*}=.*|\${kv%%=*}=\"\${kv#*=}\"|" "$conf"; done
EOF
  chmod +x "$BATS_TEST_TMPDIR/bin/snapper"
  converge_twice "$repo/src/cli/reconcile/system/001-snapper-home-access"
  grep -qx 'ALLOW_GROUPS="admins wheel"' "$conf"
  grep -qx 'SYNC_ACL="yes"' "$conf"
}

@test "system/001-snapper-home-access holds when there is no home config" {
  (
    source "$repo/src/cli/reconcile/system/001-snapper-home-access"
    check
  )
}

@test "user/001-home-stubs adds missing stubs, keeps the user's files, and holds after" {
  skel="$PYRE_ROOT/etc/skel"
  mkdir -p "$skel" "$PYRE_ROOT/usr/share/pyre/defaults/bash" "$HOME/.config/foot"
  cp -r "$repo/skel/.config" "$skel/"
  cp "$repo/defaults/bash/bashrc" "$PYRE_ROOT/usr/share/pyre/defaults/bash/bashrc"
  printf 'stock bashrc\n' >"$skel/.bashrc"
  cp "$skel/.bashrc" "$HOME/.bashrc"
  printf 'mine\n' >"$HOME/.config/foot/foot.ini"

  converge_twice "$repo/src/cli/reconcile/user/001-home-stubs"
  cmp "$HOME/.config/niri/config.kdl" "$repo/skel/.config/niri/config.kdl"
  cmp "$HOME/.config/noctalia/config.toml" "$repo/skel/.config/noctalia/config.toml"
  [ "$(cat "$HOME/.config/foot/foot.ini")" = mine ]
  cmp "$HOME/.bashrc" "$repo/defaults/bash/bashrc"

  printf 'edited\n' >"$HOME/.bashrc"
  ( source "$repo/src/cli/reconcile/user/001-home-stubs"; check )
}
