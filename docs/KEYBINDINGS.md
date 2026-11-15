# Keys

The PyreOS default keymap. **Super** is the key with the logo on it, and most keys start with it. **Super + K** lists every key on screen, and typing there searches the list.

The keys follow the conventions of macOS and of the Hyprland-based Arch desktops many people come from, wherever niri has the same action: **Super + Space** for the launcher, **Super + W** to close, **Super + F** for fullscreen, **Super + 1** for the first workspace (ADR 0021). What only niri has, such as the overview and column widths, sits on keys those conventions leave free.

**To change a key,** bind it again in `~/.config/niri/config.kdl`, below the `include` line. A later bind of the same key replaces the default, and **Super + K** then shows yours. Give it a `hotkey-overlay-title="…"` and that is its description in the list.

## The keys to learn first

| Key | Action |
|---|---|
| `Super + Space` | The launcher: apps, the calculator, and everything in the PyreOS menu |
| `Super + Alt + Space` | The PyreOS menu on its own: install, remove, update, style, setup, system |
| `Super + K` | Every key |
| `Super + Enter` | Terminal |
| `Super + Shift + B` | Browser |
| `Super + Shift + F` | Files |
| `Super + W` | Close the window |
| `Super + F` | Fullscreen |
| `Super + T` | Float the window, or tile it again |
| `Super + ← ↓ ↑ →` | Focus the column or window in that direction |
| `Super + Shift + ← ↓ ↑ →` | Move it |
| `Super + 1` … `Super + 0` | Go to workspace 1 to 10; with **Shift**, take the window there |
| `Super + Tab` | The next workspace |
| `Super + O` | Overview: every window and workspace |
| `Super + S` | Control center: sound, network, Bluetooth, power |
| `Super + Ctrl + V` | Clipboard history |
| `Super + Escape` | Lock, log out, restart or shut down |
| `Super + Ctrl + L` | Lock the screen |
| `Print` | Screenshot: pick a region, a window or a screen |

## Good to know

- **Copy and paste** stay on **Ctrl + C** and **Ctrl + V** (**Ctrl + Shift + C** and **V** in the terminal). **Super + C**, **V**, **X** and **A** are left free on purpose: niri cannot press an app's keys for it, and binding them to anything else would only surprise.
- **Screenshots** are saved in `~/Pictures/Screenshots` and copied to the clipboard.
- **Recording** (**Alt + Print**) needs the screen recorder, an optional install: open the launcher and choose **Install › Screen recorder**. Recordings go to `~/Videos`, and the first one asks which screen or window to record.
- **Volume, brightness and media keys** go through Noctalia, which shows an on-screen display. They work on the lock screen too.
- **The mouse:** **Super** with the wheel changes workspace, and with **Shift** it scrolls through the columns.
- **A window in a column:** niri keeps windows in columns on an endless strip. **Super + [** and **Super + ]** pull a window into the neighbouring column or push it out, and **Super + G** shows a column as tabs.

## Every key

This list is made from the keymap by `tools/keys-doc`, so it is complete. `pyre keys` (**Super + K**) shows the same list on screen, with your own keys in it.

### Launcher, menu and help

| Key | Action |
|---|---|
| `Super + Space` | Launcher: apps, and everything in the PyreOS menu |
| `Super + Alt + Space` | PyreOS menu: install, remove, update, style, setup, system |
| `Super + K` | Keybindings |

### Apps

| Key | Action |
|---|---|
| `Super + Enter` | Terminal |
| `Super + Shift + Enter` | Browser |
| `Super + Shift + B` | Browser |
| `Super + Shift + F` | Files |
| `Super + Shift + N` | Editor |
| `Super + Shift + T` | Activity (btop) |

### Shell (Noctalia)

| Key | Action |
|---|---|
| `Super + S` | Control center |
| `Super + Escape` | System menu: lock, log out, reboot, shut down |
| `Super + Ctrl + L` | Lock the screen |
| `Super + Ctrl + V` | Clipboard history |
| `Super + Ctrl + E` | Emoji |
| `Super + Ctrl + T` | Themes |
| `Super + Ctrl + Space` | Wallpaper |
| `Super + Ctrl + N` | Night light on or off |
| `Super + Shift + Space` | Show or hide the bar |
| `Super + ,` | Act on the latest notification |
| `Super + Shift + ,` | Dismiss all notifications |
| `Super + Ctrl + Alt + ,` | Do not disturb on or off |
| `Alt + Tab` | Window switcher |

### Capture

| Key | Action |
|---|---|
| `Print` | Screenshot: pick a region, window or screen |
| `Ctrl + Print` | Screenshot of the focused screen |
| `Shift + Print` | Screenshot of the focused window |
| `Alt + Print` | Start or stop a screen recording |

### Volume, brightness and media, with Noctalia's OSD

| Key | Action |
|---|---|
| `AudioRaiseVolume` | Volume up |
| `AudioLowerVolume` | Volume down |
| `AudioMute` | Mute |
| `AudioMicMute` | Mute the microphone |
| `AudioPlay` | Play or pause |
| `AudioPause` | Play or pause |
| `AudioStop` | Stop playback |
| `AudioPrev` | Previous track |
| `AudioNext` | Next track |
| `MonBrightnessUp` | Brightness up |
| `MonBrightnessDown` | Brightness down |

### Windows

| Key | Action |
|---|---|
| `Super + W` | Close the window |
| `Super + Q` | Close the window |
| `Super + F` | Fullscreen |
| `Super + Alt + F` | Full width: maximize the column |
| `Super + Ctrl + F` | Maximize the window to the screen edges |
| `Super + T` | Float or tile the window |
| `Super + Alt + T` | Switch focus between floating and tiled windows |
| `Super + O` | Overview of every window and workspace |
| `Super + Left` | Focus the column to the left |
| `Super + Right` | Focus the column to the right |
| `Super + Up` | Focus the window above |
| `Super + Down` | Focus the window below |
| `Super + Home` | Focus the first column |
| `Super + End` | Focus the last column |
| `Super + Shift + Left` | Move the column left |
| `Super + Shift + Right` | Move the column right |
| `Super + Shift + Up` | Move the window up |
| `Super + Shift + Down` | Move the window down |
| `Super + Shift + Home` | Move the column to the start |
| `Super + Shift + End` | Move the column to the end |

### Columns

| Key | Action |
|---|---|
| `Super + G` | Show the column as tabs, or stacked |
| `Super + Alt + G` | Move the window out of its column |
| `Super + Alt + Left` | Move the window into the column on the left, or out |
| `Super + Alt + Right` | Move the window into the column on the right, or out |
| `Super + Alt + Up` | Focus the window above in the column |
| `Super + Alt + Down` | Focus the window below in the column |
| `Super + Alt + Tab` | Next window in the column |
| `Super + Alt + Shift + Tab` | Previous window in the column |
| `Super + [` | Move the window into the column on the left, or out |
| `Super + ]` | Move the window into the column on the right, or out |

### Sizes

| Key | Action |
|---|---|
| `Super + R` | Cycle the column width presets |
| `Super + Shift + R` | Cycle the column width presets backwards |
| `Super + Ctrl + R` | Reset the window height |
| `Super + Ctrl + Shift + R` | Cycle the window height presets |
| `Super + -` | Column narrower |
| `Super + =` | Column wider |
| `Super + Shift + -` | Window shorter |
| `Super + Shift + =` | Window taller |
| `Super + Z` | Center the column |
| `Super + Shift + Z` | Center all visible columns |

### Workspaces

| Key | Action |
|---|---|
| `Super + 1` … `Super + 0` | Workspace 1 to 10 |
| `Super + Shift + 1` … `Super + Shift + 0` | Move the window to workspace 1 to 10 |
| `Super + Tab` | Next workspace |
| `Super + Shift + Tab` | Previous workspace |
| `Super + Ctrl + Tab` | The workspace you were on before |
| `Super + Page Down` | Next workspace |
| `Super + Page Up` | Previous workspace |
| `Super + Shift + Page Down` | Move the window to the next workspace |
| `Super + Shift + Page Up` | Move the window to the previous workspace |
| `Super + Ctrl + Page Down` | Move the whole workspace down |
| `Super + Ctrl + Page Up` | Move the whole workspace up |
| `Super + Wheel Down` | Next workspace |
| `Super + Wheel Up` | Previous workspace |
| `Super + Wheel Right` | Focus the column to the right |
| `Super + Wheel Left` | Focus the column to the left |
| `Super + Shift + Wheel Down` | Focus the column to the right |
| `Super + Shift + Wheel Up` | Focus the column to the left |

### Monitors

| Key | Action |
|---|---|
| `Ctrl + Alt + Tab` | Focus the next monitor |
| `Ctrl + Alt + Shift + Tab` | Focus the previous monitor |
| `Super + Shift + Ctrl + Left` | Move the window to the monitor on the left |
| `Super + Shift + Ctrl + Right` | Move the window to the monitor on the right |
| `Super + Shift + Ctrl + Up` | Move the window to the monitor above |
| `Super + Shift + Ctrl + Down` | Move the window to the monitor below |
| `Super + Shift + Alt + Left` | Move the workspace to the monitor on the left |
| `Super + Shift + Alt + Right` | Move the workspace to the monitor on the right |
| `Super + Shift + Alt + Up` | Move the workspace to the monitor above |
| `Super + Shift + Alt + Down` | Move the workspace to the monitor below |

### Session

| Key | Action |
|---|---|
| `Super + Shift + Escape` | Let the focused app take every shortcut, or stop |
| `Super + Shift + P` | Turn the monitors off |
| `Ctrl + Alt + Delete` | Quit niri, after a confirmation |
