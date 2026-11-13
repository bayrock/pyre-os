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

# Whole disks that can be installed to, as "PATH  SIZE  MODEL" lines.
candidate_disks() {
  local medium line
  medium="$(boot_medium_disk)"
  while IFS= read -r line; do
    [[ "$line" =~ ^NAME=\"([^\"]*)\"\ TYPE=\"disk\"\ SIZE=\"([^\"]*)\"\ MODEL=\"([^\"]*)\"$ ]] || continue
    installable_disk "${BASH_REMATCH[1]}" "$medium" || continue
    printf '%s  %s  %s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]:-unknown model}"
  done < <(lsblk -dnpPo NAME,TYPE,SIZE,MODEL)
}

tui_collect() {
  local disks choice
  config_defaults
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
}

# The destructive-action confirmation names the exact disk (ADR 0006).
tui_confirm() {
  local desc
  desc="$(lsblk -dno SIZE,MODEL "${CFG[disk]}" | sed 's/  */ /g')"
  gum style --border rounded --padding "0 1" --foreground 1 \
    "This erases ALL data on ${CFG[disk]} (${desc})." \
    "Hostname ${CFG[hostname]}, user ${CFG[username]}, ${CFG[timezone]}, ${CFG[locale]}, keymap ${CFG[keymap]}, autologin ${CFG[autologin]}."
  [[ "$(gum input --prompt 'Type erase to continue: ')" == erase ]] || die "not confirmed; nothing was changed"
  CFG[erase_disk]=true
}
