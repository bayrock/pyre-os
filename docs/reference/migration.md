# Migrating the development machine (P6)

The plan for moving the development machine (`dev-machine.md`) to PyreOS. Every command here is run by the machine's owner: it touches the host's disks and firmware, which agents never do (`AGENTS.md`, "Host safety"). `/dev/sda`, `/dev/nvme0n1` and `/dev/sdX` are this machine's names on 2026-11-14; check them with `lsblk` before each step.

## What is already proven, and what is not

- **In VMs** (`tools/test-machine`, `tools/test-nvidia`, `tools/test-e2e`): the interactive installer onto a disk that holds an older MBR and LUKS system, hibernation's swapfile and a resume into the same session, the Windows boot entry and its chainload, three outputs with one portrait, suspend with the lock, autologin without a keyring dialog, the NVIDIA driver build inside the installer, snapshots and rollback.
- **On this machine, read-only:** `pyre hw detect` matches the RTX 3060 Ti with the `nvidia-open` rule.
- **Only the real install can show:** the NVIDIA driver under niri, 240 Hz and VRR, suspend and hibernate with real firmware, Bluetooth, the USB audio, and the peripherals.

## The one thing that differs from today: UEFI

The current system boots in **legacy BIOS mode** from an MBR disk; Windows on the NVMe is a UEFI install. PyreOS installs on UEFI only (ADR 0011), so:

- Boot the PyreOS USB from the firmware's boot menu entry that starts with **"UEFI:"**. `pyre-install` refuses to run when the machine booted in BIOS mode, before it asks anything.
- The install adds a "Limine" entry to the firmware's boot order and puts it first. The "Windows Boot Manager" entry stays, and Limine's menu gains a "Windows" entry.
- CSM can stay enabled. Turning it off is optional and can wait until PyreOS has booted.

## 1. The safety net

Both backups fit on the Windows data partition (358 GiB free; the home directory is 63 GiB without caches, the Linux disk 112 GiB). An external disk works the same way.

1. **Home backup, from the running system.** One archive keeps owners, modes and links, which NTFS itself would not:

   ```sh
   dest=/run/media/$USER/<the Windows volume>/pyre-migration && mkdir -p "$dest"
   tar --zstd -cpf "$dest/home.tar.zst" --exclude="$USER/.cache" -C /home "$USER"
   zstd -t "$dest/home.tar.zst" && tar -tf "$dest/home.tar.zst" | wc -l
   pacman -Qqe > "$dest/packages.txt"
   ```

   Check by hand that what cannot be recreated is inside: SSH and GPG keys, the password database, browser profiles, and any repository with unpushed work.
2. **A whole-disk image of the Linux disk, from the PyreOS USB** (step 2), before installing. It is the way back to the current system, byte for byte:

   ```sh
   mount -t ntfs3 /dev/nvme0n1p4 /mnt && cd /mnt/pyre-migration
   dd if=/dev/sda bs=4M status=progress | tee >(sha256sum > sda.sha256) | zstd -T0 -1 > sda.img.zst
   zstdcat sda.img.zst | sha256sum     # must print the hash in sda.sha256
   cd / && umount /mnt
   ```

   To go back: `zstdcat sda.img.zst | dd of=/dev/sda bs=4M status=progress`, then boot in BIOS mode as today.
3. **A second USB stick with the current system's own installer** is a spare way to boot if the PyreOS USB will not. Optional once the image exists.

If Windows was hibernated or "fast startup" is on, the NTFS volume mounts read-only. Shut Windows down fully (`shutdown /s /t 0`) first.

## 2. The PyreOS USB

The ISO of 2026-11-14 (`build/out/pyreos-2026.11.14-x86_64.iso`) is built, verified and tested (STATUS). Check it once more right before writing it, then write it:

```sh
tools/verify-iso                                  # the image is still what was built
sudo dd if=build/out/pyreos-2026.11.14-x86_64.iso of=/dev/sdX bs=4M oflag=sync status=progress
sudo cmp -n "$(stat -c %s build/out/pyreos-2026.11.14-x86_64.iso)" build/out/pyreos-2026.11.14-x86_64.iso /dev/sdX   # the stick holds it, byte for byte
```

After a package change, rebuild first (`tools/build-pkgs && sudo tools/build-iso`) and run `tools/test-iso`, `test-e2e`, `test-machine` and `test-nvidia` again.

`/dev/sdX` is the USB stick: check it with `lsblk -o NAME,SIZE,TRAN,MODEL` (`TRAN` is `usb`).

## 3. Install

1. Boot the stick through its "UEFI:" entry. Take the disk image (step 1.2).
2. Run `pyre-install`. The disk list shows what each disk holds:
   - **the 120 GB Samsung SSD** ("holds vfat crypto_LUKS") is the target;
   - **the 1 TB NVMe** ("holds ntfs vfat") is Windows. Do not choose it.
3. Answer yes to autologin and to hibernation (a 16 GiB swapfile). The confirmation names the disk again before anything is erased.
4. The install log ends with "dual-boot: Windows on /dev/nvme0n1p2 is in the boot menu". Reboot without the stick.

## 4. First boot on real hardware

Clone the repository, then run `tools/hw-report` and keep its output: it collects what P6 needs to judge (the driver, the outputs and their modes, sleep states, audio, Bluetooth, failed units).

Then, by hand:

- **Outputs.** `niri msg outputs` gives the real names. The overlay's layout (portrait left, main at 240 Hz with VRR, the TV above) goes in `~/.config/niri/`.
- **Sleep.** `systemctl suspend`, wake, unlock. Then `systemctl hibernate`, power on, unlock the disk: the session is back.
- **Windows.** Pick "Windows" in the boot menu. Windows keeps the clock in local time and Linux in UTC; set Windows to UTC (`RealTimeIsUniversal`) rather than changing Linux.
- **Restore.** Unpack what is needed from `home.tar.zst`; do not restore old dotfiles over the PyreOS stubs wholesale.

## 5. If it goes wrong

- **PyreOS boots but something is broken:** boot the previous snapshot from the Limine menu, then `pyre rollback`.
- **PyreOS does not boot:** the firmware's boot menu still starts Windows directly.
- **Back to the current system:** restore the disk image (step 1.2).

The exit criterion is a week of daily use with the issues logged (ROADMAP P6).
