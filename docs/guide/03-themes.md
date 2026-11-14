# Themes

A PyreOS theme recolors the shell, the window borders, the terminal, GTK apps and btop at once, and brings its own wallpaper. Windows that are already open change color too; nothing needs a restart.

## The themes

Every theme is the same cabin in the woods at a different hour or season.

| Theme | Mood | Mode |
|---|---|---|
| **Ember** (the default) | Firelight on a dark night | dark |
| **Birch** | The cabin on a summer morning | light |
| **Evergreen** | Dusk in the pines | dark |
| **Frost** | A snowy, moonlit night | dark |

Ember and Birch are the night and day of one theme: with either one, Noctalia's dark/light switch moves between the two.

## Switching

In the welcome panel, pick one under **Choose your light**. Or, in a terminal:

```
pyre theme list                    # the themes, the current one marked with *
pyre theme set frost               # switch, with its wallpaper
pyre theme set birch --keep-wallpaper
pyre theme current
```

Noctalia's settings window (**Super + Shift + ,**) offers more palettes in its theme settings, including ones made from your wallpaper. Choosing one there leaves the PyreOS themes; `pyre theme set` brings one back.

## What a theme does not change

The boot menu, the boot splash and the login screen always wear Ember: they belong to the machine, which can have several users with different themes. The login screen takes your look when you use Noctalia's "Sync" in its settings.

## Your own theme

A theme is a Noctalia palette: a JSON file of colors. Put your own in `~/.config/noctalia/palettes/` and choose it in Noctalia's settings. A file of yours there is never replaced by PyreOS.
