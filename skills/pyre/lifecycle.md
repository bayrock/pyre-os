# Updates, snapshots, rollback and repair

PyreOS snapshots the system around every pacman transaction, and the snapshots can be booted from the boot menu. That makes most mistakes undoable, which is the reason to work this way: check, snapshot, change, check again.

The user's pages are `/usr/share/doc/pyre/guide/04-updates.md`, `05-software.md` and `07-troubleshooting.md` in the same folder.

## Passwords

`pyre update`, `pyre snapshot`, `pyre doctor`, `pyre install`, `pyre remove`, `pyre hw apply` and a system `pyre rollback` each ask for the user's password through `sudo`, for the steps that need root. Run them as the user, never as root and never with `sudo` in front. If you cannot show the user a password prompt, give them the command to run and read the output afterwards.

## Updating

```
pyre update
```

In order: it refreshes the keyrings, runs `pacman -Syu`, upgrades AUR packages when `paru` or `yay` is installed, snapshots the home folder, applies PyreOS's own changes (`pyre reconcile --user`), and checks that the system will boot (`pyre doctor --boot`). It ends by saying whether a reboot is needed.

- Plain `sudo pacman -Syu` is just as safe. The snapshots and the system reconcile come from pacman hooks either way. Never tell the user that pacman is unsafe here.
- Do not pass `--noconfirm` unless the user asked for an unattended update.
- Never run a partial upgrade (`pacman -Sy <package>`). That is Arch's rule, and it holds here.

**`.pyre-new` files.** When PyreOS has a suggested change for a file of the user's, it writes `<file>.pyre-new` beside it and leaves the user's file alone. `pyre doctor` lists them with a `diff` command. Show the user the difference, merge what they want into their file, then delete the `.pyre-new` file. `.pacnew` files in `/etc` are pacman's version of the same thing, for the administrator's files.

## Snapshots

```
pyre snapshot list
pyre snapshot create "before trying something"
```

The system (`/`) and the home folder have separate snapshots. A "pre" and a "post" snapshot surround every pacman transaction; a home snapshot is taken before PyreOS changes anything in the home folder.

## Rolling back

**Always ask before a rollback.** It discards what happened after the snapshot.

**The system,** after a bad update:

1. Reboot. In the boot menu, open **PyreOS → Snapshots** and boot the "pre" snapshot from before the update.
2. Log in and check that it works. Changes made now are temporary.
3. Run `pyre rollback`. The snapshot becomes the system again, and the broken state is kept as a backup snapshot.

Run from a normal boot, `pyre rollback` changes nothing: it lists the snapshots and these steps. The home folder is not touched by a system rollback.

**The home folder:**

```
pyre snapshot list          # the number, under "Home"
pyre rollback --home 42     # undo the changes to the home folder since snapshot 42
```

It takes a home snapshot first, so it can be undone too. For one file, prefer restoring just that file to rolling the whole home folder back.

## pyre doctor

```
pyre doctor
```

It prints `ok`, `warn` or `FAIL` per check, and exits 1 when a check failed. It covers: a boot entry, kernel and initramfs that match for each installed kernel; the hibernation resume offset; space on the boot partition; the snapper configs; whether PyreOS's reconcile state is current; `.pacnew` and `.pyre-new` files; failed system services; and the `[pyre]` repository.

Each failing line names its fix (often `sudo limine-update`). Do what the line says before trying anything else, and run `pyre doctor` again afterwards.

## Reconcile

`pyre reconcile` applies PyreOS's own small changes after an update: system ones from a pacman hook, the user's at login. Each is idempotent, and they never overwrite a user's file. There is rarely a reason to run it by hand:

```
pyre reconcile --user --dry-run     # what would change
pyre reconcile --user
```

## Software

```
pyre install              # the bundles, and which are installed
pyre install dev
pyre remove media
sudo pacman -S <package>
```

The bundles are `dev`, `media` and `office`. Everything else is a normal Arch package. PyreOS installs no AUR helper: if the user wants an AUR package, say that it comes from the AUR and let them decide; do not install `paru` or `yay` unasked.

The PyreOS menu's Install rows cover the usual extras, coding agents among them: Codex, opencode and Gemini CLI are Arch packages (`openai-codex`, `opencode`, `gemini-cli`). Claude Code is not in Arch's repositories. Its menu row runs Anthropic's own installer as the user, into `~/.local/bin` and `~/.local/share/claude`; pacman does not manage it, and it updates itself. `~/.local/bin` is on `PATH`.

## Development

```
pyre dev --status         # git identity, credential store, dev tools, GitHub, Rust
pyre dev                  # asks about each part that is missing; run it in a terminal
pyre dev git --name "Ada Lovelace" --email ada@example.org
```

git's settings are the user's own (`~/.config/git/config`); change them with `git config --global`, and never set a name or email the user did not give. Passwords and tokens that git asks for rest in the keyring (`credential.helper` is git's libsecret helper), which the login unlocks. `/usr/share/doc/pyre/guide/08-development.md` is the user's page about all this.

## Hardware

```
pyre hw            # the rules that match this machine, and what they would do
pyre hw apply      # install their packages and write their settings
```

The rules cover NVIDIA, AMD and Intel graphics. `pyre hw apply` is safe to run again and removes the settings of hardware that is gone. Do not hand-edit the files it writes (`50-pyre-hw.conf` under `/etc/mkinitcpio.conf.d/` and `/etc/limine-entry-tool.d/`).

## When the desktop does not start

From a text console (**Ctrl + Alt + F2**, log in):

- `journalctl --user -b -e` shows this boot's session log.
- `niri validate` checks the user's niri config. A broken one is the usual cause after an edit; move it aside and restore the stub: `cp /etc/skel/.config/niri/config.kdl ~/.config/niri/`.
- `pyre doctor` checks the system, and `pyre update` finishes an interrupted update.

If none of that helps, boot the last snapshot that worked and roll back.

## Boot and disks: ask first

The bootloader is Limine, with entries generated by `limine-entry-tool` and snapshot entries by `limine-snapper-sync`. The disk is encrypted with LUKS, and the kernel command line lives in `/etc/default/limine`. A mistake here can leave the machine unable to boot.

- Do not edit `/boot/limine.conf` by hand: it is generated. `sudo limine-update` regenerates it.
- In `/etc/default/limine`, kernel arguments are added with `+=`. A plain `=` on `KERNEL_CMDLINE[default]` drops the arguments PyreOS's hardware rules add.
- Never repartition, reformat, or change encryption without the user asking for exactly that.

## Reporting a problem

PyreOS is developed at <https://github.com/bayrock/pyre-os>. A useful report has the output of `pyre doctor` and what happened just before the problem. Leave out anything private.
