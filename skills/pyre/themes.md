# Themes

A PyreOS theme recolors the shell, niri's focus ring, foot, GTK apps and btop at once, live, and brings a wallpaper. `/usr/share/doc/pyre/guide/03-themes.md` is the user's page.

## Switching

```
pyre theme list                        # the themes; * marks the current one
pyre theme set frost                   # switch, with the theme's wallpaper
pyre theme set birch --keep-wallpaper  # colors only
pyre theme current
```

PyreOS ships four: `ember` (the default, dark), `birch` (light), `evergreen` (dark) and `frost` (dark). Ember and Birch are the dark and light variants of one palette, so Noctalia's dark/light switch moves between those two.

`pyre theme set` needs the user's running session, because it asks Noctalia to switch. If it reports that Noctalia did not take the theme, the command ran outside the session.

Windows that are already open recolor too. If a terminal keeps old colors, `pyre theme refresh` sends them again; a new terminal always has them.

## How it works

A theme is a Noctalia palette plus a wallpaper, in `/usr/share/pyre/themes/<id>/`:

```text
theme.toml     name, description, mode (dark or light), wallpaper
palette.json   the colors, in Noctalia's palette format
wallpapers/    the wallpaper
```

Each palette is linked into `~/.config/noctalia/palettes/` under the theme's name. Noctalia renders the current palette into the files the user's stubs already include: `~/.config/niri/noctalia.kdl`, `~/.config/foot/themes/noctalia`, a `noctalia.css` for GTK 3 and 4, and a btop theme. Never edit those generated files; the next theme change overwrites them.

The boot menu, the boot splash and the login screen always wear Ember. They belong to the machine, not to one user.

## A theme of the user's own

1. Copy a palette as a starting point: `cp /usr/share/pyre/themes/ember/palette.json ~/.config/noctalia/palettes/Mine.json`. The file must be a real file, not a link.
2. Edit the colors. The file has a `dark` and a `light` set of the same roles; keep every role.
3. Choose it in Noctalia's settings window (from the launcher: `shell settings`; then the theme settings), or with `noctalia msg color-scheme-set custom Mine`.

A file of the user's in `~/.config/noctalia/palettes/` is never replaced by PyreOS, even under a PyreOS theme's name. `pyre theme list` shows only the PyreOS themes, so a palette of the user's own does not appear there; `pyre theme set <name>` brings a PyreOS theme back.

Noctalia's settings window offers more palettes of its own, including ones made from the wallpaper.

## Wallpaper

The wallpaper is Noctalia's: its settings window, or `noctalia msg wallpaper-set <file>`. `pyre theme set` replaces it with the theme's own unless `--keep-wallpaper` is given, so use that option for a user who chose their own picture.

## Things not to do

- Do not add a directory under `/usr/share/pyre/themes/`: the package owns it.
- Do not set colors in `~/.config/niri/config.kdl` or `~/.config/foot/foot.ini` to "fix" a theme: they would stop following theme changes. Change the palette.
- `pyre theme set ember` is the way back when the colors look wrong.
