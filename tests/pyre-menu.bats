#!/usr/bin/env bats
# pyre keys and pyre menu (ADR 0021): the keymap's own list, and the PyreOS
# menu the launcher shows. The shell, pacman and the terminal are stubs.

setup() {
  repo="$(cd -- "$BATS_TEST_DIRNAME/.." && pwd -P)"
  cli="$repo/src/cli"
  export HOME="$BATS_TEST_TMPDIR/home" XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/home/.config"
  export PYRE_ROOT="$BATS_TEST_TMPDIR/root" LOG="$BATS_TEST_TMPDIR/log" INSTALLED="$BATS_TEST_TMPDIR/installed"
  export PYRE_CMDLINE="$BATS_TEST_TMPDIR/cmdline"
  mkdir -p "$HOME" "$PYRE_ROOT/usr/share/pyre/defaults/niri" "$BATS_TEST_TMPDIR/bin"
  cp "$repo/defaults/niri/binds.kdl" "$PYRE_ROOT/usr/share/pyre/defaults/niri/"
  cp -r "$repo/src/cli/menu" "$PYRE_ROOT/usr/share/pyre/menu"
  cp -r "$repo/themes" "$PYRE_ROOT/usr/share/pyre/themes"
  echo "root=/dev/mapper/root rw" >"$PYRE_CMDLINE"
  printf 'foot\nmpv\npyre-bundle-dev\n' >"$INSTALLED"
  : >"$LOG"
  bin="$BATS_TEST_TMPDIR/bin"
  # Every tool a row can reach records its call; none reaches the real system.
  for tool in noctalia foot xdg-open systemctl fastfetch; do
    printf '#!/bin/sh\necho "%s $*" >> "$LOG"\n' "$tool" >"$bin/$tool"
  done
  cat >"$bin/pacman" <<'EOF'
#!/bin/sh
case "$1" in
  -Qq) cat "$INSTALLED" ;;
  -Ss) printf 'pyre/pyre-bundle-dev 0.1.0-1\n    PyreOS bundle: development tools\npyre/pyre-bundle-media 0.1.0-1\n    PyreOS bundle: media creation\n' ;;
  -Si) [ -z "$NO_LISTS" ] ;;
  *) echo "pacman $*" >> "$LOG" ;;
esac
EOF
  printf '#!/bin/sh\necho "${CONNECTIVITY:-full}"\n' >"$bin/nmcli"
  chmod +x "$bin"/*
  PATH="$bin:$PATH"
}

pyre() {
  "$cli/pyre" "$@"
}

# --- pyre keys ----------------------------------------------------------------------

@test "keys: every default bind has a description, and no key is bound twice" {
  binds="$repo/defaults/niri/binds.kdl"
  run pyre keys --list
  [ "$status" -eq 0 ]
  # One line per bind: a line of the file that binds a key carries a title.
  [ "${#lines[@]}" -eq "$(grep -c '^ *[A-Za-z0-9_+]* .*{.*}$' "$binds")" ]
  [ "${#lines[@]}" -eq "$(grep -c 'hotkey-overlay-title="[^"]\+" {' "$binds")" ]
  [ -z "$(printf '%s\n' "${lines[@]}" | cut -f1 | sort | uniq -d)" ]
  [[ "$output" == *$'Super + K\tKeybindings'* ]]
  [[ "$output" == *$'Super + Space\tLauncher'* ]]
}

@test "keys: a bind in the user's config replaces the default's and new ones are added" {
  mkdir -p "$XDG_CONFIG_HOME/niri"
  cat >"$XDG_CONFIG_HOME/niri/config.kdl" <<'EOF'
include "/usr/share/pyre/defaults/niri/pyre.kdl"
binds {
    Mod+K hotkey-overlay-title="My own" { spawn "foot"; }
    Mod+Shift+F10 { spawn "foot" "htop"; }
}
EOF
  run pyre keys --list
  [ "$status" -eq 0 ]
  [[ "$output" == *$'Super + K\tMy own'* ]]
  [[ "$output" != *$'Super + K\tKeybindings'* ]]
  [[ "$output" == *$'Super + Shift + F10\tspawn "foot" "htop"'* ]]
}

@test "keys: without a shell to show it, the list is printed" {
  printf '#!/bin/sh\nexit 1\n' >"$bin/noctalia"
  run pyre keys
  [ "$status" -eq 0 ]
  [[ "$output" == *$'Super + K\tKeybindings'* ]]
}

@test "keys: the Keys page lists exactly what the keymap binds" {
  run "$repo/tools/keys-doc" --check
  echo "$output"
  [ "$status" -eq 0 ]
}

# --- pyre menu ----------------------------------------------------------------------

@test "menu: the data files hold no quote, backslash or shell syntax, and titles are unique" {
  for file in "$repo"/src/cli/menu/*.tsv; do
    run grep -n -e "'" -e '\\' -e '`' -e '\$' -e ';' -e '|' -e '&' "$file"
    [ "$status" -eq 1 ]
  done
  run pyre menu --list
  [ "$status" -eq 0 ]
  [ -z "$(printf '%s\n' "${lines[@]}" | cut -f1 | sort | uniq -d)" ]
  # Every row of menu.tsv has four fields and a verb pyre menu knows.
  run awk -F'\t' '/^#/ || /^$/ { next }
    NF != 4 || $3 !~ /^(term|launcher|search|aur|install-list|remove-list|theme-list|vendor|panel|nightlight|settings|edit|guide|welcome|url|session|hibernate)$/ { print "bad row: " $0; bad = 1 }
    END { exit bad }' "$repo/src/cli/menu/menu.tsv"
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "menu: lists the static rows, the themes, and apps by whether they are installed" {
  run pyre menu --list
  [ "$status" -eq 0 ]
  [[ "$output" == *$'Update › Update the system\t'* ]]
  for theme in Ember Birch Evergreen Frost; do [[ "$output" == *"Theme › $theme"$'\t'* ]]; done
  # mpv and the dev bundle are installed; the image viewer and media bundle are not.
  [[ "$output" == *$'Remove › Video player\t'* && "$output" != *"Install › Video player"* ]]
  [[ "$output" == *$'Install › Image viewer\t'* && "$output" != *"Remove › Image viewer"* ]]
  [[ "$output" == *$'Remove › dev bundle\tdevelopment tools'* ]]
  [[ "$output" == *$'Install › media bundle\tmedia creation'* ]]
  # No resume= on the command line and no AUR helper: neither row is offered.
  [[ "$output" != *Hibernate* && "$output" != *AUR* ]]
}

@test "menu: hibernate and the AUR search appear when the machine has them" {
  echo "root=/dev/mapper/root resume=/dev/mapper/root resume_offset=1" >"$PYRE_CMDLINE"
  mkdir -p "$PYRE_ROOT/usr/bin"
  printf '#!/bin/sh\n' >"$PYRE_ROOT/usr/bin/paru"; chmod +x "$PYRE_ROOT/usr/bin/paru"
  run pyre menu --list
  [[ "$output" == *$'System › Hibernate\t'* ]]
  [[ "$output" == *$'Install › Find in the AUR…\t'* ]]
}

@test "menu: picking a row does what its verb says, with the argument as one word" {
  pyre menu --pick $'Style › Wallpaper\tPick a wallpaper'
  pyre menu --pick "Style › Night light"
  pyre menu --pick "System › Lock"
  pyre menu --pick "Learn › Keybindings"
  pyre menu --pick "Learn › Arch Wiki"
  sleep 0.3
  grep -qx 'noctalia msg panel-open wallpaper' "$LOG"
  grep -qx 'noctalia msg nightlight-force-toggle' "$LOG"
  grep -qx 'noctalia msg session lock' "$LOG"
  grep -qx 'noctalia msg panel-open launcher /keys ' "$LOG"
  grep -qx 'xdg-open https://wiki.archlinux.org' "$LOG"
}

@test "menu: installs, updates and removals open the floating terminal on pyre menu --run" {
  pyre menu --pick "Install › Image viewer"
  pyre menu --pick "Remove › Video player"
  pyre menu --pick "Update › Update the system"
  sleep 0.3
  grep -q '^foot --app-id=pyre.menu --title=PyreOS -- .*/pyre menu --run install imv$' "$LOG"
  grep -q '^foot --app-id=pyre.menu .* menu --run remove mpv$' "$LOG"
  grep -q '^foot --app-id=pyre.menu .* menu --run term update$' "$LOG"
}

@test "menu: a row it did not list is refused, whatever it says" {
  for row in "Install › nothing" 'Update › Update the system; touch pwned' "\$(touch pwned)" "'; touch pwned; '" ""; do
    run pyre menu --pick "$row"
    [ "$status" -ne 0 ]
  done
  [ ! -s "$LOG" ]
  [ ! -e pwned ]
}

@test "menu --run: installs and removes only what the catalog or a bundle names" {
  run pyre menu --run install imv </dev/null
  [ "$status" -eq 0 ]
  grep -qx 'pacman -S --needed -- imv' "$LOG"
  run pyre menu --run install "docker docker-compose docker-buildx" </dev/null
  grep -qx 'pacman -S --needed -- docker docker-compose docker-buildx' "$LOG"
  run pyre menu --run remove pyre-bundle-dev </dev/null
  grep -qx 'pacman -Rs -- pyre-bundle-dev' "$LOG"
  : >"$LOG"
  for arg in "linux" "imv linux" "imv --overwrite=*" "docker"; do
    run pyre menu --run install "$arg" </dev/null
    [ "$status" -ne 0 ]
    [[ "$output" == *"not in the catalog"* ]]
    run pyre menu --run remove "$arg" </dev/null
    [ "$status" -ne 0 ]
  done
  run pyre menu --run term "update; reboot" </dev/null
  [ "$status" -ne 0 ]
  [ ! -s "$LOG" ]
}

@test "menu: Docker offers to start once it is installed, and says what the group means" {
  run pyre menu --run install "docker docker-compose docker-buildx" <<<"y"
  [ "$status" -eq 0 ]
  grep -qx 'systemctl enable --now docker.socket' "$LOG"
  [[ "$output" == *"usermod -aG docker"* && "$output" == *"can act as root"* ]]
  : >"$LOG"
  run pyre menu --run install "docker docker-compose docker-buildx" <<<"n"
  [ "$status" -eq 0 ]
  ! grep -q '^systemctl' "$LOG"
  run pyre menu --run install imv </dev/null
  [[ "$output" != *Docker* ]]
}

# A curl that "downloads" an installer: one that puts a claude command in the
# home, as the real one does.
fake_installer() {
  cat >"$bin/curl" <<'EOF'
#!/bin/sh
echo "curl $*" >> "$LOG"
[ -z "$CURL_FAILS" ] || exit 22
while [ "$1" != -o ]; do shift; done
printf 'echo "installer ran as $(id -un)" >> "$LOG"\nmkdir -p "$HOME/.local/bin" "$HOME/.local/share/claude/versions"\n: > "$HOME/.local/bin/claude"\n' > "$2"
EOF
  chmod +x "$bin/curl"
}

@test "menu: the vendor row installs Claude Code only after a yes, by the published installer" {
  fake_installer
  run pyre menu --list
  [[ "$output" == *$'Install › Claude Code\t'*"(proprietary)"* && "$output" != *"Remove › Claude Code"* ]]
  pyre menu --pick "Install › Claude Code"
  sleep 0.3
  grep -q '^foot --app-id=pyre.menu .* menu --run vendor claude$' "$LOG"
  : >"$LOG"
  run pyre menu --run vendor claude <<<"n"
  [ "$status" -ne 0 ]
  [[ "$output" == *"proprietary software from Anthropic"* && "$output" == *"https://claude.ai/install.sh"* ]]
  [ ! -s "$LOG" ]
  run pyre menu --run vendor claude <<<"y"
  [ "$status" -eq 0 ]
  grep -q '^curl -fsSL -o .* -- https://claude.ai/install.sh$' "$LOG"
  grep -qx "installer ran as $(id -un)" "$LOG"
  ! grep -q -e '^pacman' -e sudo "$LOG"
  [ -e "$HOME/.local/bin/claude" ]
}

@test "menu: an installed Claude Code is a Remove row, and removal keeps the settings" {
  mkdir -p "$HOME/.local/bin" "$HOME/.local/share/claude/versions" "$HOME/.claude"
  : >"$HOME/.local/bin/claude"
  run pyre menu --list
  [[ "$output" == *$'Remove › Claude Code\t'* && "$output" != *"Install › Claude Code"* ]]
  pyre menu --pick "Remove › Claude Code"
  sleep 0.3
  grep -q '^foot --app-id=pyre.menu .* menu --run vendor-remove claude$' "$LOG"
  run pyre menu --run vendor-remove claude <<<"y"
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/.local/bin/claude" ] && [ ! -e "$HOME/.local/share/claude" ]
  [ -d "$HOME/.claude" ]
}

@test "menu: a failed download runs nothing, offline says so, and no other vendor exists" {
  fake_installer
  CURL_FAILS=1 run pyre menu --run vendor claude <<<"y"
  [ "$status" -ne 0 ]
  [[ "$output" == *"could not be fetched"* ]]
  ! grep -q '^installer ran' "$LOG"
  : >"$LOG"
  CONNECTIVITY=none run pyre menu --run vendor claude <<<"y"
  [ "$status" -ne 0 ]
  [[ "$output" == *"This machine is offline"* ]]
  [ ! -s "$LOG" ]
  for name in "" other "claude; touch pwned" "https://example.org/x.sh"; do
    run pyre menu --run vendor "$name" <<<"y"
    [ "$status" -ne 0 ]
    [[ "$output" == *"no vendor installer named"* ]]
  done
  [ ! -s "$LOG" ] && [ ! -e pwned ]
}

@test "menu: Setup › Development runs pyre dev in the terminal" {
  pyre menu --pick "Setup › Development"
  sleep 0.3
  grep -q '^foot --app-id=pyre.menu .* menu --run term dev$' "$LOG"
}

@test "menu --run: offline, an install says so and pacman is not called" {
  CONNECTIVITY=none run pyre menu --run install imv </dev/null
  [ "$status" -ne 0 ]
  [[ "$output" == *"This machine is offline"* ]]
  [ ! -s "$LOG" ]
}

@test "menu --run: without package lists, an install offers an update first" {
  NO_LISTS=1 run pyre menu --run install imv <<<"n"
  [ "$status" -ne 0 ]
  [[ "$output" == *"no package lists yet"* ]]
  [ ! -s "$LOG" ]
}

@test "menu: every catalog row names packages by plain package names" {
  while IFS=$'\t' read -r name desc pkgs; do
    [[ -n "$name" && -n "$desc" && "$pkgs" =~ ^[a-z0-9][a-z0-9+._-]*(\ [a-z0-9][a-z0-9+._-]*)*$ ]] ||
      { echo "bad catalog row: $name"; return 1; }
  done < <(grep -v -e '^#' -e '^$' "$repo/src/cli/menu/catalog.tsv")
}

@test "keys: every key the guide, the skill and the welcome panel name is one the keymap binds" {
  bound="$(pyre keys --list | cut -f1)"
  found=0
  # A key in bold, "**Super + K**", or the welcome panel's quoted "Super + K".
  # Families ("Super + 1" to 0, arrows) and the unbound copy and paste keys
  # are written differently or named as unbound, and are skipped.
  while IFS= read -r key; do
    case "$key" in
      "Super + C" | "Super + V" | "Super + X" | "Super + A" | "Super + [" | "Super + ]") continue ;;
      "Ctrl + Alt + F"[0-9]*) continue ;; # a virtual console, which niri switches to itself
      *[!\ -~]*) continue ;;
    esac
    grep -qxF -- "$key" <<<"$bound" || { echo "not in the keymap: $key"; return 1; }
    found=$((found + 1))
  done < <(grep -rhoE '(\*\*|")((Super|Ctrl|Alt|Shift) \+ [^*"]+|Print)(\*\*|")' \
    "$repo"/docs/guide/0[1345678]*.md "$repo/docs/KEYBINDINGS.md" "$repo"/skills/pyre "$repo/src/desktop/welcome/welcome.luau" |
    sed -E 's/^(\*\*|")//; s/(\*\*|")$//' | grep -v -e '^Ctrl + [CV]$' -e '^Ctrl + Shift + C$' | sort -u)
  [ "$found" -ge 15 ]
}
