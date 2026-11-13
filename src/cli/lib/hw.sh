# shellcheck shell=bash
# Hardware rules (ARCHITECTURE.md, Hardware rules). A rule is a data file,
# never shell: "key = value" lines and # comments. Match keys:
#   match_pci_vendor        hex vendor id, e.g. 10de
#   match_pci_class         hex class prefixes, e.g. 0300 0302
#   match_pci_device_min    lowest hex device id (inclusive)
#   match_pci_device_max    highest hex device id (inclusive)
#   match_cpu_vendor        e.g. AuthenticAMD
# Action keys: packages, modules (initramfs), kernel_args, files (a directory
# under hw/files mirroring the target paths), note. Detection reads sysfs and
# /proc only; it never runs lspci, which wakes runtime-suspended dGPUs.

HW_RULES="${HW_RULES:-$PYRE_ROOT/usr/share/pyre/hw/rules}"
HW_FILES="${HW_FILES:-$PYRE_ROOT/usr/share/pyre/hw/files}"
# shellcheck disable=SC2034 # used by commands/hw
HW_STATE="$PYRE_ROOT/var/lib/pyre/hw"
# shellcheck disable=SC2034
HW_MODULES_CONF="$PYRE_ROOT/etc/mkinitcpio.conf.d/50-pyre-hw.conf"
# shellcheck disable=SC2034
HW_CMDLINE_CONF="$PYRE_ROOT/etc/limine-entry-tool.d/50-pyre-hw.conf"

# rule_get FILE KEY: a rule's value for KEY, or nothing.
rule_get() {
  sed -n "s/^[[:space:]]*$2[[:space:]]*=[[:space:]]*\(.*[^[:space:]]\)[[:space:]]*$/\1/p" "$1" | head -n 1
}

# hw_pci: one "vendor device class" line per PCI function, lowercase hex
# without 0x; class is its first four digits (base class and subclass).
hw_pci() {
  local dev vendor device class
  for dev in "$PYRE_ROOT"/sys/bus/pci/devices/*; do
    [[ -r "$dev/vendor" && -r "$dev/device" && -r "$dev/class" ]] || continue
    read -r vendor <"$dev/vendor"
    read -r device <"$dev/device"
    read -r class <"$dev/class"
    vendor="${vendor#0x}" device="${device#0x}" class="${class#0x}"
    printf '%s %s %s\n' "${vendor,,}" "${device,,}" "${class:0:4}"
  done
}

hw_cpu_vendor() {
  sed -n 's/^vendor_id[[:space:]]*:[[:space:]]*//p' "$PYRE_ROOT/proc/cpuinfo" 2>/dev/null | head -n 1
}

# rule_matches FILE: true when some device (or the CPU) satisfies the rule.
rule_matches() {
  local rule="$1" want_vendor want_class dmin dmax want_cpu vendor device class c
  want_cpu="$(rule_get "$rule" match_cpu_vendor)"
  if [[ -n "$want_cpu" ]]; then
    [[ "$(hw_cpu_vendor)" == "$want_cpu" ]]
    return
  fi
  want_vendor="$(rule_get "$rule" match_pci_vendor)"
  [[ -n "$want_vendor" ]] || return 1
  want_class="$(rule_get "$rule" match_pci_class)"
  dmin="$(rule_get "$rule" match_pci_device_min)"
  dmax="$(rule_get "$rule" match_pci_device_max)"
  while read -r vendor device class; do
    [[ "$vendor" == "${want_vendor,,}" ]] || continue
    if [[ -n "$want_class" ]]; then
      for c in $want_class; do [[ "$class" == "${c,,}"* ]] && break; c=""; done
      [[ -n "$c" ]] || continue
    fi
    [[ -z "$dmin" ]] || (( 16#$device >= 16#$dmin )) || continue
    [[ -z "$dmax" ]] || (( 16#$device <= 16#$dmax )) || continue
    return 0
  done < <(hw_pci)
  return 1
}

# hw_matched: the matching rule files, in order.
hw_matched() {
  local rule
  for rule in "$HW_RULES"/*.rule; do
    [[ -f "$rule" ]] && rule_matches "$rule" && printf '%s\n' "$rule"
  done
  return 0
}

# hw_collect KEY: the space-joined values of KEY across matching rules.
hw_collect() {
  local rule out=()
  while IFS= read -r rule; do
    # shellcheck disable=SC2207 # values are space-separated words by design
    out+=($(rule_get "$rule" "$1"))
  done < <(hw_matched)
  printf '%s\n' "${out[*]}"
}

# write_if_changed FILE: write stdin to FILE only when it differs; true when
# the file changed.
write_if_changed() {
  local file="$1" new
  new="$(cat)"
  [[ -f "$file" && "$(cat -- "$file")" == "$new" ]] && return 1
  printf '%s\n' "$new" | write_atomic "$file"
}

# remove_if_present FILE: true when the file was there.
remove_if_present() {
  [[ -e "$1" ]] || return 1
  rm -f -- "$1"
}
