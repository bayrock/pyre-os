# shellcheck shell=bash
# Interactive questions with gum. Fills CFG; the same checks as --config apply.

declare -gA CFG  # defined in config.sh; declared here so the keys parse as strings

ask() {
  local value
  value="$(gum input --prompt "$1: " --value "${2:-}")" || die "cancelled"
  printf '%s\n' "$value"
}

ask_secret() {
  local first second
  while :; do
    first="$(gum input --password --prompt "$1: ")" || die "cancelled"
    second="$(gum input --password --prompt "Repeat $1: ")" || die "cancelled"
    [[ -n "$first" && "$first" == "$second" ]] && break
    gum style --foreground 1 "Empty, or the two entries differ. Try again."
  done
  printf '%s\n' "$first"
}

# ask_checked PROMPT CHECK: an optional value, asked again until CHECK
# accepts it. Enter leaves it empty.
ask_checked() {
  local value
  while :; do
    value="$(ask "$1")"
    "$2" "$value" && break
    gum style --foreground 1 "That does not look right. Try again, or leave it empty."
  done
  printf '%s\n' "$value"
}

# disk_contents DISK: what the disk holds now ("empty", or its filesystems),
# so that nobody erases the wrong one on a machine with several disks.
disk_contents() {
  local types
  types="$(lsblk -nlo FSTYPE "$1" | awk 'NF && !seen[$1]++' | paste -sd' ')"
  if [[ -n "$types" ]]; then printf 'holds %s\n' "$types"; else printf 'empty\n'; fi
}

# Whole disks that can be installed to, as "PATH  SIZE  MODEL  CONTENTS" lines.
candidate_disks() {
  local medium line
  medium="$(boot_medium_disk)"
  while IFS= read -r line; do
    [[ "$line" =~ ^NAME=\"([^\"]*)\"\ TYPE=\"disk\"\ SIZE=\"([^\"]*)\"\ MODEL=\"([^\"]*)\"$ ]] || continue
    installable_disk "${BASH_REMATCH[1]}" "$medium" || continue
    printf '%s  %s  %s  (%s)\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]:-unknown model}" \
      "$(disk_contents "${BASH_REMATCH[1]}")"
  done < <(lsblk -dnpPo NAME,TYPE,SIZE,MODEL)
}

# PYRE_KERNEL_PARAMS in the environment adds kernel parameters, for machines
# that need one to boot (and for the VM tests' serial console).
tui_collect() {
  local disks choice swap_gib
  config_defaults
  CFG[kernel_params]="${PYRE_KERNEL_PARAMS:-}"
  gum style --bold --foreground 208 "PyreOS installer"

  disks="$(candidate_disks)"
  [[ -n "$disks" ]] || die "no disk to install to"
  choice="$(gum choose --header "Install PyreOS to which disk? It will be erased." <<<"$disks")" || die "cancelled"
  CFG[disk]="${choice%%  *}"

  CFG[hostname]="$(ask "Hostname" "${CFG[hostname]}")"
  CFG[username]="$(ask "Username")"
  CFG[password]="$(ask_secret "Password for ${CFG[username]}")"
  CFG[luks_passphrase]="$(ask_secret "Disk encryption passphrase")"
  CFG[timezone]="$(timedatectl list-timezones | gum filter --header "Timezone" --value "${CFG[timezone]}")" || die "cancelled"
  CFG[locale]="$(awk '$2 == "UTF-8" { print $1 }' /usr/share/i18n/SUPPORTED |
    gum filter --header "Locale" --value "${CFG[locale]}")" || die "cancelled"
  CFG[keymap]="$(localectl list-keymaps | gum filter --header "Keyboard layout" --value "${CFG[keymap]}")" || die "cancelled"
  if gum confirm --default=false "Log in automatically after the disk is unlocked?"; then
    CFG[autologin]=true
  fi
  swap_gib=$(( ($(swap_mib) + 1023) / 1024 ))
  if gum confirm --default=false "Enable hibernation? It adds a $swap_gib GiB swapfile, the size of this machine's memory."; then
    CFG[hibernation]=true
  fi
  # Development (ADR 0022): both the identity and the tools are optional.
  CFG[git_name]="$(ask_checked "Your name, for git commits (optional)" valid_git_name)"
  CFG[git_email]="$(ask_checked "Your email, for git commits (optional)" valid_git_email)"
  if gum confirm --default=false "Install the development tools? Compilers, GitHub CLI, Go, Node, Python and Rust."; then
    CFG[dev_tools]=true
  fi
}

# The destructive-action confirmation names the exact disk (ADR 0006).
tui_confirm() {
  local desc
  desc="$(lsblk -dno SIZE,MODEL "${CFG[disk]}" | xargs)"
  gum style --border rounded --padding "0 1" --foreground 1 \
    "This erases ALL data on ${CFG[disk]} (${desc}, $(disk_contents "${CFG[disk]}"))." \
    "Hostname ${CFG[hostname]}, user ${CFG[username]}, ${CFG[timezone]}, ${CFG[locale]}, keymap ${CFG[keymap]}," \
    "autologin ${CFG[autologin]}, hibernation ${CFG[hibernation]}, development tools ${CFG[dev_tools]}," \
    "git identity ${CFG[git_name]:-no name} <${CFG[git_email]:-no email}>."
  [[ "$(gum input --prompt 'Type erase to continue: ')" == erase ]] || die "not confirmed; nothing was changed"
  CFG[erase_disk]=true
}
