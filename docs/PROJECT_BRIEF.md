# Project brief

## Mission

PyreOS is a polished, keyboard-first Arch Linux desktop. Enthusiasts build it for themselves and anyone who wants it. It aims for a cohesive Wayland desktop, everything shipped as packages, beautiful themes, and snapshot-backed updates. Its engineering is safer and leaner, and it is run as a humble community project with no corporate backing, vendor tie-ins, or personality cult.

It starts as the primary author's daily driver and is built to the standard of a distribution others can install and trust.

## Settled decisions (2026-11-07)

| Area | Decision | ADR |
|---|---|---|
| Base | Arch Linux x86_64, stock kernels, systemd, pacman | [0001](decisions/0001-archiso-foundation.md) |
| Name | PyreOS: CLI `pyre`, packages `pyre-*`; "Ember" is the default theme and the 1.0 codename | [0004](decisions/0004-name-pyreos.md) |
| Compositor | Niri | [0002](decisions/0002-niri-noctalia-direction.md) |
| Shell | Noctalia v5, plus noctalia-greeter on greetd | [0005](decisions/0005-noctalia-shell.md) |
| Delivery | Own archiso ISO plus a thin TUI installer driving archinstall | [0006](decisions/0006-delivery-and-installer.md) |
| Updates | Plain pacman is always safe; reconcile instead of migrations | [0007](decisions/0007-update-and-reconcile-model.md) |
| Storage/boot | LUKS2 + btrfs, Limine, snapper (root and home), systemd initramfs | [0008](decisions/0008-storage-and-boot.md) |
| Packages | Signed `[pyre]` repo after Arch's repos, CI-built | [0009](decisions/0009-package-repository.md) |
| Themes | A theme is a Noctalia palette; Noctalia's templates color the apps | [0015](decisions/0015-theme-system.md) |
| Welcome | A Noctalia plugin panel, "Welcome home", with the user guide in place | [0016](decisions/0016-welcome-panel.md) |

## Priorities

When goals conflict, apply them in this order:

1. **Safe updates and rollback.** An update must never strand the user. Every change can be rolled back, including changes to user state.
2. **Polish and aesthetics.** One cohesive visual identity from boot splash to lock screen, with a theme system that reaches every default app.
3. **Lean and understandable.** A small, auditable codebase and a minimal default app set. Someone can read the whole distro in an afternoon.

Clean separation between distribution defaults and user configuration underpins all three.

## Principles

1. **Upstream first.** Use official Arch packages and upstream projects. Do not fork without proven need.
2. **Your files are yours.** Defaults live in `/usr`. User files are thin stubs that include them, and updates never overwrite either admin or user edits.
3. **Everything is a package.** pacman is the source of truth for what is installed and who owns each file.
4. **Idempotent, declarative lifecycle.** The system converges to a desired state. Running a step twice changes nothing.
5. **No personal or vendor defaults.** Defaults serve everyone. Opinions about specific apps go into optional bundles.
6. **Evidence over claims.** Every phase is verified by a reproducible test, usually in a VM.
7. **Community over capture.** Use an open license, keep decisions in public ADRs, adopt a code of conduct, take no sponsorship with strings, and collect no telemetry.

## Prior art

Other Arch-based desktop distributions, including the one on the development machine, are references for workflows and good ideas, never codebases to clone. Prefer reimplementing from the idea. Any adapted snippet must keep its original license notice.

## Scope

**In scope:**
- the ISO and installer
- base system defaults
- the Niri and Noctalia desktop integration
- the theme system
- a small `pyre` CLI
- hardware rules
- optional app bundles
- a signed package repository
- documentation

**Out of scope:**
- custom kernels, package managers, or update systems
- atomic or image-based delivery
- GUI installers
- AI-usage meters, vendor web apps, and account-bound services enabled by default
