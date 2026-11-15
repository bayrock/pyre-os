# Development

PyreOS is made by people who write software on it. Getting from a fresh install to a first commit takes one command.

## Set up

Open the launcher (**Super + Space**), type `git` and choose **Setup › Development**. The welcome panel has it too, as "Set up for development". Or run this in a terminal:

```
pyre dev
```

It asks about each part that is not set up yet, and Enter skips any of them:

- **Your name and email for git.** Every commit carries them. They go into your own `~/.config/git/config`.
- **The development tools:** compilers, the GitHub CLI, lazygit, Go, Node.js, Python with uv, and rustup.
- **Signing in to GitHub**, once the tools are there.
- **A Rust toolchain**, which rustup downloads into your home.

If you answered these questions in the installer, there is nothing left to ask. `pyre dev --status` shows where things stand without changing anything.

## Passwords and tokens

When git asks for a password or a token, it keeps the answer in your keyring, which your login unlocks. You are asked once per site, not at every push.

## Editors

Neovim is installed. More are one step away: open the launcher, type `install`, and choose.

| Editor | What it is |
|---|---|
| Code - OSS | The open source build of VS Code. Its extensions come from Open VSX, not Microsoft's marketplace, so a few Microsoft-only extensions are missing |
| Zed | A fast graphical editor |
| Helix | A modal editor for the terminal |
| Emacs | The extensible editor |

## Coding agents

The same Install list holds the agents:

| Agent | Where it comes from |
|---|---|
| Codex | Arch's repositories |
| opencode | Arch's repositories |
| Gemini CLI | Arch's repositories |
| Claude Code | Anthropic's own installer. It is proprietary and not part of Arch, so PyreOS shows what it will run and asks first. It installs into your home (`~/.local/bin/claude`) and updates itself |

Each needs its own account or key. Whichever you use already knows PyreOS: a skill named `pyre` tells it where each setting lives, so you can ask for a keybinding or a rollback in plain words.

## Languages and containers

- **Versions per project:** install `mise` from the menu, then `mise use node@22` or `mise use python@3.13` in a project.
- **Python:** `uv` comes with the development tools: `uv init`, `uv add`, `uv run`.
- **Containers:** Docker, Podman and Distrobox are in the Install list. Docker's install offers to start it. To use Docker without sudo you must join the `docker` group, and whoever is in that group can act as root on the machine.

## Commands in your home

`~/.local/bin` is on your `PATH`. Tools that install themselves for one user, such as `uv tool install` and Claude Code, put their commands there.
