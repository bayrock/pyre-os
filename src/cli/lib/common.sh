# shellcheck shell=bash
# Shared helpers for the pyre commands (ADR 0014).
#
# PYRE_ROOT prefixes every system path a command reads or writes, so tests can
# run against a scratch tree. It is empty on a real system.

PYRE_ROOT="${PYRE_ROOT:-}"

die() {
  printf 'pyre: %s\n' "$*" >&2
  exit 1
}

warn() {
  printf 'pyre: warning: %s\n' "$*" >&2
}

step() {
  printf '\n==> %s\n' "$*"
}

info() {
  printf '  -> %s\n' "$*"
}

# as_root CMD...: run CMD as root, through sudo when needed. Under PYRE_ROOT
# (tests) it runs CMD directly.
as_root() {
  if [[ $EUID -eq 0 || -n "$PYRE_ROOT" ]]; then
    "$@"
  else
    sudo -- "$@"
  fi
}

# command_meta FILE KEY: the value of a "# KEY: value" header line.
command_meta() {
  sed -n "s/^# $2: //p" "$1" | head -n 1
}

command_list() {
  local file
  printf 'Usage: pyre <command> [options]\n\nCommands:\n'
  for file in "$PYRE_LIB"/commands/*; do
    printf '  %-10s %s\n' "${file##*/}" "$(command_meta "$file" help)"
  done
  printf '\nRun "pyre help <command>" for its options.\n'
}

# usage FILE: print a command's usage block (its "# usage:" and following
# "#   " lines).
command_usage() {
  sed -n '/^# usage: /,/^[^#]/{s/^# usage: /Usage: /p;s/^#   /  /p}' "$1"
}

# write_atomic FILE: write stdin to FILE through a temporary file and rename.
write_atomic() {
  local file="$1" tmp
  mkdir -p -- "$(dirname -- "$file")"
  tmp="$(mktemp -- "$file.XXXXXX")"
  cat >"$tmp"
  chmod 644 -- "$tmp"
  mv -f -- "$tmp" "$file"
}

# notify SUMMARY BODY: a desktop notification when a session bus is around.
notify() {
  [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]] && command -v notify-send >/dev/null 2>&1 &&
    notify-send -a PyreOS "$1" "$2" 2>/dev/null || true
}

# booted_snapshot: the number of the root snapshot the system booted from, or
# nothing when it booted normally. A snapshot boots read-only under an overlay
# (sd-btrfs-overlayfs), so / shows "overlay"; the kernel command line names
# the snapshot subvolume.
booted_snapshot() {
  local cmdline=""
  read -r cmdline <"${PYRE_CMDLINE:-/proc/cmdline}" || true
  [[ "$cmdline" =~ subvol=/?@snapshots/([0-9]+)/snapshot ]] && printf '%s\n' "${BASH_REMATCH[1]}"
  return 0
}

# confirm PROMPT: true when the user answers yes; --yes callers skip it.
confirm() {
  local answer
  read -r -p "$1 [y/N] " answer || return 1
  [[ "$answer" == [yY] || "$answer" == [yY][eE][sS] ]]
}
