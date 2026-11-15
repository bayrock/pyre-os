# ADR 0022: From install to a first commit without hand work

- Status: Accepted
- Date: 2026-11-14
- Amends: ADR 0021, point 4 ("The catalog is Arch's official repositories")

## Context

PyreOS is built by people who write software on it, and the Hyprland-based Arch desktops many users come from treat development as a first-class use. On PyreOS the pieces were present and unconnected:

- The `dev` bundle needed a network, and neither the installer nor the welcome panel offered it.
- git had no name, email or credential store, although git's libsecret helper and a keyring that the login unlocks (ADR 0018) are on every install.
- git and ssh were installed only as dependencies of other packages.
- `~/.local/bin`, where tools that install per user put their commands, was not on `PATH`.
- No coding agent was in the menu. Codex, opencode and Gemini CLI are in Arch's `extra`. Claude Code is not in Arch's repositories; neither is Microsoft's build of VS Code.

Decided with the owner on 2026-11-14: the installer offers the development tools and carries them on the ISO; the git identity is an optional question; and the menu may hold a short, labeled list of vendor installers.

Anthropic's setup page, read on 2026-11-14 (<https://code.claude.com/docs/en/setup>): the recommended install is `curl -fsSL https://claude.ai/install.sh | bash`. It needs no root, puts a launcher at `~/.local/bin/claude` and versions under `~/.local/share/claude/`, and updates itself. Removing those two paths uninstalls it; settings stay in `~/.claude`.

## Decision

- **`pyre dev`** (`src/cli/commands/dev`) sets a machine up, one skippable question per part: the git name and email, the `dev` bundle, the GitHub sign-in (`gh auth login`), a Rust toolchain. A second run asks nothing that is already answered. `pyre dev --status` only reports.
  - `pyre dev git --name … --email …` is the one place that writes the identity. It goes into the user's own `~/.config/git/config` (or `~/.gitconfig` if they have one), through git itself.
  - It names git's libsecret helper as the credential store unless a store is already chosen, so tokens rest in the keyring.
  - PyreOS never writes these settings unasked.
- **The installer** asks for an optional name and email, and whether to install the development tools. It runs `pyre dev git` as the new user and adds `pyre-bundle-dev` to the install. The bundle's packages are in the ISO's offline repository, so this works without a network. The config keys are `git_name`, `git_email` and `dev_tools`.
- **The welcome panel and the menu** open `pyre dev` in the floating terminal ("Set up for development", "Setup › Development").
- **`pyre-desktop`** names `git` and `openssh` as dependencies and adds `~/.local/bin` to `PATH` through `/etc/profile.d/`.
- **The catalog** gains Codex, opencode, Gemini CLI and mise, all from `extra`. VS Code is Code - OSS, also from `extra`.
- **A vendor row** installs an app from outside Arch's repositories with its maker's own installer. The rules:
  - The installer is the one the vendor documents, fetched over https, run as the user, and it writes only into the home directory.
  - What runs is a function in `pyre menu`, never a line in a data file. The row's argument only names it.
  - The row says "proprietary" where that is so. The terminal shows the address and what will happen, and asks before it fetches anything. The script is downloaded whole before it runs.
  - Nothing is installed by default, and nothing is bundled or mirrored.
  - Claude Code is the only one. A second needs the same reading of its vendor's documentation, recorded here.
- **Docker**, once installed from the menu, offers to start now and at boot, and says what membership of the `docker` group means.

## Consequences

- **"No vendor defaults" holds.** A fresh install has no agent and no account-bound service. A vendor row is a labeled door, not a default.
- **PyreOS does not verify what a vendor installer fetches.** It trusts https and the vendor, as the user would by pasting the command. Anthropic signs a manifest of its binaries; checking it is left to the user.
- **pacman does not know a vendor app.** `pyre update`, snapshots of `/` and `pyre remove` do not cover it. It lives in the home, which has its own snapshots.
- **The ISO grows** by the dev bundle's packages (Go, Node.js, the compilers and the rest).
- **Not covered:** an SSH agent backed by the keyring. `gh auth login` and https with the keyring cover the first push.
- **Tests:** `tests/pyre-dev.bats`, the installer and menu tests, `tools/test-e2e` (an identity from the config, no tools), `tools/test-machine` (every answer typed, the tools from the offline repository) and `tools/test-dev` (the terminal flow, the keyring as the store, the agents and Docker from the menu).
- About 250 lines of bash against the budget (ARCHITECTURE); the CLI and the installer together are near 3,100 of 5,000.
