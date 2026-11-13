# ADR 0008: Encrypted btrfs, Limine, and snapper as installer defaults

- Status: Accepted; amended by ADR 0011 (UEFI only, no UKI for now, who sets up each part)
- Date: 2026-11-07

## Context

Rollback is the top priority, so the default storage design needs cheap snapshots, and those snapshots must be bootable. The reference machine already runs LUKS2, btrfs, Limine, and limine-snapper-sync, and that combination is proven in daily use. Every component except `limine-snapper-sync` is in Arch's official repositories; `limine-snapper-sync` is AUR-only.

## Decision

**Partitions.** The disk is GPT with a 2 GiB FAT32 ESP mounted at `/boot`. The rest of the disk is LUKS2 containing btrfs.

**Subvolumes.** `@` `/`, `@home` `/home`, `@log` `/var/log`, `@pkg` `/var/cache/pacman/pkg`, and `@snapshots`. Cache data gets nested subvolumes so it never enters snapshots. Mount options are `compress=zstd:3,noatime`.

**Swap.** zram by default. When the user chooses hibernation, the installer also creates a btrfs swapfile with the correct `resume_offset`.

**Initramfs.** mkinitcpio with systemd hooks (`systemd`, `sd-vconsole`, `sd-encrypt`). This allows TPM2/FIDO2 unlock to be added later. Plymouth is themed.

**Bootloader.** Limine, with `limine-snapper-sync` turning snapshots into boot entries. Whether to use UKI is decided during P2 testing. Kernels are `linux` as the default plus `linux-lts` as a fallback entry, with no custom kernel.

**Snapper.** Two configs:

| Config | Snapshots taken | Retention |
|---|---|---|
| `root` | `snap-pac` pre/post | about 10 |
| `home` | before `pyre update` and before user reconcile | about 5 |

The timeline is off by default.

**Dual-boot.** If an existing Windows ESP is detected on any disk, add a Limine chainload entry. PyreOS never modifies the other disk.

## Consequences

- `limine-snapper-sync` is packaged in `packages/` from its AUR PKGBUILD and tracked against upstream. If it reaches `extra`, the vendored copy is dropped.
- A 2 GiB ESP limits how many snapshot boot entries can carry kernel copies. Tune the cap during P2.
- A full-disk erase is the only supported layout at first. Install alongside an existing OS on the same disk is a later feature.
- The firewall choice is deliberately left to a separate P2 ADR.
