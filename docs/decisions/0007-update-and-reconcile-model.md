# ADR 0007: Plain pacman stays safe; reconcile units replace migrations

- Status: Accepted (implementation in P4; snapshot hooks in P2)
- Date: 2026-11-07

## Context

Safe updates are the project's top priority. Prior art among Arch-based desktops taught several lessons.

- **An update guard.** An ALPM hook aborts a raw `pacman -Syu` because snapshots and migrations happen only inside the distribution's own update command. Users who follow standard Arch practice are blocked, and the guard is easy to bypass.
- **One-way migrations.** 218 timestamped migration scripts run as the user. 73 of them call `sudo`, so system changes repeat for every user. None can be undone. Many sed-patch dotfiles in `$HOME`. Completion is tracked with an empty marker file per migration.
- **Upgrades that clobber `/etc`.** `etc-overrides` copies files over admin-edited `/etc` files on every upgrade.
- **Partial snapshots.** Snapshots cover `/` only, but migrations mutate `~/.config`.

## Decision

1. **Snapshot every pacman transaction.** `snap-pac` takes snapper pre/post snapshots of every transaction, and `limine-snapper-sync` makes those snapshots bootable. Plain `pacman -Syu` is therefore always a supported, snapshotted update path. PyreOS never ships an update guard.
2. **Reconcile instead of migrating.**
   - A reconcile unit is a `check` and `apply` pair that converges the system to a desired state.
   - **System** units run as root from a pacman hook, once per machine.
   - **User** units run at login from a systemd user service, without privileges.
   - Each scope stores a schema version. Fresh installs start at the current version.
   - Imperative one-offs must be idempotent and tested, inside the same framework.
3. **Never edit user files.** When a seeded stub must change, reconcile writes `<file>.pyre-new` and notifies the user.
4. **Admin files survive upgrades.** System configuration ships as drop-ins or as pacman `backup=()` files, never by copying over `/etc`.
5. **Snapshot home before user changes.** A snapper `home` config takes a snapshot before `pyre update` and before user reconcile, so rollback covers user state as well.
6. **`pyre update` is optional convenience.** It refreshes keyrings first, runs `-Syu` and optional AUR updates, runs user reconcile, verifies boot artifacts, and advises whether to reboot.

## Consequences

- Users can treat PyreOS as Arch. Documentation must state plainly that both `pacman -Syu` and `pyre update` are safe.
- System reconcile runs inside a pacman hook, so it must be fast, non-interactive, and must never call pacman. Package installs belong in package dependencies.
- Every unit needs a bats test that runs it twice and asserts the second run is a no-op. CI enforces this.
- Release testing must include an N-1 → N upgrade in a VM (ADR 0009).
