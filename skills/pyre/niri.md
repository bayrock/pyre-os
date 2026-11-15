# niri: keys, screens, windows

niri is the compositor. It places windows side by side in columns on an endless horizontal strip, with workspaces stacked vertically on each screen. PyreOS keeps niri's own behavior, so niri's documentation applies: <https://github.com/niri-wm/niri/wiki>. The keys are PyreOS's own (`pyre keys --list`), not the ones niri's wiki lists.

## The files

```text
~/.config/niri/config.kdl                the user's file: edit this one
/usr/share/pyre/defaults/niri/pyre.kdl   defaults: input, layout, window rules (read-only)
/usr/share/pyre/defaults/niri/binds.kdl  the default keymap (read-only)
~/.config/niri/noctalia.kdl              the theme's colors, written by Noctalia (do not edit)
```

The user's file starts with two `include` lines: the PyreOS defaults, then the theme colors. Keep both, and write every change below them. Later settings override earlier ones (niri's "Configuration: Include" wiki page has the rules):

- **Most sections merge setting by setting.** `layout { gaps 6; }` changes the gaps and leaves the rest of `layout` as it was. A flag is turned off with `false`.
- **A key bound again replaces that key's default;** the other keys stay.
- **`window-rule`, `output` and `workspace` blocks are added** as they are, after the defaults' own.
- **A few sections are replaced whole, not merged:** `preset-column-widths`, `struts`, each subsection of `animations`, and the pointing-device sections of `input` (`touchpad`, `mouse` and the like). Repeat the default settings that should stay.

Read the defaults before changing anything, so the change overrides the right setting.

## Apply and check

niri applies the file when it is saved. If the file has an error, niri keeps the previous config and shows a notice. **After every edit, run:**

```
niri validate
```

Fix whatever it reports before telling the user the change is done.

Read-only queries:

```
niri msg outputs          # screens: names, modes, positions
niri msg windows          # open windows, with the app ID and title for window rules
niri msg layers           # shell surfaces, such as Noctalia's bar
niri msg --help           # every other query
```

Add `--json` (`niri msg --json outputs`) when a script reads the answer; the plain output is for people and may change.

## Keys

`pyre keys --list` prints every key with what it does, the defaults and the user's own; `/usr/share/doc/pyre/guide/02-keys.md` explains the keymap. `Mod` is the Super key. The defaults follow macOS and the Hyprland-based Arch desktops (**Super + W** closes, **Super + F** is fullscreen, **Super + 1** is the first workspace), so a user from there needs few changes. Before binding a key, check what it does now, and tell the user what the new bind replaces.

```kdl
binds {
    // A new key, with the description the key list (Super + K) shows
    Mod+B hotkey-overlay-title="Browser" { spawn "firefox"; }
    // Replaces the default editor key
    Mod+Shift+N hotkey-overlay-title="Editor" { spawn "foot" "hx"; }
}
```

**Super + C**, **V**, **X** and **A** are unbound on purpose: copy and paste are the apps' own **Ctrl** keys, and niri cannot press keys for an app.

`spawn` takes the program and each argument as separate strings: `spawn "nautilus" "--new-window"`. For a shell command line, use `spawn "sh" "-c" "..."`.

niri documents no way to remove a default key from the user's file, only to bind it again. If the user wants a key to do nothing, say so and ask what it should do instead.

## Screens

niri arranges screens side by side by itself. To place them, set a mode, rotate one or turn on VRR, add an `output` block per screen. Take the name and the mode exactly as `niri msg outputs` prints them.

```kdl
output "DP-1" {
    mode "2560x1440@143.912"
    position x=0 y=0
    variable-refresh-rate
}
output "HDMI-A-1" {
    transform "270"
    position x=2560 y=0
}
```

- Without a refresh rate in `mode`, niri picks the highest one for that size.
- `transform` is `"90"`, `"180"` or `"270"`. A rotated 1920x1080 screen is 1080 wide when setting positions.
- For anything else an output takes (scaling, turning one off), read niri's "Configuration: Outputs" wiki page instead of guessing a setting's name.

`/usr/share/doc/pyre/guide/06-your-machine.md` is the user's page for this.

## Window rules

Find the window's app ID and title with `niri msg windows`, then add a rule:

```kdl
window-rule {
    match app-id="org.gnome.Calculator"
    open-floating true
}
```

The defaults already round every window's corners and float Noctalia's settings window, portal dialogs and Firefox's picture-in-picture.

## Layout and input

The defaults set 12 px gaps, column widths of a third, a half and two thirds, a 3 px focus ring and no border. Touchpads tap to click and scroll naturally.

```kdl
layout {
    gaps 6
}
```

A `touchpad` block is replaced whole (see above), so one that only changes the scroll direction must repeat `tap`:

```kdl
input {
    touchpad {
        tap
        // natural-scroll is left out, so scrolling is no longer reversed
    }
}
```

The keyboard layout is the system's, chosen at install time (`localectl status` shows it). niri reads it from there because the defaults leave the `xkb` block empty. niri's "Configuration: Input" wiki page documents setting a layout for the session instead.

The focus ring's colors come from the theme (`noctalia.kdl`). Setting them in `config.kdl` works, but they stop following theme changes; say so before doing it.

## Screenshots and recording

- **Print** picks a region, window or screen; **Ctrl + Print** takes the focused screen; **Shift + Print** takes the focused window. Screenshots go to `~/Pictures/Screenshots` and to the clipboard.
- **Alt + Print** starts or stops a screen recording through `pyre-record`. The recorder (`gpu-screen-recorder`) is an optional install; without it the key shows a notification that says so. The first recording asks which screen or window to record. Recordings go to `~/Videos`.
