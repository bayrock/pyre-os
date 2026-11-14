# Updates and snapshots

PyreOS takes a snapshot of the system before every update, so a bad update is a reboot away from undone.

## Updating

```
pyre update
```

It refreshes the keyrings, upgrades everything with pacman, upgrades AUR packages if you use `paru` or `yay`, applies any PyreOS changes to your setup, and checks that the system will boot. Plain `sudo pacman -Syu` is just as safe: the snapshot and the PyreOS changes come from pacman hooks either way.

Update every week or two. Arch moves fast, and small steps are easier than big ones.

**`.pyre-new` files:** PyreOS never overwrites a config file of yours. When it has a suggested change for one, it saves the new version next to it as `<file>.pyre-new`, and `pyre doctor` lists them. Compare the two when you have a moment, keep what you like, then delete the `.pyre-new` file.

## Snapshots

The system (`/`) and your home folder have separate snapshots.

- **Automatic:** a "pre" and a "post" snapshot of the system around every pacman transaction, and a snapshot of your home before PyreOS changes anything in it.
- **By hand:** `pyre snapshot create "before trying something"`.
- **List them:** `pyre snapshot list`.

## Rolling back the system

If an update breaks something:

1. Reboot. In the boot menu, open **PyreOS → Snapshots**, pick the "pre" snapshot from before the update, and boot it.
2. Log in and check that everything works. Changes you make now are temporary.
3. Run `pyre rollback`. The snapshot becomes your system again, and the broken one is kept as a backup.

Your home folder is not touched by a system rollback.

## Rolling back your home

To undo changes to your files since a home snapshot:

```
pyre snapshot list            # find the number under "Home snapshots"
pyre rollback --home 42
```
