# ADR 0020: "Remind me" is a `pyre` command behind a launcher provider

- Status: Accepted
- Date: 2026-11-14

## Context

A desktop should let its user say "remind me about the tea in ten minutes" in a few keystrokes. PyreOS had no way to. Noctalia 5.5 (ADR 0005) reminds only of calendar events, and its launcher's providers are applications, calculator, emoji, panels, session, wallpaper and windows. Its official plugins add a countdown desktop widget, not reminders.

Noctalia's launcher takes plugin providers: a Luau script answers the text behind a prefix with result rows, and acts when a row is chosen. A provider without a prefix is asked on every search, as the built-in application search is.

What a reminder needs:

- a time read from what a person types: `10m`, `5pm`, `tomorrow 9am`, "call mum in 2 hours"
- to fire at that time on the wall clock, also after a suspend
- to survive the shell restarting, a logout and a reboot, and to turn up late rather than never
- to be seen: a notification that stays until it is dismissed

Researched on 2026-11-14 in Noctalia's sources and documentation at tag `v5.5.0` (<https://github.com/noctalia-dev/noctalia>: `docs/user/plugins/development/entries.mdx`, `src/launcher/plugin_launcher_provider.cpp`, `src/shell/launcher/launcher_panel.cpp`):

- A plugin provider's `onQuery(text)` gets the text behind its prefix, or the whole search when it has no prefix; the two cannot be told apart in one script.
- A provider keeps showing its last rows until it publishes new ones, and every publish makes the launcher gather its results again.
- Plugin scripts have no timers that outlive the shell.

## Decision

- **`pyre remind` owns reminders** (`src/cli/commands/remind`), like every other behavior of PyreOS (ADR 0014).
  - `pyre remind <when> [message]` reads the time at the start of the text, or else at its end. `list` shows what is pending and `cancel` drops one or all.
  - A reminder is a file, `~/.local/state/pyre/reminders/<number>`, holding its time and its message.
  - Its clock is a transient systemd user timer (`systemd-run --user --on-calendar`), which runs `pyre remind --fire <number>`: a notification without a timeout, then the file is removed. A calendar timer follows the wall clock across a suspend.
  - Transient timers end with the session. `pyre-remind.service`, wanted by `graphical-session.target`, runs `pyre remind --rearm` when the desktop starts: it sets the timers again, and a reminder that came due meanwhile fires then.
  - A reminder that cannot be shown (no notification service) keeps its file, and the next login shows it.
- **The launcher is a thin Noctalia plugin, `pyre/remind`** (`src/desktop/remind/`), installed and enabled like the welcome panel (ADR 0016). It has two providers that share one script:
  - behind the prefix: `/remind 10m tea`. `/remind` alone lists the pending reminders, and Enter on one cancels it.
  - without a prefix: `remind me to call mum at 5pm`, typed like any search. It answers only a search that starts with "remind", and publishes nothing for any other.
  - The row shows the time `pyre remind --parse` read from the text, before Enter sets it. Enter always sets what the text says, through `pyre remind`, so a fast Enter cannot set the text of an older row.

## Consequences

- **One parser, tested without a desktop.** The launcher and the terminal read times the same way, and bats covers it with a fixed clock (`tests/pyre-remind.bats`). `tools/test-remind` drives the launcher in a VM.
- **No daemon and no polling.** systemd holds the timers. Nothing runs between setting a reminder and its time.
- **A reminder is as reliable as the notification.** It stays on screen until dismissed and is kept in Noctalia's history, but it makes no sound of its own and follows Do Not Disturb like any other notification.
- **Coupled to Noctalia's plugin API** like ADR 0016: `plugin_api = 24`, and a provider without a prefix, which Noctalia's code supports but its documentation does not mention. If that goes away, `/remind` still works.
- **Not built:** repeating reminders and snooze. `pyre remind` again is three seconds.
- About 250 lines of bash against the CLI budget (ARCHITECTURE).
