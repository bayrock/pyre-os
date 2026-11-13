# ADR 0004: Name the distribution PyreOS

- Status: Accepted
- Date: 2026-11-07

## Context

"EmberOS" was a working codename. Before identifiers spread into package names, paths, and a CLI, the project needed a durable public name. The author shortlisted Cinder (CinderOS) and Pyre (PyreOS) and asked for a branding-led decision.

Conflict research (web search, 2026-11-07):

- **CinderOS** already exists as a hobbyist Arch-based ISO distribution with `cinder-*` CLI tools. Its 1.0 release is even codenamed "Ember". "Cinder" also names OpenStack's block-storage service (packaged in Debian/Ubuntu as `cinder`), the libcinder C++ framework, and a Stanford research OS. A second Arch distro with the same name would compete directly for search results and identity.
- **PyreOS** has no Linux distribution using the name. The nearest uses are Meta's Pyre Python type checker (`pyre-check`, which provides a `pyre` command when pip-installed), Supergiant Games' *Pyre*, and an itch.io toy. The `pyreos` GitHub account is a dormant personal account with no OS project. `pyre-os` is free.

## Decision

- The distribution name is **PyreOS**.
- Identifiers:
  - CLI `pyre`
  - packages `pyre-*`
  - paths `/usr/share/pyre`, `/usr/lib/pyre`, `~/.local/state/pyre`
  - repository `[pyre]`
  - `os-release` `ID=pyreos`, `ID_LIKE=arch`
- "Ember" is kept as the default theme and the 1.0 release codename. This preserves the fire motif and the project's history.

## Consequences

- The CLI name `pyre` can collide with Meta's type checker when someone installs `pyre-check` globally with pip. That is uncommon on Arch, because pip installs usually go into virtual environments. If the collision causes real trouble, keep `pyre` and document it, or ship a `pyreos` alias. Do not rename casually.
- "Pyre" also evokes a funeral pyre. Branding should lean on warmth, forge, and signal-fire imagery.
- A trademark and domain check is required before any public release (roadmap P7).
- The local checkout directory and the GitHub repository are still named `emberos`. Renaming the GitHub repo is the owner's decision; GitHub redirects the old URL.
