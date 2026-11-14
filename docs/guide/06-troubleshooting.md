# Troubleshooting

## Check the system

```
pyre doctor
```

It checks that the kernels, the boot entries, the snapshots and the PyreOS setup agree, and says what to do about anything that does not. The welcome panel's **Check the system** runs it too.

## After a bad update

Boot the snapshot from before the update, then run `pyre rollback`. The Updates and snapshots page has the steps.

## The desktop does not start

At the login screen, or on a black screen, press **Ctrl + Alt + F2** for a text console. Log in, then:

- `journalctl --user -b -e` shows this boot's session log.
- `pyre doctor` checks the system.
- `pyre update` finishes an interrupted update.

**Ctrl + Alt + F1** returns to the login screen.

## Undo a change to your config

PyreOS's defaults stay in `/usr/share/pyre/defaults/`, and your changes are in `~/.config`. Your files there start as short stubs that load the defaults, and the original stubs are kept in `/etc/skel/.config`. To go back to the defaults for an app, put its stub back, for example:

```
mv ~/.config/niri/config.kdl ~/config.kdl.mine
cp /etc/skel/.config/niri/config.kdl ~/.config/niri/
```

Your home snapshots (`pyre snapshot list`) hold older versions of your files too.

## The theme looks wrong

`pyre theme set ember` puts the default theme back. If a terminal kept old colors, open a new one.

## Asking for help

PyreOS is developed at <https://github.com/bayrock/pyre-os>. When you report a problem, include the output of `pyre doctor`, and what you did just before it happened. Arch's wiki, <https://wiki.archlinux.org>, answers most questions about the system underneath.
