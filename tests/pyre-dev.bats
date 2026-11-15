#!/usr/bin/env bats
# pyre dev (ADR 0022): the git identity, the credential store, and the state
# of the development tools. git is real and writes into a scratch home;
# pacman, gh and rustup are stubs.

setup() {
  repo="$(cd -- "$BATS_TEST_DIRNAME/.." && pwd -P)"
  cli="$repo/src/cli"
  export HOME="$BATS_TEST_TMPDIR/home" XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/home/.config"
  export PYRE_ROOT="$BATS_TEST_TMPDIR/root" LOG="$BATS_TEST_TMPDIR/log" INSTALLED="$BATS_TEST_TMPDIR/installed"
  # Only the scratch home's settings count, not this machine's.
  export GIT_CONFIG_NOSYSTEM=1
  unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL
  helper=/usr/lib/git-core/git-credential-libsecret
  mkdir -p "$HOME" "$PYRE_ROOT${helper%/*}" "$BATS_TEST_TMPDIR/bin"
  printf '#!/bin/sh\n' >"$PYRE_ROOT$helper"
  chmod +x "$PYRE_ROOT$helper"
  : >"$LOG"
  : >"$INSTALLED"
  bin="$BATS_TEST_TMPDIR/bin"
  cat >"$bin/pacman" <<'EOF'
#!/bin/sh
case "$1" in
  -Qq) grep -qx "$2" "$INSTALLED" ;;
  *) echo "pacman $*" >> "$LOG" ;;
esac
EOF
  printf '#!/bin/sh\necho "gh $*" >> "$LOG"\n[ "$1 $2" != "auth status" ] || [ -n "$GH_SIGNED_IN" ]\n' >"$bin/gh"
  printf '#!/bin/sh\necho "rustup $*" >> "$LOG"\n[ "$1" != toolchain ] || echo "${RUST_TOOLCHAINS:-no installed toolchains}"\n' >"$bin/rustup"
  chmod +x "$bin"/*
  PATH="$bin:$PATH"
  cd "$BATS_TEST_TMPDIR"
}

pyre() {
  "$cli/pyre" "$@"
}

@test "dev git: the identity goes into ~/.config/git/config, with the keyring as the store" {
  run pyre dev git --name "Ada Lovelace" --email ada@example.org
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/.gitconfig" ]
  [ "$(git config --file "$XDG_CONFIG_HOME/git/config" user.name)" = "Ada Lovelace" ]
  [ "$(git config --file "$XDG_CONFIG_HOME/git/config" user.email)" = "ada@example.org" ]
  [ "$(git config --file "$XDG_CONFIG_HOME/git/config" credential.helper)" = "$helper" ]
}

@test "dev git: a second run changes nothing" {
  pyre dev git --name "Ada Lovelace" --email ada@example.org
  before="$(sha256sum "$XDG_CONFIG_HOME/git/config")"
  pyre dev git --name "Ada Lovelace" --email ada@example.org
  [ "$before" = "$(sha256sum "$XDG_CONFIG_HOME/git/config")" ]
}

@test "dev git: an existing ~/.gitconfig and its credential helper are kept" {
  printf '[credential]\n\thelper = store\n[alias]\n\tst = status\n' >"$HOME/.gitconfig"
  run pyre dev git --email ada@example.org
  [ "$status" -eq 0 ]
  [ ! -e "$XDG_CONFIG_HOME/git/config" ]
  [ "$(git config --global credential.helper)" = "store" ]
  [ "$(git config --global alias.st)" = "status" ]
  [ "$(git config --global user.email)" = "ada@example.org" ]
  [ -z "$(git config --global user.name)" ]
}

@test "dev git: no credential helper is named when git's keyring helper is missing" {
  rm "$PYRE_ROOT$helper"
  pyre dev git --name Ada
  [ -z "$(git config --global credential.helper)" ]
}

@test "dev git: a bad name or email is refused and nothing is written" {
  run pyre dev git --name "Ada <ada>" --email ada@example.org
  [ "$status" -ne 0 ]
  run pyre dev git --name Ada --email "not an email"
  [ "$status" -ne 0 ]
  run pyre dev git --name Ada --email "a@b@c"
  [ "$status" -ne 0 ]
  run pyre dev git --name $'Ada\nLovelace'
  [ "$status" -ne 0 ]
  run pyre dev git
  [ "$status" -ne 0 ]
  [ ! -e "$XDG_CONFIG_HOME/git/config" ]
}

@test "dev --status: says what is missing, and changes nothing" {
  run pyre dev --status
  [ "$status" -eq 0 ]
  [[ "$output" == *"Git identity  not set"* ]]
  [[ "$output" == *"Credentials   not kept"* ]]
  [[ "$output" == *"Dev tools     not installed"* ]]
  [[ "$output" == *"GitHub        not signed in"* ]]
  [[ "$output" == *"Rust          no toolchain"* ]]
  [ ! -e "$XDG_CONFIG_HOME/git/config" ]
  ! grep -q '^pacman' "$LOG"
}

@test "dev --status: says what is set up" {
  pyre dev git --name Ada --email ada@example.org
  echo pyre-bundle-dev >"$INSTALLED"
  GH_SIGNED_IN=1 RUST_TOOLCHAINS="stable-x86_64-unknown-linux-gnu (default)" run pyre dev --status
  [ "$status" -eq 0 ]
  [[ "$output" == *"Git identity  Ada <ada@example.org>"* ]]
  [[ "$output" == *"Credentials   kept in the keyring"* ]]
  [[ "$output" == *"Dev tools     installed"* ]]
  [[ "$output" == *"GitHub        signed in"* ]]
  [[ "$output" == *"Rust          stable-x86_64"* ]]
}

@test "dev: asks for the identity, and each yes does one thing" {
  # name, email, then yes to the tools, no to GitHub, yes to Rust
  run pyre dev <<<$'Ada Lovelace\nada@example.org\ny\nn\ny\n'
  [ "$status" -eq 0 ]
  [ "$(git config --global user.name)" = "Ada Lovelace" ]
  [ "$(git config --global user.email)" = "ada@example.org" ]
  grep -qx 'pacman -S --needed -- pyre-bundle-dev' "$LOG"
  ! grep -q '^gh auth login' "$LOG"
  grep -qx 'rustup default stable' "$LOG"
}

@test "dev: Enter skips every part, and a set-up machine is asked nothing" {
  run pyre dev <<<$'\n\n\n\n\n'
  [ "$status" -eq 0 ]
  [ -z "$(git config --global user.name)" ]
  ! grep -q '^pacman -S' "$LOG"
  ! grep -q '^rustup default' "$LOG"

  pyre dev git --name Ada --email ada@example.org
  echo pyre-bundle-dev >"$INSTALLED"
  : >"$LOG"
  GH_SIGNED_IN=1 RUST_TOOLCHAINS="stable (default)" run pyre dev </dev/null
  [ "$status" -eq 0 ]
  [[ "$output" != *"(Enter skips)"* && "$output" != *"[y/N]"* ]]
  [[ "$output" == *"Ada <ada@example.org>"* ]]
}
