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
| Agent skill | `/usr/share/pyre/skills/<name>/` | Package-owned; linked into `~/.claude/skills/` and `~/.agents/skills/` by user reconcile (ADR 0019) |
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

**It asks for:** the target disk (the list shows what each disk holds now), hostname, user and password, the LUKS passphrase, timezone, locale and keyboard layout, autologin, and hibernation. Optional bundles are still to come.

**It generates an archinstall JSON config** and runs archinstall with `--skip-boot`. Arch-maintained code does the disk, LUKS2, btrfs, subvolume, and base-system work.

**It then owns the boot stack** in the chroot (ADR 0011):

1. the systemd initramfs `HOOKS`
2. the hibernation swapfile, when chosen (ADR 0017)
3. `/etc/default/limine` and the `rd.luks` command line
4. the snapper configs
5. installing `limine-mkinitcpio-hook`, `limine-snapper-sync` and `snap-pac`
6. `limine-install` and `limine-update`
7. a "Windows" boot entry when another disk holds Windows (ADR 0017)

**It finishes in the chroot** by running `pyre hw apply` and `pyre reconcile --system`. It then reboots into the greeter.

**Unattended mode** (`pyre-install --config file.toml`) drives the e2e tests.

### Storage and boot defaults

- GPT. A 2 GiB FAT32 ESP is mounted at `/boot`.
- LUKS2 holds btrfs with subvolumes `@`, `@home`, `@log`, `@pkg`, `@snapshots`, plus nested cache subvolumes. Mount options are `compress=zstd:3,noatime`.
- Swap is zram. Only when hibernation is chosen (ADR 0017), a swapfile as large as the memory lives in its own `@swap` subvolume, outside every snapshot, and the kernel command line carries `resume=` and `resume_offset=`. `pyre doctor` checks that the offset is still the swapfile's.
- The initramfs uses systemd hooks with `sd-encrypt`, which makes TPM2/FIDO2 unlock possible later. Plymouth is themed.
- Limine is the bootloader. `limine-entry-tool` (`limine-mkinitcpio-hook`) generates the boot entries, and `limine-snapper-sync` adds the snapshot entries. Read-only snapshots boot with `sd-btrfs-overlayfs`. There is no UKI for now (ADR 0011).
- Kernels are `linux` plus `linux-lts` as a fallback entry.
- Dual-boot (ADR 0017): Windows on another disk gets a "Windows" entry below PyreOS that chainloads its boot manager. The other disk is only read.

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
| Night light | Noctalia's gamma service on niri's `wlr-gamma-control`; no separate gamma daemon. Off by default. `Mod+Ctrl+N` holds it on, and PyreOS's defaults give its schedule fixed hours (20:00 to 07:00), so it needs no location lookup |
| Firewall | firewalld, stock `public` zone (ADR 0012) |

### Default applications

The default set is lean (ADR 0021). Everything else is an optional install: an app from the PyreOS menu's catalog, or a bundle.

| Role | Default |
|---|---|
| Terminal | foot |
| Browser | Firefox |
| File manager | Nautilus |
| Editor | neovim with a minimal config; LazyVim is offered as a bundle |
| Screenshots | niri's built-in screenshot UI |
| Recording | `pyre-record` toggles gpu-screen-recorder (portal capture), an optional install; without it, the key says where to find it |
| Media | none by default: mpv, imv and Papers are in the catalog |
| CLI tools | btop, fastfetch, fzf, eza, zoxide, starship; bat and ripgrep are in the catalog |

Bundles are meta-packages: `pyre-bundle-dev`, `-media` and `-office`. `pyre install <bundle>` adds one, and `pyre remove <bundle>` takes it away with the apps nothing else needs. Two bundles are still to come:

- **`-gaming`** needs `[multilib]` enabled in `pacman.conf`, which is the admin's file.
- **`-lazyvim`** needs a per-user LazyVim checkout, which is not a package payload.

The installer will offer bundles once the TUI is exercised.

### Theme system (`themes/`, package `pyre-themes`, ADR 0015)

- **A theme is a Noctalia palette.** Each one is a directory, `themes/<id>/`, installed to `/usr/share/pyre/themes/<id>/`:
  - `theme.toml` holds `name`, `description` and `mode`
  - `palette.json` is in Noctalia's palette format 2: 16 Material roles plus terminal and ANSI colors, generated by `tools/theme-palettes`
  - `wallpapers/`, which `theme.toml` names (`wallpaper = "wallpapers/…"`, and `banner`, a wide crop for panels), generated by `tools/render-wallpaper`
  - data only, never code. `tools/check-themes` checks the schema and WCAG contrast.
- **Applying a theme.**
  1. The user reconcile unit `002-theme-palettes` links each palette into `~/.config/noctalia/palettes/`.
  2. Noctalia's defaults select Ember, and Noctalia renders the palette into the apps through its built-in templates, live, on every change.
  3. `pyre theme set <name>` switches through `noctalia msg color-scheme-set custom <name>`, and sets the theme's wallpaper.
  4. On every palette change, Noctalia's `pyre-live` user template runs `pyre theme refresh`, which recolors open foot terminals (OSC sequences) and open GTK windows (a color-scheme nudge).
- **Coverage:** Noctalia, niri, foot, GTK 3/4 (with `adw-gtk-theme`) and btop. Qt follows when a default app uses it. The login screen starts on Ember (system reconcile `002-greeter-appearance`), and Noctalia's greeter sync replaces it with a user's own look.
- **Boot surfaces wear Ember for every user** (ADR 0015). `pyre-base` keeps a marked PyreOS block at the top of `/boot/limine.conf`, with the branding, Ember's colors and the wallpaper copied to `/boot/pyre/`. Its pacman hook applies it, and so does `pyre-install`.
- **Shipped themes:** all original, one cabin at four hours and seasons: Ember (the default, dark), Birch (light; Ember's day), Evergreen (dark, green) and Frost (dark, blue). Ember and Birch are each other's other variant, so Noctalia's dark/light switch moves between them. Noctalia's own built-in palettes stay available in its settings; no third-party theme artwork is copied.

### Welcome panel (`src/desktop/welcome/`, package `pyre-desktop`, ADR 0016)

- A Noctalia plugin, `pyre/welcome`, installed read-only in `/usr/share/pyre/noctalia/plugins/` and enabled by PyreOS's Noctalia defaults through a `path` plugin source.
- "Welcome home.": the theme buttons (`pyre theme set`), the main keys, updates, `pyre doctor`, the shell settings, and the user guide (`docs/guide/`, installed to `/usr/share/doc/pyre/guide/`) rendered in place. Every color is a palette role, so it recolors with the theme.
- `pyre welcome` opens it. niri runs `pyre welcome --first-login` at login, which opens it once (or at every login, `--at-login on`); the launcher lists it as "Welcome to PyreOS".

### Keymap, key list and the PyreOS menu (ADR 0021)

- **The keymap** (`defaults/niri/binds.kdl`) follows macOS and the Hyprland-based Arch desktops wherever niri has the same action; niri-only actions sit on the keys those leave free. Every bind is one line with a `hotkey-overlay-title`, which is its description everywhere.
- **`pyre keys`** lists the keys from that file and the user's `config.kdl`. `tools/keys-doc` writes the "Every key" section of `docs/KEYBINDINGS.md` from the same parser, and a bats test fails when they differ.
- **`pyre menu`** is the PyreOS menu: update, install and remove (the catalog `src/cli/menu/catalog.tsv`, the bundles, a repository search), themes, style, setup, learn, system. The rows come from `src/cli/menu/menu.tsv`, installed to `/usr/share/pyre/menu/`. The data names one of a fixed set of actions per row and never holds a command; installs run in a floating terminal.
- **In the launcher,** two dmenu providers in `defaults/noctalia/pyre.toml` show them: `/pyre` (also part of the ordinary search) and `/keys`. `Mod+Alt+Space` and `Mod+K` open the launcher on them.
- `tools/check-catalog` checks, against a sync database, that every catalog package is in `core` or `extra`.

### Remind me (`src/cli/commands/remind`, `src/desktop/remind/`, ADR 0020)

- `pyre remind <when> [message]` sets a reminder: `10m tea`, `5pm call mum`, `tomorrow 9am standup`, or the time last, `call mum in 2 hours`. `pyre remind list` and `pyre remind cancel` manage them.
- A reminder is a file in `~/.local/state/pyre/reminders/` and a transient systemd user timer on the wall clock. It fires as a notification that stays until dismissed. `pyre-remind.service` sets the timers again when the desktop starts, and shows what came due meanwhile.
- In the launcher, the Noctalia plugin `pyre/remind` answers `/remind 10m tea` and plain `remind me to call mum at 5pm`. It shows the time `pyre remind` read before Enter sets it; `/remind` alone lists the pending reminders.

### CLI (`src/cli/`, package `pyre-cli`)

- **One entrypoint,** `pyre <command>` (ADR 0014). Commands are files in `/usr/lib/pyre/commands/` with `# help:` and `# usage:` header metadata. The shared library is in `/usr/lib/pyre/lib/`, and the reconcile units are in `/usr/lib/pyre/reconcile/{system,user}/`.
- **Commands:** `update`, `snapshot`, `rollback`, `doctor`, `reconcile`, `hw`, `install`/`remove <bundle>`, `theme`, `keys`, `menu`, `welcome`, `remind`, `help`.
- **Triggers:** an ALPM hook (`pyre-reconcile.hook`) runs system reconcile after `pyre-*` packages change, and `pyre-reconcile.service` (a user unit enabled globally) runs user reconcile at login. `pyre-remind.service` sets the reminders' timers when the desktop starts.
- **Budget:** under 5,000 lines total for the CLI plus the installer before 1.0. Every command needs a test, and anything over budget needs a reason in its ADR.

### Agent skill (`skills/`, shipped in `pyre-cli`, ADR 0019)

- **One skill, `pyre`,** tells a coding agent on an installed machine how PyreOS is put together: which files are the user's, which are read-only, the `pyre` commands, and when to ask first. It is Markdown only, and it points to the installed defaults and the user guide instead of repeating them.
- **The user reconcile unit `004-agent-skills`** links each skill in `/usr/share/pyre/skills/` into `~/.claude/skills/` (Claude Code) and `~/.agents/skills/` (Codex, Gemini CLI, opencode). A skill of the user's own under the same name is left alone.
- **`tests/skill.bats`** fails when the skill names a command, theme, bundle or installed path that this repository does not have, or misses a command.

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
src/desktop/               small desktop helpers (pyre-record) and the Noctalia plugins (welcome, remind)
system/                    → package-owned drop-ins
themes/                    theme data: theme.toml and a Noctalia palette per theme
skills/                    → /usr/share/pyre/skills (the agent skill, for coding agents on an installed machine)
iso/                       archiso profile (releng-derived)
tests/                     bats unit tests, VM e2e scenarios
tools/                     build-pkgs, build-iso, run-vm, test-e2e, test-remind, publish-repo
docs/                      brief, architecture, roadmap, status, handoff, decisions/, reference/,
                           guide/ (the user guide, → /usr/share/doc/pyre/guide)
landing/                   the website: site/ is published to GitHub Pages as-is
```

Generated ISOs, packages, VM disks, keys, and secrets go only under the ignored `build/`.

## Development loop

1. `tools/build-pkgs` builds packages into the local repo `build/repo/`.
2. `sudo tools/build-iso` runs `mkarchiso` on `iso/` with the local repo injected and writes to `build/out/`.
3. `tools/run-vm <iso>` boots it with QEMU/KVM and UEFI (OVMF), or BIOS with `--bios`. It uses disposable qcow2 disks under `build/vm/`, a serial log, and a monitor socket for screendumps.
4. `tools/test-iso` boot-checks an ISO under UEFI and BIOS, covering the serial login, identity, and keyring.
5. `tools/test-e2e` runs an unattended install, then boot, then assertions over the serial console and screenshots.
6. `tools/test-machine` drives the interactive installer by keyboard next to a stand-in Windows disk, then checks hibernation, the Windows entry, three outputs and suspend (P6).

CI runs the same scripts.
