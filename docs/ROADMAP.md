# Roadmap

Phases run in order. A phase is accepted only when its exit criteria pass with evidence recorded in `STATUS.md`. On 2026-11-07 this roadmap replaced the earlier milestones 0–7. The old milestone 0 discovery work is preserved in `docs/reference/`.

## P0: Reset (accepted 2026-11-07)

- Rename the project to PyreOS, rewrite the project docs, and record ADRs 0004–0009.
- Install the approved host dev tools.
- Retire the VirtualBox build VM in favour of local QEMU/KVM.
- Add `tools/run-vm`.
- **Exit when:** the docs are coherent, `shellcheck` passes on `tools/`, and `tools/run-vm` boots the stock Arch ISO to a live shell, with the evidence captured.

## P1: Build pipeline (accepted 2026-11-08)

- Create package skeletons: `pyre-keyring` (development key), `pyre-release` (with an `os-release` ADR), and the `pyre-base` meta-package.
- Add `tools/build-pkgs`, which builds into a local repo.
- Re-derive `iso/` from archiso `releng`, consume the local repo, and add a serial console.
- Set up CI: shellcheck, bats, namcap, and a package build.
- **Exit when:** the ISO builds from a clean checkout, boots under QEMU on both UEFI and BIOS, and shows PyreOS identity in `os-release`.

## P2: Installer and base system (accepted 2026-11-08)

- Build `pyre-install`: a gum TUI plus an archinstall config generator, with unattended `--config` support.
- Implement the storage and boot defaults: LUKS2 + btrfs, Limine, snapper root and home, snap-pac, limine-snapper-sync, and the sd-encrypt initramfs.
- Write a firewall ADR.
- Add `tools/test-e2e`.
- **Exit when:** an automated VM scenario passes this sequence: unattended install, reboot, LUKS unlock, login, `pacman -Syu` that creates a snapshot pair, boot into the snapshot from Limine, then rollback.

## P3: Desktop core (accepted 2026-11-10)

- Wire up the desktop stack: niri, Noctalia, noctalia-greeter, portals, polkit, PipeWire, NetworkManager, bluez, xwayland-satellite, and power profiles.
- Ship the default apps and the keymap (`docs/KEYBINDINGS.md`).
- Layer configs by include, and check every include mechanism actually works.
- **Exit when:** the daily-interaction checklist passes in the VM, backed by screendump evidence. The checklist covers login, launcher, notifications, lock/idle, screenshot, recording, screen-share portal, clipboard, multi-output, and audio/network/Bluetooth controls.

## P4: Lifecycle (accepted 2026-11-13)

- Build the `pyre` CLI: `update`, `snapshot`, `rollback`, `doctor`, and `install`/`remove <bundle>`.
- Build the reconcile engine with system and user scopes, plus home snapshots.
- Add `pyre hw` with the NVIDIA, AMD, and Intel rules.
- Publish a testing channel on GitHub Releases.
- **Exit when:**
  - an N-1 → N upgrade test passes in a VM
  - every reconcile unit's test shows that a second run is a no-op
  - a deliberately broken update can be rolled back to a working desktop

## P5: Polish and identity (in review)

- Build the theme system on Noctalia's palettes and templates (ADR 0015), with `pyre theme`.
- Ship the "Ember" default theme plus curated alternatives.
- Brand Limine, Plymouth, the greeter, and wallpapers.
- Add a welcome/onboarding flow and user documentation.
- **Exit when:** switching themes updates every covered app live, and a full visual review passes from boot splash to lock screen.

## P6: Daily driver on the development machine

- Cover the hardware and setup on the development machine:
  - an NVIDIA RTX 3060 Ti
  - three outputs, one of them portrait, with 240 Hz VRR on the main display
  - suspend and hibernate
  - peripherals
  - Windows dual-boot through Limine
- Build the author's personal overlay repo. It covers keybind extras, monitor layout, fonts, and personal toys such as the visualizer and the Quickshell dancer.
- Migrate the development machine: a verified home backup, a recovery USB for the current system, then install.
- **Exit when:** a week of daily use passes, with issues logged and the critical ones fixed.

## P7: Public readiness

- Check the name, trademark, and domain.
- Move the repository to object storage behind a CDN.
- Publish a website and docs.
- Add CONTRIBUTING, a Code of Conduct, a governance doc, a release process, and a security contact.
- **Exit when:** PyreOS 1.0 "Ember" is released, with signed ISO checksums and published upgrade notes.
