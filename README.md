# PyreOS

PyreOS is a polished, keyboard-first Arch Linux desktop built on [Niri](https://github.com/niri-wm/niri) and [Noctalia](https://github.com/noctalia-dev/noctalia). It is a humble, community-run project that aims for:

- updates are safe, and plain `pacman -Syu` is always fine
- everything can be rolled back, including your home directory
- one cohesive look from boot splash to lock screen
- a codebase small enough to read in an afternoon

> **Status:** early development. The live ISO installs an encrypted, snapshot-protected system with the niri + Noctalia desktop, offline (P3 accepted). P4, lifecycle tooling, is in progress. See [docs/STATUS.md](docs/STATUS.md).

## Documents

- [Project brief](docs/PROJECT_BRIEF.md): mission, priorities, settled decisions
- [Architecture](docs/ARCHITECTURE.md): system design and repository layout
- [Roadmap](docs/ROADMAP.md): phases P0–P7 and exit criteria
- [Status](docs/STATUS.md) and [Handoff](docs/HANDOFF.md): current state and the next task
- [Building and testing](docs/BUILDING.md): ISO build and the QEMU/KVM test loop
- [Decisions](docs/decisions/): architecture decision records
- [Reference](docs/reference/): the development machine

## Contributing

Read [AGENTS.md](AGENTS.md) first. It contains the shared rules for humans and coding agents. Changes stay small, follow upstream Arch conventions, and are verified, usually in a VM, before being called done.

The repository is `https://github.com/bayrock/pyre-os.git` (branch `main`). "EmberOS" was the project's codename before it was renamed (ADR 0004).

## License

PyreOS's own code is licensed under the MIT License ([`LICENSE`](LICENSE)), and its artwork under CC BY-SA 4.0 ([`LICENSE-ARTWORK`](LICENSE-ARTWORK)). Two parts come from upstream and keep their upstream licenses:

- **`iso/`** is derived from archiso's `releng` profile ([`iso/UPSTREAM.md`](iso/UPSTREAM.md)) and is licensed under GPL-3.0-or-later, as archiso is. That includes its boot artwork.
- **`packages/limine-mkinitcpio-hook/` and `packages/limine-snapper-sync/`** are PKGBUILDs vendored from the AUR, whose submissions are 0BSD. They build GPL-3.0-only software.
