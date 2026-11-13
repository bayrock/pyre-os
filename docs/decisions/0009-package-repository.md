# ADR 0009: Signed `[pyre]` repository, CI-built, after Arch's repos

- Status: Accepted. Local repo in P1, testing channel in P4, public hosting in P7
- Date: 2026-11-07

## Context

PyreOS ships its defaults, CLI, themes, installer, hardware rules, and meta-packages as pacman packages, so it needs a signed repository.

A typical community setup builds packages in CI, signs them on merge, and uploads them to object storage behind a CDN, with channels promoted by a script. That is a good model.

Two patterns to avoid: a repository listed ahead of `[core]` that overrides Arch packages with patched or forked builds, and pointing users at a curated mirror of Arch.

## Decision

**Repository order.** `[pyre]` is listed after `[core]`, `[extra]` and `[multilib]`, and never replaces an Arch package. If PyreOS ever has to ship a modified upstream package, that needs its own ADR, and the package must be renamed.

**Signing.**
- A PyreOS primary key is kept offline.
- A signing subkey is held as a CI secret.
- `pyre-keyring` ships with the first release.
- Clients verify with `SigLevel = Required DatabaseOptional`.
- Development builds use a separate dev key that is marked as such and never trusted by release images.

**Builds.**
- GitHub Actions builds every package in a clean chroot (devtools) and runs namcap.
- Pushing a version bump publishes the package to `testing`.
- A promotion script moves verified packages to `stable` after the release checks pass.

**Hosting.**
- Start on GitHub Releases while the project is private and small. Copy the files rather than using symlinks, and avoid `:` in filenames.
- Move to object storage behind a CDN, for example Cloudflare R2, before public release.

**Release gate.** Every stable promotion requires:
- a passing N-1 → N VM upgrade test
- a passing fresh-install e2e test

## Consequences

- Arch mirrors serve the base system unchanged, so PyreOS has no mirror to maintain.
- Key management needs a documented procedure, including revocation, before public release.
- A CDN can cache files by name, so a rebuilt package must always bump `pkgrel`.
