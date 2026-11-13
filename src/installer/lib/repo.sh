# shellcheck shell=bash
# The installed system's [pyre] repository (ADR 0014). pacman.conf belongs to
# the admin and has no drop-in directory, so the installer appends the section
# once. It does so only when a server is known: a [pyre] section without one
# makes every pacman -Syu fail.

TARGET="${TARGET:-/mnt}"

# pyre_repo_section: the section appended to pacman.conf, after Arch's repos.
pyre_repo_section() {
  cat <<'EOF2'

# PyreOS packages (ADR 0009, ADR 0014). Listed last: [pyre] never replaces an
# Arch package. Servers: /etc/pacman.d/pyre-mirrorlist.
[pyre]
SigLevel = Required DatabaseOptional
Include = /etc/pacman.d/pyre-mirrorlist
EOF2
}

# drop_pyre_section FILE: FILE without any [pyre] section. The live medium's
# own [pyre] (the ISO's offline repository, or a development server) can reach
# the target during the install, and must not stay there.
drop_pyre_section() {
  awk '/^\[/ { skip = ($0 == "[pyre]") } !skip' "$1"
}

configure_pyre_repo() {
  local conf="$TARGET/etc/pacman.conf" mirrors="$TARGET/etc/pacman.d/pyre-mirrorlist" kept
  if [[ -n "${CFG[pyre_repo]}" ]]; then
    printf '# Written by pyre-install (pyre_repo); yours to edit.\nServer = %s\n' "${CFG[pyre_repo]}" >"$mirrors"
  fi
  if grep -q '^\[pyre\]' "$conf"; then
    kept="$(drop_pyre_section "$conf")"
    printf '%s\n' "$kept" >"$conf"
  fi
  if ! grep -q '^Server *=' "$mirrors" 2>/dev/null; then
    info "[pyre] repository: not configured (no server is known yet)"
    return 0
  fi
  pyre_repo_section >>"$conf"
  info "[pyre] repository: $(sed -n 's/^Server *= *//p' "$mirrors" | head -n 1)"
}
