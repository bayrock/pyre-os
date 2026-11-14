# ADR 0019: PyreOS ships an agent skill, linked into each home

- Status: Accepted
- Date: 2026-11-14

## Context

People increasingly change their desktop by asking a coding agent to do it. An agent that knows nothing about PyreOS guesses: it edits a defaults file under `/usr/share/pyre`, copies a default into `~/.config` where it stops following updates, removes a stub's include line, or reaches for a tool PyreOS does not ship. The layering in ARCHITECTURE only works when whoever edits the files knows about it.

Agents have a common format for such knowledge, the skill: a directory with a `SKILL.md`, whose frontmatter says when to load it, and further files it links to. Another Arch-based desktop ships one this way: the skills are package-owned directories, and a per-user provisioning script links each into six agent directories in the home.

Where agents read user skills from, checked on 2026-11-14:

| Agent | User skills | Source |
|---|---|---|
| Claude Code | `~/.claude/skills` | Observed on the development machine, which loads its skills through links there |
| Codex | `$HOME/.agents/skills`; follows symlinked skill folders. Admin scope: `/etc/codex/skills` | <https://learn.chatgpt.com/docs/build-skills.md> |
| Gemini CLI | `~/.gemini/skills` "or the `~/.agents/skills/` alias" | <https://geminicli.com/docs/cli/creating-skills.md> |
| opencode | `~/.config/opencode/skills`, and for compatibility `~/.claude/skills` and `~/.agents/skills` | <https://opencode.ai/docs/skills.md> |

No agent reads a system-wide directory that a user can override, apart from Codex's admin scope, so a skill has to be reachable from the home directory.

## Decision

- **PyreOS ships one skill, `pyre`** (`skills/pyre/` in this repository). `pyre-cli` installs it read-only to `/usr/share/pyre/skills/pyre/`.
  - It is for the person at an installed machine: where each setting lives, what is read-only, the `pyre` commands, and when to ask first. Developing PyreOS itself stays in `AGENTS.md`.
  - It points to the installed defaults and the user guide (`/usr/share/doc/pyre/guide/`) rather than repeating them.
  - It is data: Markdown only, no scripts.
- **A user reconcile unit, `004-agent-skills`, links every skill in `/usr/share/pyre/skills/` into `~/.claude/skills/` and `~/.agents/skills/`.** Those two directories reach the four agents above.
  - A link follows package updates, like the theme palettes (ADR 0015).
  - Anything of the user's under the same name is left alone: a file, a directory, or a link that points outside `/usr/share/pyre/skills/`. Only a stale link of PyreOS's own is repointed.
  - It runs for the first user from `pyre-install`, for a new user at the first login, and for existing users at the first login after the update.
- **`tests/skill.bats` keeps the skill true:** every command in `src/cli/commands/` is named in it, and every command, theme, bundle and installed path it names exists in this repository.

## Consequences

- **No vendor default.** The skill is plain text that an agent reads if the user runs one. It installs no agent, needs no account, and turns nothing on, so the "no personal or vendor defaults" rule holds. The cost is two small dot-directories in every home, created even for a user who never runs an agent. Linking only into directories that already exist would miss an agent installed later, since a unit runs once.
- **Two directories, not every agent's own.** An agent that reads neither gets no skill until a new unit version adds its directory. That is a one-line change, made when someone asks for it with the agent's documentation in hand.
- **A further skill** goes in `skills/<name>/`. Because a unit runs once per version, it also needs a new unit version to be linked for existing users.
- **The skill can go stale in prose** even while the test passes: the test checks names, not explanations. A change to how a setting is layered or a command behaves must update the skill in the same commit.
- **Not exercised:** an agent loading the skill on PyreOS. The VM has no agent installed. The same link layout is what the development machine's Claude Code and Codex load skills from today.
