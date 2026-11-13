# Handoff

## Next task: P4 final evidence and the hosting decision

Both P4 exit tests pass from network installs (STATUS).

1. **Ask the user for one ISO rebuild** (`sudo tools/build-iso`). Its installer is 0.3.0, and its offline repository gains `pyre-cli` and the hardware packages.
2. Run `tools/test-e2e` and `tools/test-upgrade` from the new ISO. The ISO's packages are release N-1, and `test-upgrade` builds N and N+1 from the tree. Run `tools/test-iso` too. Record the evidence and ask the user to accept P4.
3. **Hosting is decided:** the repository goes public (user, 2026-11-12), and the testing channel will be a GitHub Release on it. It needs:
   - the user to make the repository public in GitHub settings
   - a release signing key with a CI-held subkey, which the user creates and stores as an Actions secret (ADR 0009)
   - then a CI job that builds, signs and uploads `[pyre]`, and a `pyre-release` mirrorlist that points at the release
4. **Before announcing anything:** replace the releng boot splash (`iso/syslinux/splash.png`), which is Arch artwork. The menu text already says PyreOS. The artwork is P5.

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
