# Upstream profile provenance

This directory is derived from archiso's `configs/releng` profile, the profile Arch uses for its official install media (ADR 0006).

| Field | Value |
|---|---|
| Upstream | <https://gitlab.archlinux.org/archlinux/archiso> |
| License | GPL-3.0-or-later, as archiso (`pacman -Qi archiso`); this directory keeps it |
| Release | archiso `v91`, the version of the `archiso` 91-1 package in `extra` that builds this profile |
| Tag commit | `723da192226e1c9d5def9168f13332793c82a85e` |
| Copied from | `/usr/share/archiso/configs/releng/` of `archiso` 91-1 (`pacman -Qkk archiso`: 0 altered files) on 2026-11-07 |

The profile tracks the installed `mkarchiso`, not upstream `master`, so the profile format always matches the builder. Upstream `v92` exists but is not yet packaged.

## PyreOS delta

Everything not listed here is byte-identical to upstream, including symlinks.

1. **Removed** `packages.aarch64`. PyreOS is x86_64 only.
2. **`profiledef.sh`:**
   - `iso_name`, `iso_label`, `iso_publisher` and `iso_application` carry PyreOS metadata.
   - `kernel_params_aarch64` is replaced by `kernel_params_x86_64="console=ttyS0,115200 console=tty0"`. mkarchiso substitutes it for `%KERNEL_PARAMS%` in every boot entry (systemd-boot, GRUB, GRUB loopback, syslinux), so the kernel log and a serial getty reach `build/vm/<name>/serial.log`. `tty0` is listed last, so it stays `/dev/console` for the interactive session.
3. **`pacman.conf`:** adds a `[pyre]` section after every Arch repository, at `Server = file://@PYRE_REPO_DIR@`, with `SigLevel = Optional TrustAll`. `tools/build-iso` substitutes the absolute `build/repo` path into `build/pacman.conf` and passes it with `-C`, so no machine path is committed.
4. **`packages.x86_64`:** appends `pyre-base`, which brings in `pyre-release` (os-release identity, ADR 0010) and `pyre-keyring`, and `pyre-installer` (ADR 0011).
5. **`offline.x86_64`** (new, ADR 0006): the packages `pyre-install` needs without a network. `tools/build-iso` stages a copy of this profile in `build/profile/`, resolves the dependency closure from one explicit mirror (`PYRE_MIRROR`), and adds the packages with Arch's `core.db`/`extra.db` and the `pyre.db` at `airootfs/opt/pyre-offline/`. `pyre-install` points the live `pacman.conf` at that directory.
6. **Trimmed guest tools** (P2). The live medium does not need cloud or hypervisor guest agents, so these are removed:
   - packages: `cloud-init`, `hyperv`, `open-vm-tools`, `qemu-guest-agent`, `virtualbox-guest-utils-nox`
   - their enablement symlinks in `airootfs/etc/systemd/system/`: `cloud-init.target.wants/` (5 units), and `hv_fcopy_daemon`, `hv_kvp_daemon`, `hv_vss_daemon`, `vboxservice`, `vmtoolsd` and `vmware-vmblock-fuse` from `multi-user.target.wants/`
7. **No `systemd-time-wait-sync`** (P2): its `sysinit.target.wants/` symlink is removed. releng orders `pacman-init.service` after `time-sync.target`, so without a network the keyring never initialized and offline installs hung, as did getty on other VTs. `systemd-timesyncd` still syncs the clock whenever a network is available.
8. **PyreOS boot menus and motd** (P4): the systemd-boot, GRUB and syslinux entries say "PyreOS install medium" instead of "Arch Linux install medium", and the live `/etc/motd` points at `pyre-install`. Arch's trademark policy does not let a derivative present itself as Arch.
9. **Ember boot splash** (P5, ADR 0015): `syslinux/splash.png` is PyreOS artwork, the cabin at night that `tools/render-wallpaper` renders (640×480). `syslinux/archiso_head.cfg`'s `MENU COLOR` lines use Ember's colors. The UEFI menu is systemd-boot's text menu, which has no artwork.

`tools/check-profile` enforces the serial console, the required files, `[pyre]` as the last repository, and the presence of `pyre-base`.

## Updating

When the `archiso` package updates, compare this directory against the new `/usr/share/archiso/configs/releng/`, using `diff -r --no-dereference`. Take upstream changes, re-apply the delta above, and update the release, commit, and date in this file. Never overwrite the directory blindly.
