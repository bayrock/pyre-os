# Shared project instructions

This repository is the source of truth for **PyreOS**, an independent, community-run Arch Linux distribution built around Niri and Noctalia. These rules apply to every contributor and coding agent.

## Start of session

Read only what the task needs, in this order:

1. `docs/HANDOFF.md`: the next task. Usually enough to start.
2. `docs/STATUS.md`: current state, verified facts, open questions.
3. Only when the task touches them: `docs/ARCHITECTURE.md` (design and layout), `docs/ROADMAP.md` (phase exit criteria), and the relevant ADR in `docs/decisions/`.

`docs/PROJECT_BRIEF.md` and `docs/reference/` give background. Do not re-read them every session.

## Settled decisions

Do not reopen these without new evidence and a superseding ADR.

- Arch Linux x86_64 with stock kernels, systemd, and pacman.
- Niri as the compositor, Noctalia v5 as the shell, and noctalia-greeter on greetd.
- Our own archiso ISO plus a thin installer that drives archinstall.
- Priorities in order: safe updates and rollback, then polish, then lean and understandable code.
- Plain `pacman -Syu` must always be safe. Never add an update guard.

## Workflow

- **Act within the active phase without asking.** Pick the next HANDOFF step, implement it, verify it, commit it, and move on. Ask the user only for:
  - privileged commands (their password)
  - new host packages
  - irreversible or outward-facing actions outside the repo
  - genuine product decisions not covered by an ADR
- **Batch user interventions.** When several steps need sudo, gather them into one command for the user to run, and keep working on other steps meanwhile.
- **Verify with one command.** Run `tools/check` (shellcheck, Python syntax, profile check, bats, markdown links, whitespace) before every commit. Changes that affect a build or boot also need a VM run (`tools/run-vm` + `tools/vm-ctl`). Screendumps and logs stay under `build/`; record only a one-line summary in STATUS.
- **Git.**
  - Commit and push to `main` directly after each verified, coherent step.
  - Use a short-lived branch only for risky or multi-session work. Fast-forward or merge it into `main` promptly, then delete it.
  - Never force-push `main`.
  - Use Conventional Commit prefixes (`feat:`, `fix:`, `docs:`, `build:`, `test:`, `chore:`), with a body when the reason is not obvious.
  - Commits made by Claude Code end with its attribution trailer.
- **Docs are current state, not a diary.** Git history is the log.
  - `STATUS.md`: the current phase, a progress table, verified facts, and open questions. Replace stale content; never append session narratives.
  - `HANDOFF.md`: a numbered list of the next steps and nothing else. Update it whenever the next step changes.
  - Phase acceptance: mark the phase accepted in `ROADMAP.md`, keep its exit evidence in `STATUS.md` (a few lines), and drop that phase's progress table.
- **ADRs** cover decisions that constrain future work. Keep each to a page or less. Supersede old ADRs rather than editing them into contradiction.
- **Research once.** Record external findings with source URLs and dates in the relevant ADR or `docs/reference/`, so they are not researched again.

## Engineering rules

- **Upstream first.** Use official Arch packages and upstream projects. Add no custom kernel, package manager, or fork without an ADR that shows the need. The `[pyre]` repository never takes precedence over Arch's own repositories.
- **Never clobber admin or user files.**
  - Ship defaults under `/usr/share/pyre` and `/usr/lib`.
  - Make system changes through drop-in directories or pacman `backup=()` files.
  - Never `cp -f` over `/etc` from package scriptlets.
  - Never sed-patch files in `$HOME`.
- **Idempotent lifecycle.** Install, reconcile, and hardware steps must be safe to run twice, and tests must prove it.
- **No personal or vendor defaults.** Personal preferences belong in the user's own overlay. Nothing proprietary or account-bound ships enabled by default.
- **Code quality.**
  - Bash scripts use `set -euo pipefail`, pass shellcheck, and logic gets `bats` tests under `tests/`.
  - Python is for dev tools only: stdlib only, run with `-I`.
  - Data files (menus, rules, themes) never contain executable shell.
  - Respect the CLI and installer line budget in `docs/ARCHITECTURE.md`.
- **Evidence.** Never claim something is verified unless it was run and its output was inspected. State plainly what was not exercised.

## Host safety

The development machine runs a daily-driver Arch-based desktop install. It is a reference environment, not a target.

**Allowed on the host:**
- Read-only inspection.
- The approved dev tools: `archiso`, `qemu-desktop`, `edk2-ovmf`, `shellcheck`, `bats`, `devtools` (clean-chroot package builds). Ask before adding others.
- Building packages and ISOs.
- QEMU/KVM VMs on disposable images under the ignored `build/` directory.

**Never on the host:**
- Changing desktop or user configuration.
- Touching boot entries, the bootloader, or the kernel.
- Enabling or altering services.
- Writing to physical disks.
- Running system upgrades for project purposes.

Privileged commands need the user's password. Ask them to run the exact command, for example `! sudo …` in Claude Code. Never request or store credentials.

## Repository hygiene

- Generated output goes only under `build/`, which is ignored. Never commit ISOs, packages, VM disks, keys, or secrets.
- Keep machine identifiers and private data out of the repo. Hardware notes stay at model level.
