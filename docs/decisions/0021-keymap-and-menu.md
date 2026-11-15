# ADR 0021: A familiar keymap, and a PyreOS menu inside the launcher

- Status: Accepted
- Date: 2026-11-14
- Amends: ADR 0013 (the default apps, and "the keymap keeps niri's own defaults" in `docs/KEYBINDINGS.md`)

## Context

PyreOS opened Noctalia's launcher on Super+Space, and that was all: no way to install or remove an app, update, or switch the theme without a terminal, and no list of the keys beyond niri's small overlay. The keymap was niri's own (Super+H/J/K/L, Super+Q, Super+V, Super+Ctrl+1…9), which matches neither macOS nor the Hyprland-based Arch desktops many users come from. And the default install carried apps not everyone wants.

Decided with the owner on 2026-11-14:

1. **One launcher.** Super+Space stays the app launcher, and the PyreOS menu is searchable inside it. Super+Alt+Space opens the menu on its own.
2. **Match the familiar keys fully** wherever niri has the same action.
3. **Trim the default install to the core.** The rest is an optional install in the menu.
4. **The catalog is Arch's official repositories, plus a search.** No AUR or proprietary app is named.

Read on 2026-11-14 in Noctalia's documentation and sources at tag `v5.5.0` (<https://github.com/noctalia-dev/noctalia>: `docs/user/launcher/index.mdx`, `src/launcher/dmenu_provider.cpp`, `src/shell/launcher/launcher_panel.cpp`) and its IPC pages (<https://github.com/noctalia-dev/noctalia-docs>, `ipc/surfaces.mdx`, `ipc/shell.mdx`, `ipc/media-and-ui.mdx`):

- `[shell.launcher.dmenu.entry.<id>]` makes a launcher provider from a command's output: one result per line, a tab between title and description. `prefix` gives it a `/word`, and `global = true` adds its rows to the ordinary search once two characters are typed.
- The command runs again each time the launcher opens (providers are reset when it closes), with a two-second limit and at most 200 rows.
- `exec` runs when a row is chosen, with `{selection}` replaced by the row's text, unquoted, in a shell command line. Only a row the command printed can be chosen, never typed text.
- `noctalia msg panel-toggle launcher <query>` opens the launcher with the search filled in.

## Decision

**The keymap** (`defaults/niri/binds.kdl`, `docs/KEYBINDINGS.md`):

- The familiar key for every action niri has: Super+W closes, Super+F is fullscreen, Super+T floats, Super+arrows focus and Super+Shift+arrows move, Super+1…0 are workspaces and Super+Shift+1…0 move a window there, Super+Tab steps through workspaces, Super+K lists the keys, Super+Escape is the system menu, Super+Ctrl+L locks.
- niri-only actions sit on keys those conventions leave free: Super+O overview, Super+R width presets, Super+[ and ] for columns, Super+G for tabs, Super+Z to center.
- Super+H/J/K/L navigation is gone; the arrows do it.
- **Super+C, V, X and A stay unbound.** They mean copy, paste, cut and select all where these conventions come from. niri cannot send keys to a window, and any other meaning would surprise.
- Nothing is bound to an action PyreOS does not ship: no scratchpad, no minimize, no web-app or proprietary-app keys.
- **Every bind is one line with a `hotkey-overlay-title`.** That title is its description everywhere.

**`pyre keys`** (`src/cli/commands/keys`) prints "key, description" from that file and then from the user's `config.kdl`, where a later bind of a key wins, as in niri. `tools/keys-doc` writes the "Every key" section of the Keys page from the same parser, and a test fails when the page and the keymap differ.

**`pyre menu`** (`src/cli/commands/menu`) is the PyreOS menu:

- `--list` prints its rows: update, install and remove, themes, style, setup, learn, system. They come from `menu.tsv`, from the optional apps in `catalog.tsv`, and from the bundles and themes that are installed. An app shows under Install or under Remove, by whether it is installed.
- `--pick` does what a row says. It looks the row up by its title among the rows it would list now, so text that is not a row does nothing.
- **The data files hold words and package names, never commands.** A row names one of a fixed set of actions and an argument for it. No field may hold a quote or a backslash, because the launcher puts the chosen row between single quotes on a command line; `pyre menu` drops such a row and a test refuses one in the files.
- Installs, removals and updates run in a floating terminal (`foot`, app-id `pyre.menu`) that stays open until Enter. `--run` there accepts only a set of packages the catalog or a bundle names, exactly.
- An install checks first: offline, it says so; without package lists (after an install with no network), it offers `pyre update` and continues after it.
- "Find a package…" is an `fzf` search over the repositories. "Find in the AUR…" appears only when `paru` or `yay` is installed.
- Restart and shut down are not rows. "Log out, restart or shut down…" opens Noctalia's power menu, so a hurried Enter in a search cannot end the session.

**The launcher** gets two providers in `defaults/noctalia/pyre.toml`: `/pyre` (also in the ordinary search) from `pyre menu --list`, and `/keys` from `pyre keys --list`. Super+Alt+Space, Super+K and Super+Ctrl+T open the launcher on them.

**The default apps** are foot, Firefox, Nautilus, Neovim, btop, fastfetch, and what the default prompt and the menu use (eza, fzf, zoxide, starship). mpv, imv, Papers, the screen recorder, bat and ripgrep move to the catalog. `pyre-record` says where to find the recorder when it is missing.

## Consequences

- **No new shell code to own.** The feature is two bash commands and two data files, tested with bats; Noctalia draws all of it.
- **niri's documentation no longer matches the defaults key for key.** The Keys page and Super+K are the reference.
- **Optional installs need a network.** The ISO's offline repository shrinks with the default set, and an offline install can add nothing until it is online.
- **Existing installs keep their apps.** pacman removes nothing when a dependency is dropped; the apps turn up under Remove.
- **A catalog entry is a promise** that the package is in `core` or `extra`. `tools/check-catalog` checks it against a sync database, on a machine that has one.
- **Coupled to Noctalia's dmenu providers** and their unquoted `{selection}`. If that changes, the quote rule above is what to revisit.
- About 350 lines of bash against the CLI budget (ARCHITECTURE); the CLI and the installer together are near 2,600 of 5,000.
