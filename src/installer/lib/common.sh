# shellcheck shell=bash
# Shared helpers for pyre-install.

die() {
  printf 'pyre-install: %s\n' "$*" >&2
  exit 1
}

step() {
  printf '\n==> %s\n' "$*"
}

info() {
  printf '  -> %s\n' "$*"
}

# A random UUID, as archinstall's obj_id expects.
new_uuid() {
  local id
  read -r id </proc/sys/kernel/random/uuid
  printf '%s\n' "$id"
}

# True when running on the PyreOS/archiso live medium. pyre-install erases
# disks, so it refuses to run anywhere else.
on_live_medium() {
  [[ -d /run/archiso/bootmnt || -d /run/archiso/airootfs ]] &&
    grep -q 'archisobasedir=' /proc/cmdline
}

# installable_disk DISK [MEDIUM]: true for a real whole disk that is not the
# live medium. zram, loop, and optical devices are never install targets.
installable_disk() {
  case "$1" in
    /dev/zram* | /dev/loop* | /dev/sr* | /dev/ram*) return 1 ;;
  esac
  [[ -z "${2:-}" || "$1" != "$2" ]]
}
