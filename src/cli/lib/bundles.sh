# shellcheck shell=bash
# Bundles are pyre-bundle-<name> meta-packages in [pyre].

# bundle_check NAME: die unless NAME is a plain bundle name.
bundle_check() {
  [[ "$1" =~ ^[a-z][a-z0-9-]*$ ]] || die "not a bundle name: $1"
}

# bundle_list: "name installed|available description" per bundle in the sync db.
bundle_list() {
  local pkg desc state
  while IFS='|' read -r pkg desc; do
    state=available
    pacman -Q "$pkg" >/dev/null 2>&1 && state=installed
    printf '  %-10s %-10s %s\n' "${pkg#pyre-bundle-}" "$state" "$desc"
  done < <(pacman -Ss '^pyre-bundle-' 2>/dev/null | paste - - |
    sed -n 's|^[^/]*/\(pyre-bundle-[a-z0-9-]*\) [^ ]*.*\t *\(.*\)$|\1\|\2|p')
}
