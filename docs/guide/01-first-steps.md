# First steps

Welcome home. PyreOS is Arch Linux with the furniture already arranged: the niri window manager, the Noctalia shell, a theme, safe updates and snapshots you can boot into. This page is the short tour.

## Getting around

- **Super** is the key with the logo on it. Most keys start with it.
- **Super + Space** opens the launcher. Type the name of an app and press Enter. It finds more than apps: type `install`, `update` or `theme`, and the PyreOS menu answers.
- **Super + Alt + Space** opens that menu on its own: install, remove, update, style, setup, system.
- **Super + Enter** opens a terminal, and **Super + W** closes a window.
- **Super + S** opens the control center: sound, network, Bluetooth and power.
- **Super + K** lists every key on screen. Type to search it.

The keys follow macOS and the Hyprland-based Arch desktops many people come from, so much of what your hands know already works.

niri places windows side by side in columns on an endless strip, instead of overlapping them. **Super + ← →** moves between columns, **Super + R** cycles a column's width, and **Super + O** shows every window and workspace at once. The Keys page has the full list.

## The apps

| What | App | Key |
|---|---|---|
| Terminal | foot | Super + Enter |
| Browser | Firefox | Super + Shift + B |
| Files | Nautilus | Super + Shift + F |
| Text editor | Neovim | Super + Shift + N |
| System monitor | btop | Super + Shift + T |

That is the whole default set, on purpose. A video player, an image and document viewer, the screen recorder and more are one step away: open the launcher and type `install`. The Software page explains.

## Make it yours

- **Theme:** **Super + Ctrl + T** lists the themes; so does the welcome panel, and `pyre theme set birch` in a terminal. The Themes page explains.
- **Shell settings:** open the launcher and type `shell settings` for Noctalia's settings: the bar, the dock, the wallpaper, night light and more.
- **Your config files** live in `~/.config`. PyreOS loads its defaults first and your files second, so whatever you set wins, and PyreOS never rewrites your files.
- **With a coding agent:** if you use Claude Code, Codex, Gemini CLI or opencode, it already knows its way around. PyreOS gives each of them a skill named `pyre` that explains the system, so you can ask for a keybinding, a monitor layout or a rollback in plain words. The agents themselves are not installed; that choice is yours, and they are in the launcher under `install`.
- **For development:** `pyre dev` sets up git, the development tools and GitHub in one go. The Development page explains.

## Remind me

Open the launcher and type `/remind`, then when and what:

- `/remind 10m tea`
- `/remind 5pm call mum`
- `/remind tomorrow 9am standup`

The row shows the time PyreOS read; Enter sets the reminder. Plain words work too, without the slash: `remind me to call mum in 2 hours`. When the time comes, a notification appears and stays until you dismiss it. If the machine was asleep or off, it appears when you are back.

`/remind` alone lists the reminders that are waiting, and Enter on one cancels it. In a terminal, the same is `pyre remind 10m tea`, `pyre remind list` and `pyre remind cancel`.

## The welcome panel

The panel that greeted you is always one search away: open the launcher and type **Welcome**, or run `pyre welcome`. It can greet you at every login if you like; flip the switch at its bottom.
