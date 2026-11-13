# ADR 0001: Arch and archiso as the distribution foundation

- Status: Accepted for initial development
- Date: 2026-11-04

## Context

The project is intended to remain an independent Arch-based distribution and needs a standard, repeatable way to produce a live image. The host's own boot design and package selection are machine-specific and should not dictate the new distribution's foundations.

## Decision

Use Arch Linux x86_64, systemd, pacman and official Arch repositories as the initial base. Use upstream archiso profiles and tooling for live images. Keep the initial profile minimal and own only necessary profile changes and small distribution packages.

## Consequences

This preserves compatibility with Arch packaging and upstream infrastructure. Rolling updates require careful lifecycle and recovery work before daily-driver use. Installed-system partitioning, bootloader, snapshots, package signing, and installer are deferred until the relevant milestones.

## References

- https://archlinux.org/packages/extra/any/archiso/
- https://wiki.archlinux.org/title/Archiso
- https://gitlab.archlinux.org/archlinux/archiso
