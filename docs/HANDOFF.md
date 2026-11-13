# Handoff

## Next task: the hosted testing channel, then P5

1. **The release key** (ADR 0009, procedure in `docs/reference/release-key.md`). The private parts never pass through the agent:
   - done on 2026-11-13: the primary key `65D123DD…0A7F` (certify-only) and an ed25519 signing subkey
   - still to do: the user runs `tools/release-key-ci` to fill the Actions secret `PYRE_SIGNING_SUBKEY` and write `build/keys/pyre-release.asc`, then moves the keyring to two offline drives
   - then the agent commits the public key, so `pyre-keyring` trusts the release key alongside the dev key; release images will drop the dev key in P7
2. **CI publishing:** on pushes to `main`, build every package, sign it and the database with the subkey, and upload them to a GitHub Release named `testing`. Then `pyre-release`'s mirrorlist points at `https://github.com/bayrock/pyre-os/releases/download/testing`. Verify a VM can `pyre update` from it.
3. **P5 (ROADMAP):** `palette.toml`, matugen templates, `pyre theme`, the "Ember" theme, and branding (Limine, Plymouth, the greeter, wallpapers, and the boot splash, which is still Arch artwork).
4. **Landing page:** live at <https://bayrock.github.io/pyre-os/> (Pages source: GitHub Actions). When a testing release exists, add the "Install" pill (`landing/README.md`).

## Dev loop reference

- **Full e2e:** `tools/test-e2e` (about 15 minutes), and `tools/test-iso` (about 2 minutes).
- **Resume:** `tools/test-e2e --from first-boot|snapshot-boot|rollback` reuses the existing `build/vm/test-e2e` disk.
- **No ISO rebuild:**
  1. Serve `build/` with `python3 -I -m http.server 8080 --bind 127.0.0.1 --directory build`.
  2. Boot an ISO with `tools/run-vm --name test-e2e --fresh --display none <iso>`. `bootstrap-e2e.sh` installs the host's newest `pyre-installer` and installs everything from the network, so new packages in `build/repo` need no ISO rebuild.
  3. Type `curl -fsS 10.0.2.2:8080/dev/bootstrap-offline.sh | bash`, which installs offline with the host's newest `pyre-installer`, or `bootstrap-e2e.sh` for a network install.
  4. Run `tools/test-e2e --from first-boot`.

  For the upgrade test, `bootstrap-upgrade.sh` installs into `build/vm/test-upgrade` with `pyre_repo` at `/upgrade/repo`. Then run `tools/test-upgrade --from upgrade`.

  The `build/dev/` scripts are untracked and dev only.
- **ISO rebuilds** need the user to run `sudo tools/build-iso`. A first vendored-package build needs `tools/build-pkgs` in a terminal, for the chroot sudo. Batch requests for both.

## Boundaries

- Project root: the checkout. Remote: `origin` → `https://github.com/bayrock/pyre-os.git`, branch `main`. CI must stay green; the user can check the Actions tab, because `gh` is not installed.
- Host rules are in `AGENTS.md` under "Host safety". Dev tools and VMs are fine. Never touch desktop config, boot setup or disks. Installs happen only to qcow2 disks under `build/vm/`. New host packages need the user's approval.
