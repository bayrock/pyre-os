# ADR 0016: The welcome panel is a Noctalia plugin

- Status: Accepted
- Date: 2026-11-14

## Context

P5 asks for a welcome and onboarding flow. A new user lands on a tiling desktop with no visible menu, so the first minute decides whether PyreOS feels like home or like homework. The flow should:

- greet the user in PyreOS's voice: the doormat of a cabin in the woods, "Welcome home."
- offer the few things worth doing first: choose a theme, learn the keys that matter, know where updates and help are
- show the user guide without a browser or a network
- look like the rest of the desktop and follow the theme live
- appear once, unasked, and stay findable afterwards

The desktop has no GUI toolkit of PyreOS's own. A GTK or Qt app would add a toolkit, a language runtime and a second look. A terminal walkthrough would not match the shell around it.

Noctalia 5.5, the shell (ADR 0005), runs plugins: sandboxed Luau scripts that declare their UI as a tree of Noctalia's own controls. A plugin can open a floating panel, color it with palette roles, run commands with an argument array, read files, and render Markdown. Plugins load from git sources, the user's data directory, or a read-only `path` source "for Nix-managed plugins".

## Decision

- **The welcome flow is a Noctalia panel plugin, `pyre/welcome`** (`src/desktop/welcome/`).
  - `pyre-desktop` installs it read-only to `/usr/share/pyre/noctalia/plugins/welcome/`.
  - PyreOS's Noctalia defaults (`defaults/noctalia/pyre.toml`) add that directory as a `path` source named `pyre` and enable the plugin. Like every default, the user's own config and Noctalia's settings window can turn it off.
  - It is data plus one Luau script. It changes the system only through `pyre` commands, so the CLI stays the one place where behavior lives and is tested.
- **What it shows:**
  - A banner of the current theme's cabin (`banner` in `theme.toml`), "Welcome home.", and one cozy line.
  - **Choose your light:** a button per installed theme, which runs `pyre theme set`. The panel recolors with everything else.
  - **Find your way around:** the five keys a new user needs first.
  - **Keep the place in order:** the user guide, `pyre update` and `pyre doctor` in a terminal, and Noctalia's settings.
  - A switch to greet at every login, and "Settle in" to close it.
  - **The guide:** the pages of `docs/guide/`, installed to `/usr/share/doc/pyre/guide/`, rendered in the panel by Noctalia's Markdown control. They work offline and read the same on GitHub.
- **When it shows: `pyre welcome`.**
  - niri's defaults run `pyre welcome --first-login` at session start. It waits for Noctalia, opens the panel, and records `~/.local/state/pyre/welcome/shown`. It never fails the session, and it retries at the next login if the panel did not open.
  - `pyre welcome --at-login on|off` chooses between every login and the first only.
  - `pyre welcome [guide]` opens it any time, and the launcher lists it as "Welcome to PyreOS" (with the PyreOS mark, installed as the `pyreos` icon that os-release's `LOGO` names). Asked for by name, it re-enables the plugin if the user had turned it off.
- **Existing users** see it once at their next login after the update, which doubles as a tour of what P5 added.

## Consequences

- **No new toolkit or runtime.** The panel is native to the shell, follows the palette without any theme code, and costs nothing when closed.
- **Coupled to Noctalia's plugin API.** The manifest pins `plugin_api = 24`, the newest level it uses (argument-array commands). Noctalia supports a range of levels and keeps old ones working; a break shows up in `tools/test-theme`, which opens the panel, clicks a theme button, and checks the result.
- **The guide has one source.** `docs/guide/` is the user documentation on GitHub and on the machine. The Keys page is `docs/KEYBINDINGS.md` itself, through a link.
- **Other surfaces can follow the same pattern**, for example a bar widget for `pyre update`. Each would be a plugin in the same source.
