# shellcheck shell=bash
# The reconcile engine (ADR 0007, ADR 0014).
#
# A unit is a file in $PYRE_LIB/reconcile/<scope>/ named NNN-name. It sets
# since=<schema version>, optionally fresh=skip, has a "# about:" line, and
# defines check (true when the desired state holds) and apply. A scope
# records the newest version it has reconciled; later runs consider only
# units with a higher since. A fresh scope (no record) considers every unit
# except fresh=skip ones.

# reconcile_units SCOPE: the unit files of SCOPE, in order.
reconcile_units() {
  local dir="$PYRE_LIB/reconcile/$1" file
  [[ -d "$dir" ]] || return 0
  for file in "$dir"/[0-9][0-9][0-9]-*; do
    [[ -f "$file" ]] && printf '%s\n' "$file"
  done
}

# unit_meta FILE: print "since fresh" for a unit, sourced in a subshell.
unit_meta() {
  (
    since="" fresh=""
    # shellcheck source=/dev/null
    source "$1"
    [[ "$since" =~ ^[1-9][0-9]*$ ]] || { echo "invalid since= in $1" >&2; exit 1; }
    printf '%s %s\n' "$since" "${fresh:-run}"
  )
}

# unit_run FILE DRY: check, apply if needed, and check again, in a subshell
# so units cannot leak functions or variables into each other.
unit_run() {
  local file="$1" dry="$2" about
  about="$(command_meta "$file" about)"
  (
    # shellcheck source=/dev/null
    source "$file"
    if check; then
      info "${file##*/}: ok ($about)"
      exit 0
    fi
    if [[ "$dry" == 1 ]]; then
      info "${file##*/}: would apply ($about)"
      exit 0
    fi
    info "${file##*/}: applying ($about)"
    apply
    check || { echo "pyre: ${file##*/}: still not converged after apply" >&2; exit 1; }
  )
}

# reconcile_pending SCOPE RECORDED: the units to consider, one per line.
reconcile_pending() {
  local scope="$1" recorded="$2" unit since fresh
  while IFS= read -r unit; do
    read -r since fresh < <(unit_meta "$unit") || return 1
    if [[ -z "$recorded" ]]; then
      [[ "$fresh" == skip ]] && continue
    else
      (( since > recorded )) || continue
    fi
    printf '%s\n' "$unit"
  done < <(reconcile_units "$scope")
}

# reconcile_latest SCOPE: the newest since among the scope's units (0 if none).
reconcile_latest() {
  local unit since fresh latest=0
  while IFS= read -r unit; do
    read -r since fresh < <(unit_meta "$unit")
    (( since > latest )) && latest="$since"
  done < <(reconcile_units "$1")
  printf '%s\n' "$latest"
}

# reconcile_read STATE: the recorded version, or empty for a fresh scope.
reconcile_read() {
  local value=""
  [[ -f "$1" ]] && read -r value <"$1"
  [[ -z "$value" || "$value" =~ ^[0-9]+$ ]] || die "corrupt reconcile state in $1: $value"
  printf '%s\n' "$value"
}

# reconcile_scope SCOPE STATE DRY [BEFORE]: run the pending units of SCOPE and
# record the scope's version. BEFORE, if given, is called once before the
# first unit when there is work to do and the scope is not fresh.
reconcile_scope() {
  local scope="$1" state="$2" dry="$3" before="${4:-}" recorded latest unit
  local -a pending
  recorded="$(reconcile_read "$state")"
  latest="$(reconcile_latest "$scope")"
  mapfile -t pending < <(reconcile_pending "$scope" "$recorded")
  step "Reconciling $scope state (recorded ${recorded:-none}, current $latest)"
  if (( ${#pending[@]} == 0 )); then
    info "nothing to do"
  else
    [[ "$dry" == 1 || -z "$before" || -z "$recorded" ]] || "$before"
    for unit in "${pending[@]}"; do
      unit_run "$unit" "$dry" || die "reconcile stopped at ${unit##*/}; nothing was recorded, the next run retries"
    done
  fi
  [[ "$dry" == 1 || "$recorded" == "$latest" ]] || printf '%s\n' "$latest" | write_atomic "$state"
}
