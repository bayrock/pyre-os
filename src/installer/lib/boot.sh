# shellcheck shell=bash
# The boot-stack steps pyre-install owns after archinstall returns (ADR 0011).
# archinstall leaves the target mounted at TARGET with the LUKS volume open.

TARGET="${TARGET:-/mnt}"
# plymouth after systemd and kms, before sd-encrypt: the splash asks for the passphrase.
readonly INITRAMFS_HOOKS='base systemd autodetect microcode modconf kms plymouth keyboard sd-vconsole block sd-encrypt filesystems sd-btrfs-overlayfs fsck'
readonly BOOT_STACK=(limine limine-mkinitcpio-hook limine-snapper-sync efibootmgr)

in_target() {
  arch-chroot "$TARGET" "$@"
}

# The LUKS partition on the install disk.
luks_partition() {
  lsblk -nlpo NAME,FSTYPE "${CFG[disk]}" | awk '$2 == "crypto_LUKS" { print $1; exit }'
}

# kernel_cmdline LUKS_UUID [RESUME_OFFSET]: the command line for every Limine
# entry. With an offset, the kernel resumes from the hibernation swapfile.
kernel_cmdline() {
  local cmdline="rd.luks.name=$1=root root=/dev/mapper/root rootflags=subvol=@ rw rootfstype=btrfs zswap.enabled=0"
  [[ -z "${2:-}" ]] || cmdline+=" resume=/dev/mapper/root resume_offset=$2"
  cmdline+=" quiet splash"
  [[ -z "${CFG[kernel_params]}" ]] || cmdline+=" ${CFG[kernel_params]}"
  printf '%s\n' "$cmdline"
}

# 1. systemd initramfs with sd-encrypt, the read-only snapshot overlay, and
# the PyreOS boot splash (pyre-base's Plymouth theme, ADR 0015). The theme is
# chosen before the boot stack builds the first initramfs.
write_initramfs_hooks() {
  local conf="$TARGET/etc/mkinitcpio.conf"
  [[ "$(grep -c '^HOOKS=' "$conf")" == 1 ]] || die "expected exactly one HOOKS= line in $conf"
  sed -i "s/^HOOKS=.*/HOOKS=($INITRAMFS_HOOKS)/" "$conf"
  info "initramfs hooks: $INITRAMFS_HOOKS"
  in_target plymouth-set-default-theme pyre
  info "boot splash: PyreOS"
}

# Hibernation (ADR 0017), only when chosen: a swapfile as large as the memory
# in its own @swap subvolume, which keeps it out of every snapshot of @. zram
# stays the everyday swap (priority 100); the file is where the image goes.
# Sets RESUME_OFFSET for the kernel command line.
RESUME_OFFSET=""
setup_hibernation() {
  local file="$TARGET/swap/swapfile"
  [[ "${CFG[hibernation]}" == true ]] || return 0
  [[ "$(findmnt -no SOURCE "$TARGET/swap")" == *"[/@swap]" ]] || die "$TARGET/swap is not the @swap subvolume"
  btrfs filesystem mkswapfile --size "$(swap_mib)m" --uuid clear "$file" >/dev/null
  RESUME_OFFSET="$(btrfs inspect-internal map-swapfile -r "$file")"
  [[ "$RESUME_OFFSET" =~ ^[0-9]+$ ]] || die "could not read the resume offset of $file"
  printf '\n# Hibernation swapfile, written by pyre-install (ADR 0017).\n%s\n' "$(swapfile_fstab)" >>"$TARGET/etc/fstab"
  info "hibernation: /swap/swapfile, $(swap_mib) MiB, resume offset $RESUME_OFFSET"
}

swapfile_fstab() {
  printf '/swap/swapfile  none  swap  defaults,pri=0  0 0\n'
}

# 2. limine-entry-tool settings. The installer writes this file once; it
# belongs to the admin afterwards.
write_limine_defaults() {
  local part uuid cmdline
  part="$(luks_partition)"
  [[ -n "$part" ]] || die "no LUKS partition found on ${CFG[disk]}"
  uuid="$(blkid -s UUID -o value "$part")"
  [[ "$uuid" =~ ^[0-9a-f-]{36}$ ]] || die "could not read the LUKS UUID of $part"
  cmdline="$(kernel_cmdline "$uuid" "$RESUME_OFFSET")"
  cat >"$TARGET/etc/default/limine" <<EOF
# Written by pyre-install; yours to edit. Run limine-update after changes.
# Keep "+=": this file loads last, and "=" would drop the kernel arguments of
# drop-ins in /usr/share/limine-entry-tool.d and /etc/limine-entry-tool.d.
# Options: /etc/limine-entry-tool.conf and /etc/limine-snapper-sync.conf.
ESP_PATH="/boot"
KERNEL_CMDLINE[default]+="$cmdline"
ENABLE_UKI=no
ENABLE_LIMINE_FALLBACK=yes
# The ESP is new and holds only Limine, so there is no other loader to list.
FIND_BOOTLOADERS=no
BOOT_ORDER="*, *lts*, *fallback, Snapshots"
EOF
  info "kernel command line: $cmdline"
}

# 3. snapper configs for the flat layout: snapper create-config insists on
# creating /.snapshots itself, so the @snapshots mount is swapped back in.
setup_snapper() {
  local snapdir="$TARGET/.snapshots" source options
  source="$(findmnt -no SOURCE "$snapdir")"
  options="$(findmnt -no OPTIONS "$snapdir")"
  [[ "$source" == *"[/@snapshots]" ]] || die "$snapdir is not the @snapshots subvolume"
  source="${source%\[*}"

  umount "$snapdir"
  rmdir "$snapdir"
  in_target snapper --no-dbus -c root create-config /
  btrfs -q subvolume delete "$snapdir"
  mkdir -m 750 "$snapdir"
  mount -o "$options" "$source" "$snapdir"
  chmod 750 "$snapdir"
  in_target snapper --no-dbus -c home create-config /home

  in_target snapper --no-dbus -c root set-config \
    TIMELINE_CREATE=no NUMBER_CLEANUP=yes NUMBER_LIMIT=10 NUMBER_LIMIT_IMPORTANT=10
  in_target snapper --no-dbus -c home set-config \
    TIMELINE_CREATE=no NUMBER_CLEANUP=yes NUMBER_LIMIT=5 NUMBER_LIMIT_IMPORTANT=5 \
    ALLOW_GROUPS=wheel SYNC_ACL=yes
  info "snapper configs: root (@snapshots), home"
}

# 4 and 5. Install the boot stack; its pacman hooks build the initramfs, deploy
# Limine to the ESP, and write the entries. snap-pac comes last: pacman runs
# the post hook of a package installed in the same transaction, so
# SNAP_PAC_SKIP keeps the installation itself from creating snapshots.
install_boot_stack() {
  systemd-machine-id-setup --root="$TARGET" >/dev/null
  pacstrap -C /etc/pacman.conf -G -M "$TARGET" --noconfirm --needed "${BOOT_STACK[@]}"
  SNAP_PAC_SKIP=y pacstrap -C /etc/pacman.conf -G -M "$TARGET" --noconfirm --needed snap-pac
  in_target limine-update
  # The timeline stays off (ADR 0008); creating the configs from snapper's
  # default template enables its timer.
  in_target systemctl enable snapper-cleanup.timer
  in_target systemctl disable snapper-timeline.timer
  [[ -f "$TARGET/boot/limine.conf" ]] || die "Limine did not write /boot/limine.conf"
  info "Limine entries: $(grep -c '^ */' "$TARGET/boot/limine.conf") lines"
  # pyre-base's hook ran before limine.conf existed; brand the menu now (ADR 0015).
  in_target /usr/lib/pyre/boot-branding >/dev/null
  info "boot menu: PyreOS look"
}

# Dual-boot (ADR 0008, ADR 0017): Windows on another disk gets a boot menu
# entry that chainloads its boot manager. limine-entry-tool only looks for
# other loaders on its own ESP, so the installer finds Windows itself. The
# other disk is mounted read-only and never written.
readonly ESP_PARTTYPE=c12a7328-f81f-11d2-ba4b-00a0c93ec93b
readonly WINDOWS_LOADER=EFI/Microsoft/Boot/bootmgfw.efi

# other_esps: FAT EFI system partitions on every disk but the install target,
# read from "lsblk -npPo NAME,PKNAME,PARTTYPE,FSTYPE" on stdin.
other_esps() {
  local line re='^NAME="([^"]*)" PKNAME="([^"]*)" PARTTYPE="([^"]*)" FSTYPE="([^"]*)"$'
  while IFS= read -r line; do
    [[ "$line" =~ $re ]] || continue
    [[ "${BASH_REMATCH[2]}" != "${CFG[disk]}" && "${BASH_REMATCH[3],,}" == "$ESP_PARTTYPE" &&
      "${BASH_REMATCH[4]}" == vfat ]] && printf '%s\n' "${BASH_REMATCH[1]}"
  done
  return 0
}

add_windows_entry() {
  local part parts mnt="$TARGET/mnt" found=""
  mapfile -t parts < <(lsblk -npPo NAME,PKNAME,PARTTYPE,FSTYPE | other_esps)
  for part in "${parts[@]}"; do
    mount -o ro "$part" "$mnt" 2>/dev/null || continue
    if [[ -f "$mnt/$WINDOWS_LOADER" ]] &&
      in_target limine-entry-tool --add-efi Windows "/mnt/$WINDOWS_LOADER" \
        --comment "Windows Boot Manager" --priority 20 --overwrite --quiet </dev/null; then
      found="$part"
    fi
    umount "$mnt"
    [[ -z "$found" ]] || break
  done
  if [[ -n "$found" ]] && grep -q '^/Windows$' "$TARGET/boot/limine.conf"; then
    info "dual-boot: Windows on $found is in the boot menu"
  elif [[ -n "$found" ]]; then
    info "dual-boot: Windows on $found could not be added; later: sudo limine-entry-tool --scan"
  else
    info "dual-boot: no Windows found on another disk"
  fi
}

finish_target() {
  in_target passwd -l root >/dev/null
  sync
}

boot_stack() {
  step "Configuring the boot stack (ADR 0011)"
  write_initramfs_hooks
  setup_hibernation
  write_limine_defaults
  setup_snapper
  install_boot_stack
  add_windows_entry
  finish_target
}
