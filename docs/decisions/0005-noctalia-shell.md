# ADR 0005: Noctalia v5 as the desktop shell

- Status: Accepted (desktop validation gates P3 acceptance)
- Date: 2026-11-07

## Context

The shell provides the bar, launcher, notifications, OSD, lock screen, idle handling, settings, and wallpaper.

Another Arch-based desktop built its own shell: about 58k lines of QML/JS on a patched Quickshell snapshot, running unsandboxed third-party plugins in the same process as the lock screen and polkit agent.

Options considered:

- **Own Quickshell shell.** Gives full control, and the author's existing QML plugins would carry over. But it means a very large amount of code to own on a 0.x dependency, and a slow road to polish.
- **Noctalia v5.** A ground-up native rewrite in C++ that renders directly on Wayland with OpenGL ES, with no Qt or GTK. It is in Arch `extra` (5.3.0 in the local sync DB on 2026-11-07; upstream 5.4.1, released 2026-10-31). It supports Niri and other compositors. Plugins are written in Luau and get declarative UI, their own layer surfaces, timers, process execution, an OSD API, and system stats. It includes an audio visualizer widget, desktop widgets, and a palette system. A matching `noctalia-greeter` is also in `extra`.
- **DankMaterialShell** (QML) and others. The `extra` packages lag upstream, and this would put us back on the Quickshell dependency.

## Decision

- Adopt upstream Noctalia v5 as the shell and `noctalia-greeter` (on greetd) for login.
- PyreOS owns only configuration, theming integration, and packaging glue. It owns no shell code.
- Do not fork Noctalia. Report bugs and contribute fixes upstream.

## Consequences

- The lean priority is met. Polish arrives early, and shell maintenance is upstream's job.
- PyreOS's look depends on Noctalia's design language. The theme system must drive Noctalia's palette, not fight it.
- Coverage checks for P3: polkit agent, idle and lock behaviour, the clipboard history UI, notification actions, and screen-share indicators. Any gap is filled with small upstream tools, not custom code.
- The author's existing Quickshell plugins:
  - **music-visualizer** can use Noctalia's audio visualizer or be ported to a Luau plugin.
  - **dance2shell** can keep running as a standalone Quickshell config (`quickshell` is in `extra`) from the user overlay.
  - **screen-glitch** depended on Hyprland's full-screen shader. Niri exposes only animation shaders, so this one is deferred.
- Luau plugins are trusted, unsandboxed code. PyreOS ships no third-party plugins by default.
- If Noctalia stalls or regresses badly, revisit this ADR. The shell boundary (theme output, keybinding IPC calls) stays narrow so a replacement remains feasible.
