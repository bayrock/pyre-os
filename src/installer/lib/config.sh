# shellcheck shell=bash
# The install configuration: a flat TOML subset shared by the TUI and --config.
#
#   disk = "/dev/vda"          # whole disk to erase (required)
#   erase_disk = true          # unattended runs must say so (required for --config)
#   username = "pyre"          # required
#   password = "..."           # user password (required)
#   luks_passphrase = "..."    # disk encryption passphrase (required)
#   hostname = "pyreos"        # default pyreos
#   timezone = "UTC"           # default UTC
#   locale = "en_US.UTF-8"     # default en_US.UTF-8
#   keymap = "us"              # default us
#   kernel_params = ""         # extra kernel parameters, e.g. a serial console
#   autologin = false          # log the user in after the disk is unlocked
#   pyre_repo = ""             # [pyre] server URL; default: pyre-release's mirrorlist
#   finish = "none"            # none | reboot | poweroff
#
# Values are "basic strings" without escapes or 'literal strings'. Anything
# else is rejected rather than guessed.

declare -gA CFG=()
readonly CONFIG_KEYS=" disk erase_disk username password luks_passphrase hostname timezone locale keymap kernel_params autologin pyre_repo finish "

config_defaults() {
  CFG=(
    [erase_disk]=false
    [hostname]=pyreos
    [timezone]=UTC
    [locale]=en_US.UTF-8
    [keymap]=us
    [kernel_params]=""
    [autologin]=false
    [pyre_repo]=""
    [finish]=none
  )
}

# config_load FILE: parse FILE into CFG on top of the defaults.
config_load() {
  local file="$1" line key value n=0
  local re_basic='^[[:space:]]*([a-z_]+)[[:space:]]*=[[:space:]]*"([^"\\]*)"[[:space:]]*(#.*)?$'
  local re_literal="^[[:space:]]*([a-z_]+)[[:space:]]*=[[:space:]]*'([^']*)'[[:space:]]*(#.*)?$"
  local re_bool='^[[:space:]]*([a-z_]+)[[:space:]]*=[[:space:]]*(true|false)[[:space:]]*(#.*)?$'
  [[ -r "$file" ]] || die "cannot read config: $file"
  config_defaults
  while IFS= read -r line || [[ -n "$line" ]]; do
    n=$((n + 1))
    line="${line%$'\r'}"
    [[ "$line" =~ ^[[:space:]]*(#.*)?$ ]] && continue
    if [[ "$line" =~ $re_basic || "$line" =~ $re_literal || "$line" =~ $re_bool ]]; then
      key="${BASH_REMATCH[1]}"
      value="${BASH_REMATCH[2]}"
    else
      die "$file:$n: expected key = \"value\", key = 'value', or key = true|false"
    fi
    [[ "$CONFIG_KEYS" == *" $key "* ]] || die "$file:$n: unknown key: $key"
    CFG[$key]="$value"
  done <"$file"
}

# config_check: validate values that need no system lookups. Prints every
# problem and returns 1 if there was any.
config_check() {
  local errors=() key
  for key in disk username password luks_passphrase; do
    [[ -n "${CFG[$key]:-}" ]] || errors+=("$key is required")
  done
  [[ -z "${CFG[disk]:-}" || "${CFG[disk]}" =~ ^/dev/[A-Za-z0-9/_-]+$ ]] || errors+=("disk must be a /dev path")
  [[ -z "${CFG[username]:-}" || "${CFG[username]}" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] ||
    errors+=("username must match [a-z_][a-z0-9_-]{0,31}")
  [[ "${CFG[username]:-}" != root ]] || errors+=("username must not be root")
  [[ "${CFG[hostname]}" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$ ]] ||
    errors+=("hostname must be a single DNS label")
  [[ "${CFG[timezone]}" =~ ^[A-Za-z0-9_+-]+(/[A-Za-z0-9_+-]+)*$ ]] || errors+=("timezone is malformed")
  [[ "${CFG[locale]}" =~ ^[a-z]{2,3}(_[A-Z]{2})?\.UTF-8(@[a-z]+)?$ ]] ||
    errors+=("locale must be a UTF-8 locale such as en_US.UTF-8")
  [[ "${CFG[keymap]}" =~ ^[A-Za-z0-9_.-]+$ ]] || errors+=("keymap is malformed")
  [[ "${CFG[kernel_params]}" =~ ^[A-Za-z0-9_.,:=/+\ -]*$ ]] || errors+=("kernel_params has unsupported characters")
  for key in erase_disk autologin; do
    [[ "${CFG[$key]}" == true || "${CFG[$key]}" == false ]] || errors+=("$key must be true or false")
  done
  local re_url='^(https?|file)://[^[:space:]"'"'"'\\]+$'
  [[ -z "${CFG[pyre_repo]}" || "${CFG[pyre_repo]}" =~ $re_url ]] ||
    errors+=("pyre_repo must be an http(s):// or file:// URL")
  case "${CFG[finish]}" in none | reboot | poweroff) ;; *) errors+=("finish must be none, reboot, or poweroff") ;; esac
  (( ${#errors[@]} == 0 )) && return 0
  printf 'config: %s\n' "${errors[@]}" >&2
  return 1
}

# config_check_system: validate values against the live system's data.
config_check_system() {
  local errors=()
  [[ -f "/usr/share/zoneinfo/${CFG[timezone]}" ]] || errors+=("unknown timezone: ${CFG[timezone]}")
  grep -qx "${CFG[locale]} UTF-8" /usr/share/i18n/SUPPORTED 2>/dev/null || errors+=("unknown locale: ${CFG[locale]}")
  find /usr/share/kbd/keymaps -name "${CFG[keymap]}.map.gz" -print -quit 2>/dev/null | grep -q . ||
    errors+=("unknown keymap: ${CFG[keymap]}")
  (( ${#errors[@]} == 0 )) && return 0
  printf 'config: %s\n' "${errors[@]}" >&2
  return 1
}
