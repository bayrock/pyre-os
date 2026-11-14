# shellcheck shell=bash
# Themes (ADR 0015). A theme is a directory in /usr/share/pyre/themes/ with a
# theme.toml (name, description, mode) and a Noctalia palette, palette.json.
# Noctalia reads custom palettes only from the user's config, so each palette
# is linked into ~/.config/noctalia/palettes/ under the theme's name. A link
# follows package updates; a file of the user's own there is never replaced.

themes_dir() {
  printf '%s\n' "$PYRE_ROOT/usr/share/pyre/themes"
}

palettes_dir() {
  printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/noctalia/palettes"
}

# theme_ids: every installed theme, one id per line.
theme_ids() {
  local dir
  for dir in "$(themes_dir)"/*/; do
    [[ -f "$dir/theme.toml" && -f "$dir/palette.json" ]] && basename -- "$dir"
  done
  return 0
}

# theme_field ID KEY: a string value from the theme's theme.toml.
theme_field() {
  sed -n "s/^$2 *= *\"\\(.*\\)\"\$/\\1/p" "$(themes_dir)/$1/theme.toml" | head -n 1
}

# theme_resolve NAME: the theme id for an id or a display name (any case).
theme_resolve() {
  local want="${1,,}" id
  while IFS= read -r id; do
    if [[ "$id" == "$want" || "$(theme_field "$id" name | tr '[:upper:]' '[:lower:]')" == "$want" ]]; then
      printf '%s\n' "$id"
      return 0
    fi
  done < <(theme_ids)
  return 1
}

# theme_link_path ID: where the theme's palette is linked for Noctalia.
theme_link_path() {
  printf '%s/%s.json\n' "$(palettes_dir)" "$(theme_field "$1" name)"
}

# theme_linked ID: the palette link exists and points at the installed palette.
theme_linked() {
  local link
  link="$(theme_link_path "$1")"
  [[ -L "$link" && "$(readlink -- "$link")" == "$(themes_dir)/$1/palette.json" ]]
}

# theme_user_owned ID: the user keeps a file of their own under the theme's name.
theme_user_owned() {
  local link
  link="$(theme_link_path "$1")"
  [[ -e "$link" && ! -L "$link" ]]
}

# theme_link ID: link the palette, unless the user's own file is in the way.
theme_link() {
  local link
  link="$(theme_link_path "$1")"
  if theme_user_owned "$1"; then
    warn "$link is your own file; PyreOS leaves it alone"
    return 1
  fi
  mkdir -p -- "$(palettes_dir)"
  ln -sfn -- "$(themes_dir)/$1/palette.json" "$link"
}
