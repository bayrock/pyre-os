# ADR 0017: Hibernation and dual-boot in the installer

- Status: Accepted
- Date: 2026-11-14
- Fills in: ADR 0008 ("a btrfs swapfile with the correct `resume_offset`", "a Limine chainload entry")

## Context

ADR 0008 promised two installer features that P2 left for later, and P6 needs both: the development machine hibernates, and it keeps Windows on a second disk.

Read or measured on 2026-11-14:

- **Swapfiles and snapshots.** btrfs cannot snapshot a subvolume that holds an active swapfile, so a swapfile inside `@` would break every snap-pac snapshot.
- **Resume in a systemd initramfs.** mkinitcpio's `systemd` hook already ships `systemd-hibernate-resume` and its generator (mkinitcpio 42). They read `resume=` and `resume_offset=`; no extra hook is needed, and `sd-encrypt` unlocks the volume first.
- **zram.** systemd picks the hibernation target from `/sys/power/resume`, so the image goes to the swapfile even though zram has the higher swap priority.
- **Other loaders.** `limine-entry-tool` 1.40.0 has `FIND_BOOTLOADERS`, but `limine-install` only looks on its own ESP (systemd-boot, rEFInd, and `EFI/BOOT/BOOTX64.EFI`). Windows on another disk is not found. With `ENABLE_LIMINE_FALLBACK=yes`, the one loader it does find on a new ESP is Limine's own fallback copy, which gave the menu a pointless "EFI fallback" entry.
- **Chainloading.** `limine-entry-tool --add-efi NAME FILE` writes a top-level entry with `protocol: efi` and `path: uuid(<partition UUID>):/…` when FILE is on another mounted FAT partition. Its interactive `--scan` does the same from the firmware's boot entries and uses priority 20. Entries are ordered by descending priority, PyreOS has 50, and `default_entry` counts from the top, so an entry above PyreOS would change what boots by default.
- **NVIDIA.** With `nvidia-open` 595 and later the kernel's suspend notifiers preserve video memory. `nvidia-utils` 615 disables its old `nvidia-suspend`, `-hibernate` and `-resume` services on upgrade, and ships `NVreg_TemporaryFilePath=/var/tmp`. The hardware rule needs nothing for sleep.

## Decision

**Hibernation is an installer option, off by default** (`hibernation = true`, and a question in the TUI).

- archinstall creates one more subvolume, `@swap`, mounted at `/swap`. It is outside `@`, so snapshots and rollbacks never see the swapfile.
- `pyre-install` creates `/swap/swapfile` with `btrfs filesystem mkswapfile`, as large as the machine's memory, and adds it to `fstab` with priority 0. zram stays the everyday swap at priority 100.
- The kernel command line gains `resume=/dev/mapper/root resume_offset=<offset>`, with the offset from `btrfs inspect-internal map-swapfile -r`.
- The disk needs 16 GiB plus the swapfile; the installer refuses a smaller one before touching it.
- Without the option nothing changes: no subvolume, no swapfile, no resume arguments.

**A Windows disk gets a boot menu entry, always.**

- After the boot stack is installed, `pyre-install` looks at every FAT EFI system partition on the other disks, mounted read-only, for `EFI/Microsoft/Boot/bootmgfw.efi`.
- For the first one found it runs `limine-entry-tool --add-efi Windows … --priority 20`, which puts "Windows" below PyreOS. PyreOS stays the default, and the firmware's own Windows entry stays where it was.
- The other disk is never written. If the entry cannot be added, the install still succeeds and says so; `sudo limine-entry-tool --scan` adds it later.
- `/etc/default/limine` sets `FIND_BOOTLOADERS=no`: the ESP is new and holds only Limine.

**The disk question shows what each disk holds** ("empty", or its filesystems), and the erase confirmation repeats it, so that a machine with two disks is not a guess.

## Consequences

- Hibernation on real hardware still depends on firmware and drivers; the VM proves the installer's part (the swapfile, the offset, and a resume into the same session).
- The swapfile takes as much disk as the machine has memory. On the 120 GB development machine that is 16 GiB.
- A resume offset is only valid for the file it was read from. Recreating the swapfile needs a new offset in `/etc/default/limine` and `limine-update`.
- Windows on the *same* disk is still out of scope: installs erase a whole disk (ADR 0008).
- Other operating systems are not detected. `limine-entry-tool --scan` lists the firmware's entries for anyone who needs one.
- VM tests need QEMU's TCO watchdog strapped to not reboot (`tools/run-vm`): a kernel that boots only to resume never loads the watchdog driver, and the resumed guest was reset seconds later. Real firmware arms no such timer.
