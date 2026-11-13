# ADR 0006: Own ISO with a thin installer driving archinstall

- Status: Accepted; the archinstall/`pyre-install` split is amended by ADR 0011
- Date: 2026-11-07
- Supersedes: ADR 0003, for the source profile

## Context

PyreOS should feel like a real distribution: boot the ISO, answer a few questions, and reboot into the desktop. The alternative was a layer installed on top of vanilla Arch. Installers are high-stakes code, because disk mistakes destroy data, and the project wants a small codebase.

Other desktop distributions' ISOs install with their own scripts, some by unpacking a prebuilt root image. Arch's own `archinstall` (4.5 in `extra`) is maintained upstream, accepts a JSON configuration for unattended runs, and covers disk layout, LUKS, btrfs, and bootloader installation.

## Decision

- **ISO profile.** Build the ISO with archiso from a profile in `iso/` derived from the official **`releng`** profile. `releng` is Arch's install-media profile and already carries networking and installation tooling. `baseline` is a minimal boot demonstrator full of cloud and hypervisor guest agents.
- **Provenance.** Record the upstream revision and the full delta in `iso/UPSTREAM.md`.
- **Offline repo.** The ISO carries an offline local repo with the complete default package set, so installs need no network.
- **Installer.** `pyre-install` is a thin gum TUI. It:
  1. collects choices: disk, passphrase, user, hostname, locale and timezone, bundles, autologin, hibernation
  2. shows a destructive-action confirmation naming the exact disk model and size
  3. writes an archinstall JSON config and runs archinstall non-interactively
  4. finishes with `pyre hw apply` and `pyre reconcile --system` in the chroot
- **Unattended mode.** `--config <file>` runs the same flow without prompts. The e2e tests use it.

## Consequences

- Arch maintains the dangerous code paths, and PyreOS owns the UX and the defaults.
- The archinstall config schema can change between releases. The ISO pins the archinstall version it was built with, and the generator is tested against it.
- Before relying on archinstall in P2, verify that it supports Limine, the exact btrfs subvolume layout, LUKS2, and snapper. Anything missing becomes a small, tested post-step owned by `pyre-install`.
- A GUI installer such as Calamares is out of scope.
