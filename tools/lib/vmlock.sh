# shellcheck shell=bash
# One VM job at a time on this machine, across checkouts and worktrees.
# A guest takes 4 GiB, and jobs started side by side (three sessions, each
# with its own install test) pushed the host into its out-of-memory killer,
# which ended every one of them (2026-11-14).
#
# vm_lock wait|try WHO: take the lock for this process and its children.
#   wait   block until the running job ends (the VM tests)
#   try    fail at once when a job is running (tools/run-vm by hand)
# A job that holds the lock exports PYRE_VM_LOCK, so the run-vm calls it makes
# pass straight through.
vm_lock() {
  local mode="$1" who="$2" file="${PYRE_VM_LOCK_FILE:-${XDG_RUNTIME_DIR:-/tmp}/pyre-vm.lock}"
  [[ -z "${PYRE_VM_LOCK:-}" ]] || return 0
  exec {vm_lock_fd}>>"$file"
  if ! flock -n "$vm_lock_fd"; then
    if [[ "$mode" != wait ]]; then
      printf '%s: another VM job is running: %s\n' "$who" "$(<"$file")" >&2
      return 1
    fi
    printf '%s: waiting for another VM job to end: %s\n' "$who" "$(<"$file")" >&2
    flock "$vm_lock_fd"
  fi
  printf '%s, pid %s, in %s\n' "$who" "$$" "$PWD" >"$file"
  export PYRE_VM_LOCK=1
}
