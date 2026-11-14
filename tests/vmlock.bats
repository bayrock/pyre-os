#!/usr/bin/env bats
# tools/lib/vmlock.sh: one VM job at a time on the machine.

setup() {
  repo_root="$(cd -- "$BATS_TEST_DIRNAME/.." && pwd -P)"
  export PYRE_VM_LOCK_FILE="$BATS_TEST_TMPDIR/vm.lock"
  unset PYRE_VM_LOCK
  job="source '$repo_root/tools/lib/vmlock.sh'; vm_lock"
}

# hold SECONDS: a job that keeps the lock that long, started in the background.
hold() {
  bash -c "$job wait first && exec sleep $1" 3>&- &
  holder=$!
  for _ in $(seq 50); do [[ -s "$PYRE_VM_LOCK_FILE" ]] && return 0; sleep 0.1; done
  return 1
}

@test "vm_lock: a second job is refused while the first runs, and names it" {
  hold 5
  run bash -c "$job try second"
  kill "$holder"
  [ "$status" -eq 1 ]
  [[ "$output" == *"another VM job is running: first, pid "* ]]
}

@test "vm_lock: a waiting job starts when the first ends" {
  hold 1
  run bash -c "$job wait second && cat \"\$PYRE_VM_LOCK_FILE\""
  [ "$status" -eq 0 ]
  [[ "$output" == *"waiting for another VM job to end: first"* ]]
  [[ "${lines[-1]}" == "second, pid "* ]]
}

@test "vm_lock: what a job starts passes through its own lock" {
  run bash -c "$job wait outer && bash -c \"$job try inner\" && echo both"
  [ "$status" -eq 0 ]
  [ "${lines[-1]}" = both ]
}

@test "vm_lock: the lock is free again after a job is killed" {
  hold 30
  kill "$holder"
  wait "$holder" 2>/dev/null || true
  run bash -c "$job try next"
  [ "$status" -eq 0 ]
}
