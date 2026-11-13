# ADR 0014: The `pyre` CLI, reconcile units, and the installed `[pyre]` repository

- Status: Accepted
- Date: 2026-11-10
- Implements: ADR 0007 (update and reconcile model) and part of ADR 0009 (repository)

## Context

P4 builds the lifecycle tooling that ADR 0007 describes. Four facts shape it:

- **Installed systems have no `[pyre]` repository yet.** Arch's `pacman.conf` belongs to the `pacman` package, as a `backup=()` file, and it has no drop-in directory. `Include =` works only inside a repository section.
- **limine-entry-tool loads its config in order** (`load_config` in `limine-common-functions`, 1.40.0). The order is `/usr/share/limine-entry-tool.d/*.conf`, `/etc/limine-entry-tool.conf`, `/etc/limine-entry-tool.d/*.conf`, then `/etc/default/limine` last. `KERNEL_CMDLINE[...] +=` appends and `=` replaces. pyre-install 0.2.0 writes `=` in `/etc/default/limine`, which drops every drop-in's kernel arguments.
- **snapper lets users snapshot through snapperd** when they are in the config's `ALLOW_USERS` or `ALLOW_GROUPS`. The installer creates the `home` config without either.
- **A restore with `RESTORE_METHOD=replace` is proven** for one flow (P2): boot the snapshot from Limine, then run `limine-snapper-sync --restore`.

## Decision

**CLI.** `/usr/bin/pyre` is a small bash dispatcher, shipped in `pyre-cli`.

- Each command is a file in `/usr/lib/pyre/commands/<name>` that defines `cmd_<name>`. Its first comment lines carry `# help:` and `# usage:` metadata.
- The shared library lives in `/usr/lib/pyre/lib/`.
- Commands run as the user and call `sudo` only for the privileged steps.
- The source lives in `src/cli/`, and the dispatcher also runs from the checkout.

**Reconcile units.** Units live in `/usr/lib/pyre/reconcile/{system,user}/NNN-<name>`. A unit is a bash file that sets `since=<schema version>` and defines `check` and `apply`. It may set `fresh=skip`, for an imperative one-off a fresh install does not need.

`pyre reconcile --system|--user` reads the scope's recorded version from `/var/lib/pyre/reconcile/system` or `~/.local/state/pyre/reconcile/user`:

| Recorded version | Units considered |
|---|---|
| none (fresh) | every unit except `fresh=skip` |
| V | units with `since > V` |

For each unit it considers, it runs `check`, then `apply` only if `check` fails, then `check` again, and stops on a failure. Afterwards it records the newest `since`, written atomically.

A unit runs when its version is new. After that the admin's later changes stand, and reconcile never re-asserts them on every update. `check` and `apply` are still idempotent, and each unit's bats test runs it twice.

**Triggers.**

- **System:** an ALPM hook in `pyre-cli` runs `pyre reconcile --system` after transactions that install or upgrade `pyre-*` packages. System units are fast and non-interactive, and never call pacman.
- **User:** `pyre-reconcile.service`, a systemd user unit that `pyre-cli` enables globally (`/usr/lib/systemd/user/default.target.wants/`), runs `pyre reconcile --user` at login.
- **Home snapshot:** when user units are pending, the user scope first takes a snapper `home` snapshot.
- **Installer:** `pyre-install` runs `pyre reconcile --system` in the chroot.

**Never edit user files.** When a user unit would change a file the user owns, it writes `<file>.pyre-new` beside it and sends a notification. `pyre doctor` lists the `.pyre-new` files.

**The installed `[pyre]` repository.**

- `pyre-install` appends a `[pyre]` section to the new system's `/etc/pacman.conf` once, after Arch's repositories: `SigLevel = Required DatabaseOptional` and `Include = /etc/pacman.d/pyre-mirrorlist`.
- `pyre-release` ships that mirrorlist as a `backup=()` file. Tests and admins can point it elsewhere without touching `pacman.conf`.
- Packages are signed. Until the release key exists, `tools/build-pkgs` signs with the development key, which `pyre-keyring` already trusts.
- Where the channel is hosted is still open; see Consequences.

**Kernel arguments.** `pyre-install` writes `KERNEL_CMDLINE[default]+=` in `/etc/default/limine`, so vendor drop-ins (`/usr/share/limine-entry-tool.d/`) and `pyre hw` drop-ins (`/etc/limine-entry-tool.d/50-pyre-hw.conf`) keep their arguments.

**Rollback.** `pyre rollback` lists the `root` and `home` snapshots with what each one would revert, meaning the pacman transaction or description that created it.

- **Booted into a root snapshot:** it runs the proven `limine-snapper-sync --restore` flow.
- **Booted normally:** it explains how to boot the snapshot from the Limine menu.
- **Home:** `pyre rollback --home N` reverts the user's files with `snapper -c home undochange N..0`.

## Consequences

- `pacman -Syu` alone runs system reconcile through the hook. `pyre update` adds the keyring-first order, a home snapshot, user reconcile, boot checks and reboot advice.
- **Version numbers are a contract.** A unit's `since` never changes after release. A new desired state is a new unit with a higher version.
- **Systems installed before P4** (test VMs only) have `=` in `/etc/default/limine` and no `ALLOW_GROUPS`. The first system unit fixes `ALLOW_GROUPS`, because PyreOS created that config. `/etc/default/limine` belongs to the admin, so `pyre doctor` reports `=` there instead of editing it.
- **Hosting.** The GitHub repository was private, so pacman could not fetch release assets from it (anonymous requests got 404). On 2026-11-12 the user decided to make the repository public; a pre-publication audit found no security reason to keep it private. The testing channel will be a GitHub Release on the public repository (ADR 0009). Until CI publishes it with a signing subkey, the mirrorlist ships commented out, and the VM tests serve `[pyre]` over local HTTP.
