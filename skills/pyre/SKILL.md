---
name: pyre
description: >
  Use on a PyreOS machine for anything about the desktop or the system: changing
  or explaining config in ~/.config/niri, ~/.config/noctalia, ~/.config/foot,
  ~/.bashrc, GTK or btop; keybindings, monitors and outputs, window rules, gaps,
  the bar, launcher, notifications, lock and idle, wallpaper, themes and colors;
  screenshots and screen recording; installing software and bundles; and the
  pyre command: pyre update, snapshots, rollback, doctor, theme, the PyreOS
  menu, the key list, reminders, hardware rules, the welcome panel. Triggers: PyreOS, pyre, niri, Noctalia, foot,
  snapper, Limine, "after an update", "roll back", "my screen", "my keys".
  Not for developing PyreOS itself.
---

# PyreOS

PyreOS is Arch Linux with a finished desktop: the niri compositor, the Noctalia shell, themes, and updates that are snapshotted and can be rolled back. This skill is for helping the person at an installed PyreOS machine. Developing PyreOS itself is out of scope: that work follows `AGENTS.md` in its repository, <https://github.com/bayrock/pyre-os>.

Read the topic file before working in its area:

- [`niri.md`](niri.md): keys, screens, window rules, layout
- [`noctalia.md`](noctalia.md): the bar, launcher, notifications, lock, idle, wallpaper
- [`themes.md`](themes.md): switching themes, and making one
- [`lifecycle.md`](lifecycle.md): updates, snapshots, rollback, `pyre doctor`, bundles, hardware rules

The user guide is installed at `/usr/share/doc/pyre/guide/` (seven short pages). It is written for the user, so quote or point to it when explaining something.

## The one rule: defaults are read-only, the user's files win

PyreOS never copies its defaults into the home directory. The user's config files are short stubs that load the defaults first; whatever the user sets below that line wins.

```text
/usr/share/pyre/    READ-ONLY: defaults, themes, hardware rules, this skill
/usr/lib/pyre/      READ-ONLY: the pyre commands and reconcile units
/etc/skel/.config/  READ-ONLY: the original stubs, for putting one back
~/.config/          the user's files: edit these
```

- **Never edit anything under `/usr/share/pyre/` or `/usr/lib/pyre/`.** The packages own those files, and the next update replaces them. Reading them is safe and is how to learn what a default is.
- **Keep the `include` lines at the top of a stub.** Removing one drops every PyreOS default for that app. Add settings below them.
- **Do not copy a defaults file into `~/.config` to edit it.** The copy stops following updates. Override only the setting that should change.
- **PyreOS never rewrites a user's file.** When it has a suggestion for one, it writes `<file>.pyre-new` beside it, and `pyre doctor` lists them. Offer to compare and merge; never replace the user's file with it unasked.

## What is where

| Part | The user's file | Defaults it loads | After a change |
|---|---|---|---|
| niri (windows, keys, screens) | `~/.config/niri/config.kdl` | `/usr/share/pyre/defaults/niri/pyre.kdl`, which includes `binds.kdl` | Applied on save. Run `niri validate` every time. |
| Noctalia (bar, launcher, notifications, lock, idle) | `~/.config/noctalia/config.toml` | `/usr/share/pyre/defaults/noctalia/pyre.toml` | See [`noctalia.md`](noctalia.md): the settings window's choices override the file. |
| foot (terminal) | `~/.config/foot/foot.ini` | `/usr/share/pyre/defaults/foot/foot.ini` | New terminal windows read it. |
| bash | `~/.bashrc` | `/usr/share/pyre/defaults/bash/rc` | New shells read it. |
| Theme colors | none: generated | `/usr/share/pyre/themes/<id>/` | `pyre theme set <name>`, see [`themes.md`](themes.md) |
| fastfetch | `~/.config/fastfetch/config.jsonc` (create it to override) | `/etc/xdg/fastfetch/config.jsonc` | Next run. |

Noctalia writes these files from the theme, and rewrites them at every theme change, so a hand edit is lost: `~/.config/niri/noctalia.kdl`, `~/.config/foot/themes/noctalia`, the `noctalia.css` that `~/.config/gtk-3.0/gtk.css` and `~/.config/gtk-4.0/gtk.css` import, and btop's `noctalia` color theme. Change colors through a theme, not in these.

The rest is stock Arch Linux: pacman, systemd, PipeWire, NetworkManager, bluez, firewalld (the `public` zone), greetd with the Noctalia greeter, Limine as the bootloader, and snapper on btrfs. Arch's wiki applies.

## The pyre command

`pyre help` lists the commands and `pyre help <command>` shows one command's options. Read a command's source in `/usr/lib/pyre/commands/` when its exact behavior matters.

| Command | What it does |
|---|---|
| `pyre update` | Updates safely: keyrings, `pacman -Syu`, AUR if a helper is installed, then checks the system will boot |
| `pyre snapshot` | Lists the system and home snapshots; `pyre snapshot create "why"` takes both now |
| `pyre rollback` | Makes the booted snapshot the system again; `pyre rollback --home N` restores the home folder |
| `pyre doctor` | Checks kernels, boot entries, snapshots and PyreOS state, and says what to do about each problem |
| `pyre theme` | Lists the themes; `pyre theme set <name>` switches, live |
| `pyre install`, `pyre remove` | Adds or removes a bundle of apps: `dev`, `media`, `office` |
| `pyre dev` | Sets up for development, asking about each part: the git name and email, the `dev` bundle, the GitHub sign-in, a Rust toolchain. `pyre dev --status` shows the state and changes nothing; `pyre dev git --name … --email …` writes the identity without asking |
| `pyre menu` | Opens the PyreOS menu in the launcher (**Super + Alt + Space**): optional apps to install or remove, update, themes, settings, system. `pyre menu --list` prints its rows |
| `pyre keys` | Opens the key list (**Super + K**); `pyre keys --list` prints every key with what it does, the user's own binds included |
| `pyre hw` | Shows the hardware rules that match this machine; `pyre hw apply` installs their drivers and settings |
| `pyre reconcile` | Applies PyreOS's own changes after an update. It runs by itself; `--dry-run` shows what it would do |
| `pyre remind` | Sets a reminder: `pyre remind 10m tea`, `pyre remind tomorrow 9am standup`; `pyre remind list` and `pyre remind cancel` manage them. In the launcher it is `/remind 10m tea` |
| `pyre welcome` | Opens the welcome panel; `pyre welcome guide` opens the user guide in it |
| `pyre help` | The list above, from the system itself |

**Privileges.** Run `pyre` commands as the user, without `sudo`: each one asks for the password itself for the steps that need root, and `pyre update` refuses to run as root. A command that needs a password must run in a terminal where the user can type it. If you cannot show a password prompt, give the user the exact command to run.

## Before changing things

1. **Read first.** Read the user's file and the default it loads before proposing a change.
2. **Take a snapshot before a risky change:** `pyre snapshot create "before <what>"` (it asks for the password, for the system snapshot). Every pacman transaction is snapshotted by itself.
3. **Make the smallest change,** in the user's file, below the include lines.
4. **Validate.** `niri validate` for niri; for anything else, check that the change took effect.
5. **Say how to undo it.** Usually: remove the lines again. To go back to the defaults of an app, restore its stub: `cp /etc/skel/.config/niri/config.kdl ~/.config/niri/` (after moving the user's file aside, never deleting it).

**Ask before running** `pyre rollback` in any form, removing packages, or anything that touches disks, the bootloader or `/etc/default/limine`. A rollback discards what happened after the snapshot.

## Choosing the right tool

1. **Is there a `pyre` command for it?** Use it: themes, updates, snapshots, bundles, system checks.
2. **Is it a shell setting** (bar, dock, wallpaper, night light, notifications, idle)? It is Noctalia's: see [`noctalia.md`](noctalia.md). The user can also open the settings window from the launcher: `shell settings`.
3. **Is it about windows, keys, screens or input?** It is niri's: see [`niri.md`](niri.md).
4. **Is it a package?** `sudo pacman -S <package>`. The default install is small on purpose: no video player, image viewer, document viewer or screen recorder. The launcher's **Install** rows offer those and more (the catalog is `/usr/share/pyre/menu/catalog.tsv`), and the user may prefer picking there. PyreOS installs no AUR helper; do not assume `paru` or `yay` exists, and do not install one unasked.
5. **Is something broken?** Start with `pyre doctor`, then [`lifecycle.md`](lifecycle.md).
6. **Anything else** is plain Arch Linux.

## Examples

- "Switch to the light theme" → `pyre theme set birch`
- "Make Super+B open the browser" → add a `binds { Mod+B { spawn "firefox"; } }` block below the includes in `~/.config/niri/config.kdl`, then `niri validate`
- "Set up my second monitor" → `niri msg outputs`, then an `output` block in `~/.config/niri/config.kdl` ([`niri.md`](niri.md))
- "Smaller gaps" → `layout { gaps 6; }` in `~/.config/niri/config.kdl`
- "Lock after five minutes" → override `[idle.behavior.lock]` in `~/.config/noctalia/config.toml` ([`noctalia.md`](noctalia.md))
- "Bigger terminal font" → `[main]` `font=` in `~/.config/foot/foot.ini`, below the includes
- "Install the developer tools" → `pyre install dev`
- "Set up git" or "get this machine ready for coding" → `pyre dev` in a terminal, since it asks questions; check first with `pyre dev --status`. Git's settings are the user's own file, `~/.config/git/config`
- "Update my system" → `pyre update`, in a terminal the user can type a password in
- "The update broke something" → the steps in [`lifecycle.md`](lifecycle.md): boot the snapshot from before it, then `pyre rollback`
- "Is my system healthy?" → `pyre doctor`
- "Remind me to call the bank at 3" → `pyre remind 3pm call the bank`; it arrives as a notification that stays until dismissed
- "Warmer screen in the evening" → night light: **Super + Ctrl + N** at once, or the schedule in [`noctalia.md`](noctalia.md)
- "What keys are there?" → `pyre keys --list`, or **Super + K** on screen; `/usr/share/doc/pyre/guide/02-keys.md` explains them
- "Record my screen" → **Alt + Print** starts and stops a recording (`pyre-record`); it is saved in `~/Videos`. The recorder is an optional install: `sudo pacman -S gpu-screen-recorder`, or **Install › Screen recorder** in the launcher
