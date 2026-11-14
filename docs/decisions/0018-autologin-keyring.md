# ADR 0018: An autologin install gets a keyring without a password

- Status: Accepted
- Date: 2026-11-14
- Amends: ADR 0013 ("with autologin … the keyring stays locked and prompts on first use")

## Context

`pyre-install` adds `pam_gnome_keyring` to greetd's PAM stack, so a password typed at the login screen creates and unlocks the `login` keyring (ADR 0013). With autologin nobody types one, so there is no password to create or unlock a keyring with.

ADR 0013 accepted a prompt "on first use". The first autologin boot in a VM (`tools/test-machine`, 2026-11-14) showed what that means:

- Noctalia asks the secret service when it starts, so "Choose password for new keyring" is on the desktop seconds after the first login, before the user has done anything.
- Whatever is typed there must be typed again at every boot, which undoes autologin.
- While the dialog is open, Noctalia does not exit when the session stops, and a shutdown waits out its 90-second stop timeout (92 s measured, against 2 s without the dialog).

The usual answer is a default keyring with an empty password, which gnome-keyring stores in a plain format. The development machine's current system is set up that way. Handing the disk passphrase to the keyring instead (systemd's `pam_systemd_loadkey`) was not tried: it ties the keyring to the disk passphrase and needs greetd to run PAM's auth phase for a session nobody logged in to.

## Decision

When autologin is chosen, `pyre-install` creates the first user's default keyring without a password:

- `~/.local/share/keyrings/Default_keyring.keyring`, in gnome-keyring's plain format, mode 600
- `~/.local/share/keyrings/default`, naming it

Installs without autologin are unchanged: the login password creates and unlocks an encrypted `login` keyring.

## Consequences

- No keyring dialog on an autologin system. Apps store and read secrets from the first login (`secret-tool` in `tools/test-machine`).
- The secrets in that keyring are not encrypted separately. The disk encryption protects them when the machine is off; while it runs, the session is open to whoever sits down, which autologin already means.
- A user who wants an encrypted keyring sets a password on it in a keyring manager (for example Seahorse), and is then asked for it once per boot.
- Turning autologin on after the install does not create the keyring. The dialog appears once, and leaving its password empty has the same effect.
