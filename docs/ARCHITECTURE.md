# Architecture

This document is the target design. A section is "implemented" only once `STATUS.md` records evidence for it. Rationale for each major choice lives in `docs/decisions/`.

## Layers

```text
┌───────────────────────────────────────────────────────────────┐
│ User overlay (optional, user-owned repo: dotfiles, toys)      │  ~/.config, ~/.config/pyre/
├───────────────────────────────────────────────────────────────┤
│ User stubs: tiny files that include the defaults              │  seeded from /etc/skel once
├───────────────────────────────────────────────────────────────┤
│ PyreOS defaults, themes, templates, CLI, hardware rules       │  /usr/share/pyre, /usr/lib/pyre
│ System drop-ins (sysctl, systemd, mkinitcpio, pacman hooks)   │  /usr/lib/*.d, package-owned
├───────────────────────────────────────────────────────────────┤
│ Upstream: Arch packages, niri, noctalia, pipewire, snapper…   │  [core] [extra] [multilib]
└───────────────────────────────────────────────────────────────┘
```

Each layer only adds to the layer below it. No layer overwrites another layer's files.

## Core contracts

### 1. Plain pacman is always safe

- **Pre/post snapshots on every transaction.** `snap-pac` takes a snapper pre/post pair, and `limine-snapper-sync` makes the snapshots bootable from the Limine menu.
- **System reconcile from a hook.** A `[pyre]` pacman hook runs `pyre reconcile --system` after transactions that touch PyreOS packages.
- **`pyre update` is a convenience wrapper, never a requirement.** In order, it:
  1. checks free space and takes a lock
  2. refreshes `pyre-keyring` and `archlinux-keyring` first
  3. runs `pacman -Syu`
  4. optionally runs AUR updates
  5. takes a home snapshot, then runs `pyre reconcile --user`
  6. runs `pyre doctor --boot` to verify that kernels, initramfs, and boot entries match
  7. reports whether a reboot is needed
- **No guard.** There is never an ALPM hook that blocks direct pacman use.

### 2. File ownership

| What | Where | Mechanism |
|---|---|---|
| Distribution defaults | `/usr/share/pyre/defaults/<app>/` | Package-owned; never copied to `$HOME` |
| System tweaks | `/usr/lib/sysctl.d`, `/usr/lib/systemd/*.conf.d`, `/usr/lib/udev/rules.d`, `/etc/mkinitcpio.conf.d`, `/etc/limine-entry-tool.d`, `/usr/share/libalpm/hooks` | Package-owned drop-ins |
| Admin-editable config | `/etc/...` | pacman `backup=()`, so edits survive as `.pacnew` |
| User stubs | `/etc/skel` → `~/.config/<app>/` | Seeded once at user creation. They include the defaults and are never rewritten. |
| Generated state | `~/.local/state/pyre/` (current theme, reconcile versions) | Written atomically by the `pyre` CLI |
| System state | `/var/lib/pyre/` | Reconcile schema versions, hardware results |

When a user stub truly must change, reconcile writes `<file>.pyre-new` beside it and shows a notification with a diff command. It never edits the user's file.

`os-release` follows ADR 0010:

- `pyre-release` ships `/usr/lib/pyre/os-release`.
- An ALPM hook points `/etc/os-release` at that file, but only when `/etc/os-release` is missing or still Arch's default symlink.
- No Arch package is replaced, and no admin file is touched.

### 3. Reconcile, not migrations

Some Arch-based desktops ship hundreds of one-way migration scripts that every user runs. PyreOS uses reconcile units instead.

- **A unit is a small idempotent bash function pair.** `check` returns whether the system already matches the desired state; `apply` converges it. Examples: ensure greetd is enabled, ensure the user is in a group, ensure a stub exists.
- **Two scopes, run separately:**
  - **System** units run as root from the pacman hook, once per machine.
  - **User** units run at login from a systemd user unit, with no sudo.
- **Each scope records a schema version** in `/var/lib/pyre/reconcile` or `~/.local/state/pyre/reconcile`. A unit declares the version it was introduced in. A fresh install starts at the current version and skips history.
- **Imperative one-offs are a last resort,** for example renaming a subvolume. They live in the same framework, must be idempotent, and need a test.
- **Every unit has a bats test** that runs it twice and asserts that the second run is a no-op.

### 4. Rollback includes user state

- Snapper runs a `root` config (pre/post via snap-pac) and a `home` config (snapshot before `pyre update` and before user reconcile).
- Retention is tight, roughly 5–10 snapshots each.
- Caches are excluded through nested subvolumes such as `~/.cache`.
- `pyre rollback` lists snapshots across both configs and explains what restoring each one would revert.

### 5. Config layering by include

| App | Mechanism |
|---|---|
| niri | User `config.kdl` `include`s `/usr/share/pyre/defaults/niri/*.kdl` and the generated theme colors (niri ≥ 25.11) |
| Noctalia | Upstream config load order and GUI overrides; PyreOS ships the base config, the user layer stays untouched |
| foot | `include=` of defaults and the generated theme |
| bash | `~/.bashrc` sources `/usr/share/pyre/defaults/bash/rc`; the installer replaces bash's untouched skel copy (ADR 0013) |
| GTK/Qt | Generated theme files in `~/.local/state/pyre/theme/` referenced by stubs |

Each include mechanism is verified for real in P3 before it is relied on.

## Components

### ISO (`iso/`)

- Derived from archiso's `releng` profile. The origin and the delta are recorded in `iso/UPSTREAM.md`.
- Adds a serial console on the kernel command line, the `pyre-installer` package, and an offline local repo holding the full default package set.
- The ISO boots on UEFI and BIOS. Installed systems are UEFI only (ADR 0011).

### Installer (`src/installer/`, package `pyre-installer`)

`pyre-install` is a thin gum TUI.

**It asks for:** target disk, LUKS passphrase, user and password, hostname, timezone and locale (autodetected and confirmable), optional bundles, autologin, and hibernation.

**It generates an archinstall JSON config** and runs archinstall with `--skip-boot`. Arch-maintained code does the disk, LUKS2, btrfs, subvolume, and base-system work.

**It then owns the boot stack** in the chroot (ADR 0011):

1. the systemd initramfs `HOOKS`
2. `/etc/default/limine` and the `rd.luks` command line
3. the snapper configs
4. installing `limine-mkinitcpio-hook`, `limine-snapper-sync` and `snap-pac`
5. `limine-install` and `limine-update`

**It finishes in the chroot** by running `pyre hw apply` and `pyre reconcile --system`. It then reboots into the greeter.

**Unattended mode** (`pyre-install --config file.toml`) drives the e2e tests.

### Storage and boot defaults

- GPT. A 2 GiB FAT32 ESP is mounted at `/boot`.
- LUKS2 holds btrfs with subvolumes `@`, `@home`, `@log`, `@pkg`, `@snapshots`, plus nested cache subvolumes. Mount options are `compress=zstd:3,noatime`.
- Swap is zram. A swapfile is created only when hibernation is chosen.
- The initramfs uses systemd hooks with `sd-encrypt`, which makes TPM2/FIDO2 unlock possible later. Plymouth is themed.
- Limine is the bootloader. `limine-entry-tool` (`limine-mkinitcpio-hook`) generates the boot entries, and `limine-snapper-sync` adds the snapshot entries. Read-only snapshots boot with `sd-btrfs-overlayfs`. There is no UKI for now (ADR 0011).
- Kernels are `linux` plus `linux-lts` as a fallback entry.
- Dual-boot: an existing Windows ESP on another disk is detected and gets a Limine chainload entry.

### Session

| Function | Component |
|---|---|
| Login | greetd with `noctalia-greeter`; optional autologin (`initial_session`). `pyre-install` writes `/etc/greetd/config.toml` once (ADR 0013) |
| Compositor | niri as a systemd user session (`niri.service`); UWSM is not needed |
| Shell | Noctalia v5: bar, launcher, notifications, OSD, lock, idle, settings, wallpaper |
| Portals | `xdg-desktop-portal-gnome` and `-gtk` |
| X11 apps | `xwayland-satellite` (niri integrates it automatically) |
| Audio | PipeWire and WirePlumber |
| Network | NetworkManager with systemd-resolved |
| Bluetooth | bluez |
| Power | power-profiles-daemon |
| Polkit agent, idle/lock | Noctalia (`polkit_agent = true`; lock at 10 min, screens off at 11; ADR 0013) |
| Firewall | firewalld, stock `public` zone (ADR 0012) |

### Default applications

The default set is lean. Everything else is an optional bundle.

| Role | Default |
|---|---|
| Terminal | foot |
| Browser | Firefox |
| File manager | Nautilus |
| Editor | neovim with a minimal config; LazyVim is offered as a bundle |
| Screenshots | niri's built-in screenshot UI |
| Recording | gpu-screen-recorder, toggled by `pyre-record` (portal capture) |
| Media | mpv, imv, Papers |
| CLI tools | btop, fastfetch, fzf, ripgrep, bat, eza, zoxide, starship |

Bundles are meta-packages: `pyre-bundle-dev`, `-media` and `-office`. `pyre install <bundle>` adds one, and `pyre remove <bundle>` takes it away with the apps nothing else needs. Two bundles are still to come:

- **`-gaming`** needs `[multilib]` enabled in `pacman.conf`, which is the admin's file.
- **`-lazyvim`** needs a per-user LazyVim checkout, which is not a package payload.

The installer will offer bundles once the TUI is exercised.

### Theme system (`themes/`, `templates/`, package `pyre-themes`)

- **A theme** is a directory containing:
  - `palette.toml`: semantic roles such as background and surface steps, foreground steps, accent, selection, the 16 ANSI colors, and `mode=dark|light`
  - `wallpapers/`
  - optional per-app overrides, which are data only and never code
- **Applying a theme.** `pyre theme set <name>` renders `templates/*` with matugen, which is in `extra`, into a staging directory. It then swaps the directory into place at `~/.local/state/pyre/theme/` and signals running apps: niri reloads, foot reloads its colors, and Noctalia's palette is updated.
- **Coverage:** niri, Noctalia, foot, GTK 3/4, Qt (qt6ct), btop, neovim, fcitx5, and the Limine, Plymouth, and greeter palettes where feasible.
- **Shipped themes:** "Ember" is the default, plus a small curated set built from palettes whose licenses have been checked. No third-party theme artwork is copied.

### CLI (`src/cli/`, package `pyre-cli`)

- **One entrypoint,** `pyre <command>` (ADR 0014). Commands are files in `/usr/lib/pyre/commands/` with `# help:` and `# usage:` header metadata. The shared library is in `/usr/lib/pyre/lib/`, and the reconcile units are in `/usr/lib/pyre/reconcile/{system,user}/`.
- **Commands:** `update`, `snapshot`, `rollback`, `doctor`, `reconcile`, `hw`, `install`/`remove <bundle>`, `help`. `theme` comes in P5.
- **Triggers:** an ALPM hook (`pyre-reconcile.hook`) runs system reconcile after `pyre-*` packages change, and `pyre-reconcile.service` (a user unit enabled globally) runs user reconcile at login.
- **Budget:** under 5,000 lines total for the CLI plus the installer before 1.0. Every command needs a test, and anything over budget needs a reason in its ADR.

### Hardware rules (`src/hw/`, shipped in `pyre-cli`)

- **Rules are data.** Each rule file in `/usr/share/pyre/hw/rules/` matches a PCI vendor, class and device range, or a CPU vendor. It maps them to packages, initramfs modules (`/etc/mkinitcpio.conf.d/50-pyre-hw.conf`), kernel arguments (`/etc/limine-entry-tool.d/50-pyre-hw.conf`) and drop-in files. `pyre hw apply` evaluates the rules at install time and on demand. A second run changes nothing, and the drop-ins of hardware that is gone are removed.
- **Detection reads sysfs only.** It never calls `lspci`, which wakes runtime-suspended dGPUs.
- **NVIDIA is first-class.**
  - `nvidia-open-dkms` is used when the GPU supports GSP; otherwise the legacy branch.
  - Early KMS and `nvidia_drm.modeset=1`.
  - The niri-recommended `GLVidHeapReuseRatio=0` application profile.
  - The `libva-nvidia-driver` environment.
- **Microcode:** archinstall installs both `amd-ucode` and `intel-ucode`, and the `microcode` initramfs hook loads the right one, so no CPU rule is needed yet.
- **AMD and Intel GPUs:** Vulkan (`vulkan-radeon`, `vulkan-intel`) and Intel's VA-API media driver.
- **Pre-Turing NVIDIA GPUs:** a note only. nouveau runs, because the legacy proprietary branch is AUR-only.

### Package repository (`packages/`, ADR 0009)

- Each package is a standard PKGBUILD in `packages/<name>/`.
- CI builds them in clean chroots and signs them with a CI-held subkey of the PyreOS key. `pyre-keyring` ships from day one.
- Hosting starts on GitHub Releases (the `testing` release, filled by `tools/publish-testing`) and moves to object storage plus a CDN before public release.
- There are two channels, `testing` and `stable`, and promotion is scripted.
- `[pyre]` is listed after `[core]`, `[extra]`, and `[multilib]`.
- Every release runs an N-1 → N upgrade test in a VM.

## Repository layout

Directories are created when their phase needs them.

```text
packages/<name>/PKGBUILD   pyre-keyring, pyre-release, pyre-base, pyre-desktop (with the defaults),
                           pyre-cli, pyre-themes, pyre-installer, pyre-hw, pyre-bundle-*,
                           limine-snapper-sync, limine-mkinitcpio-hook (vendored from AUR)
src/cli/                   pyre entrypoint, lib, commands
src/installer/             pyre-install TUI and archinstall config generator
defaults/                  → /usr/share/pyre/defaults
skel/                      → /etc/skel (user stubs that include the defaults)
src/desktop/               small desktop helpers (pyre-record)
system/                    → package-owned drop-ins
themes/  templates/        theme data and matugen templates
iso/                       archiso profile (releng-derived)
tests/                     bats unit tests, VM e2e scenarios
tools/                     build-pkgs, build-iso, run-vm, test-e2e, publish-repo
docs/                      brief, architecture, roadmap, status, handoff, decisions/, reference/
landing/                   the website: site/ is published to GitHub Pages as-is
```

Generated ISOs, packages, VM disks, keys, and secrets go only under the ignored `build/`.

## Development loop

1. `tools/build-pkgs` builds packages into the local repo `build/repo/`.
2. `sudo tools/build-iso` runs `mkarchiso` on `iso/` with the local repo injected and writes to `build/out/`.
3. `tools/run-vm <iso>` boots it with QEMU/KVM and UEFI (OVMF), or BIOS with `--bios`. It uses disposable qcow2 disks under `build/vm/`, a serial log, and a monitor socket for screendumps.
4. `tools/test-iso` boot-checks an ISO under UEFI and BIOS, covering the serial login, identity, and keyring.
5. `tools/test-e2e <scenario>` runs an unattended install, then boot, then assertions over the serial console and screenshots. *(P2)*

CI runs the same scripts.
