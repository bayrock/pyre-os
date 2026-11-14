# Keys

The PyreOS default keymap. `Mod` is the Super key, the one with the logo on it. `Mod+Shift+/` shows niri's overlay of the most important keys.

The keymap is defined in `/usr/share/pyre/defaults/niri/binds.kdl` (`defaults/niri/binds.kdl` in the source), and this page must match that file. It is also the Keys page of the user guide.

The keymap keeps niri's own defaults for windows, columns, workspaces and monitors, so niri's documentation applies unchanged. PyreOS adds the app, shell and capture keys.

**To change a key,** bind it again in `~/.config/niri/config.kdl`, below the `include` line. A later bind of the same key replaces the default.

## Apps and shell

| Key | Action |
|---|---|
| `Mod+Return` | Terminal (foot) |
| `Mod+B` | Browser (Firefox) |
| `Mod+E` | Files (Nautilus) |
| `Mod+Space` | Launcher |
| `Mod+S` | Control center: audio, network, Bluetooth, power |
| `Mod+Ctrl+V` | Clipboard history |
| `Mod+Shift+N` | Do not disturb on or off |
| `Mod+Shift+,` | Shell settings |
| `Mod+Shift+E` | Session menu: lock, log out, reboot, shut down |
| `Super+Alt+L` | Lock the screen |
| `Alt+Tab` | Window switcher |

## Capture

| Key | Action |
|---|---|
| `Print` | Screenshot: pick a region, window or screen |
| `Ctrl+Print` | Screenshot of the focused screen |
| `Alt+Print` | Screenshot of the focused window |
| `Mod+Print` | Start or stop a screen recording (`pyre-record`) |

Screenshots are saved in `~/Pictures/Screenshots` and copied to the clipboard. Recordings go to `~/Videos`. The first recording asks which screen or window to record.

## Media keys

Volume, microphone mute, brightness and the play/pause, stop, previous and next keys go through Noctalia, which shows an on-screen display. They work on the lock screen too.

## Windows and columns

| Key | Action |
|---|---|
| `Mod+Q` | Close the window |
| `Mod+O` | Overview |
| `Mod+←↓↑→` or `Mod+H J K L` | Focus the column or window in that direction |
| `Mod+Ctrl+←↓↑→` or `Mod+Ctrl+H J K L` | Move the column or window |
| `Mod+Home`, `Mod+End` | Focus the first or last column |
| `Mod+Ctrl+Home`, `Mod+Ctrl+End` | Move the column to the start or end |
| `Mod+[`, `Mod+]` | Move the window into or out of the neighbouring column |
| `Mod+,`, `Mod+.` | Pull the next window into this column, or push it out |
| `Mod+R`, `Mod+Shift+R` | Cycle the column width presets forwards or backwards |
| `Mod+Ctrl+Shift+R`, `Mod+Ctrl+R` | Cycle window height presets, or reset the height |
| `Mod+-`, `Mod+=` | Column width −10% or +10% |
| `Mod+Shift+-`, `Mod+Shift+=` | Window height −10% or +10% |
| `Mod+F` | Maximize the column |
| `Mod+Shift+F` | Fullscreen |
| `Mod+M` | Maximize the window to the screen edges |
| `Mod+Ctrl+F` | Expand the column to the free width |
| `Mod+C`, `Mod+Ctrl+C` | Center the column, or all visible columns |
| `Mod+V` | Float or tile the window |
| `Mod+Shift+V` | Switch focus between floating and tiled windows |
| `Mod+W` | Show the column as tabs |

## Workspaces and monitors

| Key | Action |
|---|---|
| `Mod+1` … `Mod+9` | Go to workspace 1–9 |
| `Mod+Ctrl+1` … `Mod+Ctrl+9` | Move the column to workspace 1–9 |
| `Mod+U`, `Mod+I` or `Mod+PageDown`, `Mod+PageUp` | Workspace down or up |
| `Mod+Ctrl+U`, `Mod+Ctrl+I` | Move the column to the workspace below or above |
| `Mod+Shift+U`, `Mod+Shift+I` | Move the whole workspace down or up |
| `Mod+wheel` | Workspaces with the mouse wheel; `Mod+Shift+wheel` scrolls columns |
| `Mod+Shift+←↓↑→` or `Mod+Shift+H J K L` | Focus the monitor in that direction |
| `Mod+Shift+Ctrl+←↓↑→` or `Mod+Shift+Ctrl+H J K L` | Move the column to that monitor |

## Session

| Key | Action |
|---|---|
| `Mod+Escape` | Let the focused app take every shortcut (for VMs and remote desktops), or stop |
| `Mod+Shift+P` | Turn the monitors off |
| `Ctrl+Alt+Delete` | Quit niri, after a confirmation |
