# ADR 0003: Derive the first live profile from archiso baseline

- Status: Superseded by ADR 0006 (2026-11-07). The provenance practice is kept; the source profile changes from `baseline` to `releng`
- Date: 2026-11-04

## Context

An archiso profile includes bootloader configuration and other files beyond a package list. Recreating this machinery from memory risks a profile that looks complete but cannot boot. archiso ships a `baseline` profile documented as the minimum live environment.

## Decision

Start from the official archiso `baseline` profile. Record the exact archiso package version and corresponding upstream source revision in the repository. Preserve required boot files and make a small EmberOS-owned delta: distribution metadata, package selection, and only those live defaults needed for the build foundation.

## Consequences

This keeps boot behavior aligned with Arch's maintained tooling and makes the source relationship auditable. The copied source needs deliberate updates when archiso changes; compare against upstream during maintenance. Do not claim byte-for-byte reproducibility of rolling package contents: the initial goal is a repeatable profile/build process with package and source inputs recorded.

## References

- https://archlinux.org/packages/extra/any/archiso/
- https://wiki.archlinux.org/title/Archiso
- https://github.com/archlinux/archiso/blob/master/docs/README.profile.rst
- https://man.archlinux.org/man/mkarchiso.1.en
