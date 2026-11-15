# Your machine

The settings that differ from one computer to the next: screens, night light, sleep, and another system on the same machine.

## Screens

niri arranges screens by itself, side by side. To place them yourself, add an `output` block per screen to `~/.config/niri/config.kdl`, below the include lines. `niri msg outputs` lists the names and the modes each screen offers.

```
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

- **`mode`** takes a size, and optionally a refresh rate exactly as `niri msg outputs` prints it. Without a rate, niri picks the highest one for that size.
- **`transform`** rotates a screen: `"90"`, `"180"` or `"270"`. A rotated 1920x1080 screen is 1080 wide when you set positions.
- **`variable-refresh-rate`** turns on VRR for screens that support it.

niri applies the file as you save it. If something is wrong it keeps the previous layout and says what it could not read; `niri validate` checks the file too.

## Night light

Night light takes the blue out of every screen, so the colors turn warmer and easier on the eyes in the evening. It is part of Noctalia, and it is off until you turn it on.

- **Right now:** **Super + Ctrl + N** turns the warm light on at once, and off again. A right-click on the control center's **Night Light** button does the same. It lasts until you log out.
- **Every evening:** turn on **Night Light** in the shell settings (in the launcher: `shell settings`), under Services. The screen then warms at 20:00 and returns to normal at 07:00, fading over an hour around each. A click on the control center's button follows the same schedule, until you log out.
- **Your own hours, or the real sunset:** the settings' Location page holds the two times. To follow the sun where you live, enter a place there and turn **Custom Schedule** off. PyreOS never looks your location up by itself.
- **How warm:** the night temperature, next to the Night Light switch. It starts at 4000 K, and a lower number is warmer.

Screenshots and recordings keep their true colors, because the filter is applied on the way to the screen.

## Sleep

- **Suspend** keeps the session in memory: `systemctl suspend`, or the power menu. The screen is locked when you wake the machine.
- **Hibernate** saves the session to disk and powers off: `systemctl hibernate`. It needs the swapfile that the installer creates when you answer yes to hibernation. After you unlock the disk at the next boot, your windows are back.

`swapon` shows whether a swapfile is there (`/swap/swapfile`). `pyre doctor` checks that the system can still resume from it.

## Windows on another disk

If another disk held Windows when you installed PyreOS, the boot menu has a **Windows** entry below PyreOS. PyreOS never writes to that disk.

- To add the entry later, or to list another system: `sudo limine-entry-tool --scan`.
- Windows keeps the hardware clock in local time and Linux keeps it in UTC, so each system shows the wrong time after the other ran. Tell Windows to use UTC (its `RealTimeIsUniversal` registry setting) rather than changing Linux.
- Windows's "fast startup" leaves its disks half-closed. Turn it off in Windows if you want to open them from PyreOS.

## Keep your settings

Everything you changed is in `~/.config`, in files that are yours. Keeping them in a git repository of your own, linked into place, lets you carry them to the next machine. PyreOS's defaults are not part of it: they stay in `/usr/share/pyre/defaults/` and update with the system.
