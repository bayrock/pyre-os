# Upstream provenance: limine-snapper-sync

This package is vendored because it is only on the AUR (ADR 0008, ADR 0011). Drop the vendored copy if it reaches `extra`.

| Field | Value |
|---|---|
| Software | limine-snapper-sync `1.32.1`, <https://gitlab.com/Zesko/limine-snapper-sync>, tag commit `b4c0da2d4532a993809219f9e5d51a1fa85fcb93` |
| PKGBUILD | AUR `limine-snapper-sync`, <https://aur.archlinux.org/limine-snapper-sync.git>, commit `b3c82aded52032687a76922f2dee9497600818f2` (2026-10-03), maintainer Zesko |
| License | GPL-3.0. Upstream ships the GPLv3 text with no "or later" grant, so the package records `GPL-3.0-only`. |
| Build | GraalVM CE 25.0.4 `native-image` through Gradle. The GraalVM tarball is sha256-pinned. Gradle resolves Maven dependencies over the network at build time. |

## PyreOS delta from the AUR PKGBUILD

1. x86_64 only: the aarch64 source and checksum are removed.
2. `license` uses the SPDX identifier `GPL-3.0-only` instead of `GPL3`.
3. The `limine-dracut-support` optdepend is dropped, because PyreOS uses mkinitcpio.
4. The shell is restyled. The build and install steps are unchanged.

## Updating

Diff the new AUR PKGBUILD against the commit above, take the changes, re-apply the delta, and update this table. Bump `pkgver`/`pkgrel` with every change: `tools/build-pkgs` reuses an already-built file with the same version.
