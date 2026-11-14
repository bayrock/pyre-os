# Your machine

The settings that differ from one computer to the next: screens, sleep, and another system on the same machine.

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
