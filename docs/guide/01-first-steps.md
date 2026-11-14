# First steps

Welcome home. PyreOS is Arch Linux with the furniture already arranged: the niri window manager, the Noctalia shell, a theme, safe updates and snapshots you can boot into. This page is the short tour.

## Getting around

- **Super** is the key with the logo on it. Most keys start with it.
- **Super + Space** opens the launcher. Type the name of an app and press Enter.
- **Super + Enter** opens a terminal.
- **Super + S** opens the control center: sound, network, Bluetooth and power.
- **Super + Shift + /** shows the most useful keys on screen.

niri places windows side by side in columns on an endless strip, instead of overlapping them. **Super + ← →** moves between columns, **Super + R** cycles a column's width, and **Super + O** shows every window and workspace at once. The Keys page has the full list.

## The apps

| What | App | Key |
|---|---|---|
| Terminal | foot | Super + Enter |
| Browser | Firefox | Super + B |
| Files | Nautilus | Super + E |
| Text editor | Neovim | `nvim` in a terminal |
| Video and music | mpv | open a file |
| Images | imv | open a file |
| Documents | Papers | open a file |

More software is one command away; see the Software page.

## Make it yours

- **Theme:** `pyre theme set birch` in a terminal, or the welcome panel. The Themes page explains.
- **Shell settings:** **Super + Shift + ,** opens Noctalia's settings: the bar, the dock, the wallpaper, night light and more.
- **Your config files** live in `~/.config`. PyreOS loads its defaults first and your files second, so whatever you set wins, and PyreOS never rewrites your files.

## The welcome panel

The panel that greeted you is always one search away: open the launcher and type **Welcome**, or run `pyre welcome`. It can greet you at every login if you like; flip the switch at its bottom.
