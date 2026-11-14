# Noctalia: the shell

Noctalia is everything around the windows: the bar, the launcher, notifications, on-screen displays, the control center, clipboard history, the lock screen, idle behavior, the wallpaper, and the polkit prompt that asks for a password. niri starts it at login.

## Where a setting comes from

Noctalia reads three layers, and the last one wins:

```text
/usr/share/pyre/defaults/noctalia/pyre.toml   1. the PyreOS defaults (read-only)
~/.config/noctalia/config.toml                2. the user's file, which includes the defaults
~/.local/state/noctalia/settings.toml         3. what the user changed in the settings window
```

- The user's `config.toml` starts with an `[include]` table that loads the defaults. Keep it, and add settings below it.
- Noctalia also merges every other `*.toml` file in `~/.config/noctalia/`.
- **Whatever the settings window changed wins over both files.** When an edit to `config.toml` seems to do nothing, look in `settings.toml` for the same key first.

For most shell settings the settings window is the right tool, and the user can open it with **Super + Shift + ,**. Edit `config.toml` when the user wants the setting kept in a file, for example in their dotfiles.

## Read and change settings

Ask the running shell rather than guessing a key's name. The key is the TOML path with dots:

```
noctalia msg config-get idle.behavior.lock.timeout
noctalia msg config-set idle.behavior.lock.timeout 300
noctalia msg status
```

`config-set` changes the running shell at once, which makes it a quick way to try a value. For a change that should last, write it in `~/.config/noctalia/config.toml` as well, then confirm with `config-get`. If the value did not change, `settings.toml` is overriding it, or the shell has not read the file again yet; logging out and in reads everything again.

## What PyreOS sets

Read `/usr/share/pyre/defaults/noctalia/pyre.toml` for the exact keys. In short:

- Noctalia is the polkit agent, telemetry is off, and the first-run wizard is off.
- The theme is the custom palette "Ember"; see [`themes.md`](themes.md).
- The screen locks after 10 minutes idle and the screens turn off a minute later. Noctalia locks before suspend.
- Night light is off, and its schedule has fixed hours, 20:00 to 07:00, so it needs no location.
- The welcome panel and the launcher's reminders are Noctalia plugins, `pyre/welcome` and `pyre/remind`, loaded from `/usr/share/pyre/noctalia/plugins/`.

To change the idle times in the user's file:

```toml
[idle.behavior.lock]
timeout = 300

[idle.behavior.screen-off]
timeout = 360
```

Setting `enabled = false` in one of those tables turns that behavior off.

## Night light

Night light is Noctalia's own blue light filter; there is no separate gamma program to install or configure.

- **Super + Ctrl + N** (`noctalia msg nightlight-force-toggle`) holds the warm light on at once, until it is pressed again or the user logs out.
- For every evening, the user turns on **Night Light** in the settings window, under Services. In a file that is:

```toml
[nightlight]
enabled = true

[location]
custom_schedule = true
sunset = "21:30"
sunrise = "06:30"
```

- PyreOS never looks the user's location up. To follow the real sunset, the user enters a place on the settings' Location page and turns **Custom Schedule** off.
- A screenshot or recording never shows the tint. To check that it is on, read the shell's log: `journalctl --user -b | grep 'target .*K'`.

## Commands

`noctalia msg` talks to the running shell. These are the commands PyreOS's own keys and tools use:

| Command | Does |
|---|---|
| `noctalia msg panel-toggle launcher` | Opens or closes a panel: `launcher`, `control-center`, `clipboard`, `session` |
| `noctalia msg settings-toggle` | The settings window |
| `noctalia msg session lock` | Locks the screen (`loginctl lock-session` does too) |
| `noctalia msg notification-dnd-toggle` | Do not disturb |
| `noctalia msg nightlight-force-toggle` | Night light on at once, or off again |
| `noctalia msg volume-up`, `volume-down`, `volume-mute`, `mic-mute` | Sound, with the on-screen display |
| `noctalia msg brightness-up`, `brightness-down` | Brightness |
| `noctalia msg media toggle` | Media: `toggle`, `stop`, `previous`, `next` |
| `noctalia msg wallpaper-get`, `wallpaper-set <file>` | The wallpaper |
| `noctalia msg color-scheme-get` | The current palette |

For anything else, read Noctalia's own help and documentation rather than guessing a command's name.

## Keys for the shell

The keys that open Noctalia's panels are niri binds, in `/usr/share/pyre/defaults/niri/binds.kdl`. To move one to another key, bind the same `spawn "noctalia" "msg" ...` line to the new key in `~/.config/niri/config.kdl`; see [`niri.md`](niri.md).

## The login screen

The login screen is a separate program, the Noctalia greeter, running as its own user under greetd. It wears the Ember theme until the user presses "Sync" in Noctalia's settings, which gives it their look. `/etc/greetd/config.toml` is the administrator's file: the installer wrote it once, and it holds the autologin setting. Do not change it without asking.
