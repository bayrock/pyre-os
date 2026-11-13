# Upstream provenance: limine-mkinitcpio-hook

This package is vendored because it is only on the AUR (ADR 0008, ADR 0011). Drop the vendored copy if it reaches `extra`.

| Field | Value |
|---|---|
| Software | limine-entry-tool `1.40.0`, <https://gitlab.com/Zesko/limine-entry-tool>, tag commit `35dab4b732861f5e8d307a1a7873856a877913aa` |
| PKGBUILD | AUR `limine-mkinitcpio-hook`, <https://aur.archlinux.org/limine-mkinitcpio-hook.git>, commit `94ffde9c60808595b287edf9d4219da202a85a7a` (2026-09-27), maintainer Zesko |
| License | GPL-3.0. Upstream ships the GPLv3 text with no "or later" grant, so the package records `GPL-3.0-only`. |
| Build | GraalVM CE 25.0.4 `native-image` through Gradle. The GraalVM tarball is sha256-pinned. Gradle resolves Maven dependencies over the network at build time. |

## PyreOS delta from the AUR PKGBUILD

1. x86_64 only: the aarch64 source and checksum are removed.
2. `license` uses the SPDX identifier `GPL-3.0-only` instead of `GPL3`.
3. `/usr/local/bin/mkinitcpio` is removed. Packages must not own files under `/usr/local`, and the wrapper only prints a warning and prompts interactively.
4. The `journalctl-desktop-notification` optdepend, an AUR package, is dropped.
5. The shell is restyled. The build and install steps are unchanged.

## Updating

Diff the new AUR PKGBUILD against the commit above, take the changes, re-apply the delta, and update this table. Bump `pkgver`/`pkgrel` with every change: `tools/build-pkgs` reuses an already-built file with the same version.
