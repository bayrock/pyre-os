# ADR 0013: Desktop session, config layering and the first user's stubs

- Status: Accepted
- Date: 2026-11-08
- Builds on: ADR 0002 (niri), ADR 0005 (Noctalia), ADR 0011 (installer split)

## Context

P3 wires up the desktop. Three questions shape it:

- which component owns each part of the session
- how PyreOS defaults reach the user without being copied into `$HOME`
- who writes the few files that have to live in `/etc` or `$HOME`

The facts below come from the `extra` packages and upstream docs as of 2026-11-08: niri 26.04, noctalia 5.4.1, noctalia-greeter 1.7.0, greetd 0.10.3. STATUS lists the sources.

- **niri** reads `~/.config/niri/config.kdl`, and writes its own default config there when no config exists. Top-level `include` lines are positional: later settings override earlier ones, and `binds` override per key.
- **Noctalia** merges `~/.config/noctalia/*.toml` with `[include]` files under them, then GUI overrides from `~/.local/state/noctalia/settings.toml`. It has no system-wide config directory. It ships a polkit agent (off by default), a lock screen reached by `loginctl lock-session`, idle behaviours, clipboard history, notifications and OSDs.
- **noctalia-greeter** runs under greetd as user `greeter`. Upstream setup is a hand edit of `/etc/greetd/config.toml`.
- **archinstall 4.5** creates the users before it installs the extra `packages`, so `useradd -m` copies `/etc/skel` before `pyre-desktop` puts its stubs there.
- **`/etc/skel/.bashrc`** belongs to the `bash` package.

## Decision

**One package, `pyre-desktop`.** It depends on the whole stack and the default apps, and it ships:

- the defaults in `/usr/share/pyre/defaults/{niri,noctalia,foot,bash}`
- the user stubs in `/etc/skel/.config` (as `backup=()`)
- `pyre-record`

A separate defaults package would add a package without a consumer.

**Session ownership:**

| Function | Owner |
|---|---|
| Login | greetd with `noctalia-greeter-session`; optional autologin as greetd's `initial_session` running `niri-session` |
| Compositor | `niri-session`, which runs `niri.service` in the systemd user session |
| Shell, polkit agent, lock, idle, notifications, clipboard history, OSD | Noctalia, started by niri's `spawn-at-startup`. `polkit_agent = true`; idle locks at 10 minutes and turns the screens off at 11. |
| Portals | niri's `niri-portals.conf`: gnome, then gtk; `gnome-keyring` for Secret |
| Screenshots | niri's built-in screenshot UI |
| Recording | `pyre-record`: a toggle around `gpu-screen-recorder -w portal`. Noctalia's recorder plugin is fetched from git at runtime, which ADR 0005 rules out as a default. |

**Layering.** Each user stub is a few lines that include the package-owned defaults, then leave room for the user's own settings, which win:

| App | Stub | Include |
|---|---|---|
| niri | `~/.config/niri/config.kdl` | `include "/usr/share/pyre/defaults/niri/pyre.kdl"` |
| Noctalia | `~/.config/noctalia/config.toml` | `[include] files = ["/usr/share/pyre/defaults/noctalia/pyre.toml"]` |
| foot | `~/.config/foot/foot.ini` | `include=/usr/share/pyre/defaults/foot/foot.ini` |
| bash | `~/.bashrc` | `source /usr/share/pyre/defaults/bash/rc` |

The keyboard layout is not in the defaults. niri's empty `xkb {}` reads it from systemd-localed, and archinstall sets it with `localectl set-keymap`.

**Installer steps** (`src/installer/lib/desktop.sh`, after the boot stack):

1. archinstall installs `pyre-desktop` and enables `greetd`, `bluetooth` and `power-profiles-daemon`.
2. `pyre-install` writes `/etc/greetd/config.toml` once, and adds `pam_gnome_keyring` (auth, and session with `auto_start`) to `/etc/pam.d/greetd`, so the login password creates and unlocks the keyring. Without it, the first app that asks Secret Service for a secret opens a "new keyring password" dialog at login. greetd marks both files `backup=()`, so they are the admin's afterwards. The greeter's own session uses the `greetd-greeter` PAM service, which `pyre-desktop` ships in `/usr/lib/pam.d` without the keyring lines, so the `greeter` user starts no keyring daemon.
3. `pyre-install` seeds the first user's home:
   - it copies `/etc/skel/.config` without overwriting anything
   - it replaces `~/.bashrc` only while it is still byte-identical to bash's `/etc/skel/.bashrc`

   Running the step twice changes nothing.

## Consequences

- PyreOS changes to defaults reach every user on the next package update, because the stubs never hold the defaults themselves.
- A user created later with `useradd -m` gets the niri, Noctalia and foot stubs from `/etc/skel`, but bash's own `.bashrc`. The P4 user-scope reconcile closes that gap with the same seeding rule.
- GUI changes in Noctalia land in its state file, never in the stub, so `settings.toml` can override a PyreOS default without the user noticing. Noctalia's docs say to look there first.
- With autologin there is no password at login, so the keyring stays locked and prompts on first use.
- Noctalia's first-run wizard is off (`setup_wizard_enabled = false`), because PyreOS presets what it asks. The P5 welcome flow replaces it.
