# ADR 0010: `pyre-release` owns identity in `/usr`, linked from `/etc/os-release` by a pacman hook

- Status: Accepted
- Date: 2026-11-07

## Context

PyreOS must identify itself as `ID=pyreos`, `ID_LIKE=arch` (ADR 0004). The relevant facts on Arch, checked on 2026-11-07:

- `filesystem` owns `/usr/lib/os-release`.
- No package owns `/etc/os-release`. systemd's `tmpfiles.d/etc.conf` creates it at boot and on package installs, as `L /etc/os-release - - - - ../usr/lib/os-release`, a symlink that is created only when the file is missing.
- os-release(5) says `/etc/os-release` takes precedence, and it should be a relative symlink into `/usr/lib`.

| Option | Problem |
|---|---|
| Override `filesystem`, as CachyOS does | Replaces an Arch package, against ADR 0009 |
| Package-owned `/etc/os-release` file | Conflicts with the existing symlink whenever it is installed in a later transaction than `systemd`, as archinstall does |
| `tmpfiles.d` `L+` entry sorted before `etc.conf` | Works, but systemd-tmpfiles logs "Duplicate line… ignoring" on every boot (tested) |
| Overwrite the file from a package scriptlet | Clobbers `/etc`, which ADR 0007 forbids |

## Decision

`pyre-release` installs:

- `/usr/lib/pyre/os-release`, the identity data
- an ALPM hook and script that point `/etc/os-release` at `../usr/lib/pyre/os-release`

The script changes `/etc/os-release` only when it is missing or is a symlink to Arch's `../usr/lib/os-release`. An admin's own file, or a symlink pointing anywhere else, is never touched.

When `pyre-release` is removed, a pre-transaction hook restores the Arch symlink, but only if it still points at the PyreOS file. Arch's `/usr/lib/os-release` stays in place unchanged as the fallback.

## Consequences

- Files are never contested, and no Arch package is replaced. Converting an existing Arch install works with plain `pacman -S pyre-release`.
- Tools that read only `/usr/lib/os-release` see Arch. That is acceptable, because os-release(5) tells readers to prefer `/etc`.
- The hook script has a bats test that runs it twice and covers the admin-file case.
