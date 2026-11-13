# ADR 0011: archinstall owns disks and the base system; `pyre-install` owns the boot stack

- Status: Accepted
- Date: 2026-11-08
- Amends: ADR 0006 (installer split) and ADR 0008 (UEFI only, no UKI in P2)

## Context

ADR 0006 asked whether archinstall can express ADR 0008 before `pyre-install` relies on it. On 2026-11-08 we read the source of `archinstall` 4.5-1, the exact package the ISO ships, alongside `limine-entry-tool` 1.40.0 and `limine-snapper-sync` 1.32.1 from upstream GitLab.

| ADR 0008 requirement | archinstall 4.5, as read in the source | Gap |
|---|---|---|
| GPT, 2 GiB FAT32 ESP at `/boot`, LUKS2 partition | Yes, through `manual_partitioning` `device_modifications` with exact sector-aligned sizes. LUKS2 uses `argon2id`, with `iter_time` defaulting to 10000 ms. | Set `iter_time` to 2000 ms, cryptsetup's default, so unlocks do not take 10 s. |
| btrfs `@ @home @log @pkg @snapshots` | Yes. It accepts any list of `{name, mountpoint}` subvolumes. | — |
| `compress=zstd:3,noatime` | Yes. Free-form `mount_options` on the partition apply to every subvolume, and `genfstab` 31 drops `subvolid=`. | — |
| systemd initramfs with `sd-encrypt` | **No.** Without a FIDO2 `hsm_device`, `Installer.mkinitcpio()` rewrites `systemd` to `udev` and inserts busybox `encrypt`, and the kernel command line uses `cryptdevice=`. | `pyre-install` owns `HOOKS` and the command line (`rd.luks.name=`). |
| Limine plus `limine-snapper-sync` | **Partly.** It installs Limine, but writes its own static `limine.conf` under `EFI/arch-limine/` (or `EFI/BOOT/`), an `/etc/pacman.d/hooks/99-limine.hook`, and an NVRAM entry. `limine-entry-tool` and `limine-snapper-sync` manage `$ESP_PATH/limine.conf` and their own EFI deploy, so the two would fight. | Run archinstall with `--skip-boot`. `pyre-install` installs the bootloader with `limine-entry-tool`. |
| snapper with `@snapshots` | **No.** `setup_btrfs_snapshot()` runs `snapper create-config` for `/` and `/home`, which needs a nested `.snapshots` and so conflicts with a mounted `@snapshots`. It also enables `snapper-timeline.timer`, which ADR 0008 turns off. | `pyre-install` creates the snapper configs. |
| zram | Yes, but it writes `/etc/systemd/zram-generator.conf`, which belongs to the admin. | `pyre-base` ships a vendor drop-in in `/usr/lib/systemd/zram-generator.conf.d/` instead (zram-generator.conf(5)). |
| Users, sudo, hostname, locale, keymap, timezone, NetworkManager, fstab | Yes. | — |
| Offline install | `pacstrap -C /etc/pacman.conf -K`, so the live ISO's `pacman.conf` chooses the repositories. Without `-P`, the target keeps the stock `pacman.conf`. | The ISO's `pacman.conf` points at the offline repo (step 4 of P2). |

Other facts that shape the design:

- archinstall does not unmount on exit. `custom_commands` run *before* `genfstab`, so `pyre-install` does its steps after archinstall returns, while the target is still mounted at `/mnt`.
- `limine-entry-tool` and its `limine-install` are UEFI-only. `limine-mkinitcpio-hook` provides `sd-btrfs-overlayfs` for systemd initramfs, so read-only snapshots can boot with an overlay. It also replaces mkinitcpio's `90-mkinitcpio-install.hook` by putting a hook with the same name in `/etc/pacman.d/hooks/`.
- `limine-mkinitcpio-hook` installs `/usr/local/bin/mkinitcpio`, an interactive wrapper. Packages must not own files in `/usr/local`, so our vendored build drops that wrapper.
- Both tools are Java, compiled with GraalVM `native-image`. Their AUR PKGBUILDs download a pinned GraalVM tarball (sha256-checked) and resolve Maven dependencies through Gradle at build time.

## Decision

**archinstall** runs silently with `--config`, `--creds` and `--skip-boot`. It owns everything that touches the disk, plus base system configuration:

- partitions, LUKS2 (`iter_time` 2000), btrfs, the subvolumes and mounts of ADR 0008
- `pacstrap` of `base`, `linux`, `linux-lts`, firmware and `pyre-base`
- hostname, locale, keymap, timezone, users, sudo, NetworkManager
- `fstab`

Its bootloader, swap, snapshot, Plymouth, profile and custom-command features are not used.

**`pyre-install`** then runs these steps in `arch-chroot /mnt`, in this order:

1. It writes `HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems sd-btrfs-overlayfs fsck)` into `/etc/mkinitcpio.conf`. The installer creates that file, and the admin owns it afterwards.
2. It writes `/etc/default/limine` with `ESP_PATH=/boot` and `KERNEL_CMDLINE[default]` built from the LUKS UUID: `rd.luks.name=<uuid>=root root=/dev/mapper/root rootflags=subvol=@ rw`.
3. It creates the snapper `root` config for the flat `@snapshots` layout, and a `home` config. Both have `TIMELINE_CREATE=no` and the ADR 0008 limits.
4. It installs the boot stack from the offline repo: `limine`, `limine-mkinitcpio-hook`, `limine-snapper-sync`, `efibootmgr`. Their pacman hooks deploy Limine to the ESP, build the initramfs, and write the entries, after steps 1–3, so they see the final config. `snap-pac` follows in its own transaction, with `SNAP_PAC_SKIP=y`. pacman runs the post hook of a package installed in the same transaction, which would otherwise leave a stray snapshot 1.
5. It runs `limine-update` once more for a consistent final state, and enables `snapper-cleanup.timer`. Snapshot entries are synced by `limine-snapper-sync`'s snapper plugin on every snapshot create or delete. Its optional inotify watcher service is not enabled.

**Firmware.** Installed systems are **UEFI only**, because the boot tooling is UEFI only. `pyre-install` refuses to run on BIOS with a clear message. The ISO itself still boots under BIOS, for rescue.

**UKI.** No UKI for now (`ENABLE_UKI=no`). UKIs pay off with Secure Boot and TPM2 PCR policies, which come after 1.0. Snapshot entries need a kernel and initramfs either way.

**Rollback.** `limine-snapper-sync` uses `RESTORE_METHOD=replace`. With the flat layout, a restore replaces `@` and leaves `@snapshots` untouched. Verified on 2026-11-08: booted into snapshot 2, then `limine-snapper-sync --restore` snapshotted it to a new `@` and kept the old `@` as backup snapshot 3. It also moved the nested `var/lib/portables` and `var/lib/machines` subvolumes across.

## Consequences

- The dangerous disk code stays upstream. `pyre-install` owns about five small, idempotent steps, and the e2e test checks every one.
- The boot stack takes over `/boot/limine.conf` and the initramfs. Plain `pacman -Syu` keeps entries and snapshots in sync through the vendored packages' hooks, with no PyreOS wrapper.
- Vendoring the two Limine tools needs clean-chroot builds (`devtools`), with network access for Gradle. CI builds them in the throwaway Arch container with `makepkg --syncdeps`.
- Building the JSON config for a different archinstall version is a tested change. The generator targets the pinned 4.5 schema.
