# Handoff

## Next task: P6, daily driver on the development machine

P5 was accepted on 2026-11-14 (STATUS). P6 is in `docs/ROADMAP.md`; the machine is described in `docs/reference/dev-machine.md`. It is the first phase on real hardware, and the host is the user's working desktop, so **every step that touches the host's boot setup, disks or desktop config needs the user**: the agent plans, builds and tests in VMs, and the user runs the host steps.

Suggested order:
1. **A P6 plan with the user:** what can be proven in VMs first, and the migration's order and safety net (a verified home backup and a recovery USB for the current system before anything is installed).
2. **Gaps that VMs can close first** (STATUS, "Carried over"): the hibernation swapfile option in the installer, Windows chainload detection (`FIND_BOOTLOADERS=yes`), three outputs with one portrait (`run-vm --outputs 3`), and the interactive gum TUI, which only `--config` has exercised.
3. **Real hardware:** `pyre hw` against the RTX 3060 Ti (`nvidia-open-dkms`), VRR at 240 Hz, suspend and hibernate, the peripherals, Bluetooth.
4. **The author's overlay repo** (keybind extras, monitor layout, fonts, the personal Quickshell toys; ADR 0005), kept out of distribution defaults.
5. **Migrate**, then a week of daily use with issues logged (the exit criterion).

Standing facts:
- **The testing channel** (`docs/BUILDING.md`): every push to `main` publishes signed packages, so **any package change needs a `pkgver`/`pkgrel` bump**; `tools/check` runs `tools/check-bumps`. The release key's subkey is in the Actions secret `PYRE_SIGNING_SUBKEY` (`docs/reference/release-key.md`).
- **Install images** are not published yet. CI needs a privileged container for mkarchiso, and the ISO is over GitHub's 2 GiB per-asset limit. They unlock the landing page's "Install" pill (P7, or earlier if wanted).
- **Brand assets:** `docs/images/` (wordmark, preview, avatar; `tools/render-avatar`), the landing page at <https://bayrock.github.io/pyre-os/>. Themes and wallpapers come from `tools/theme-palettes` and `tools/render-wallpaper`.
- **VM tests:** `tools/test-e2e`, `test-iso`, `test-upgrade`, `test-channel`, `test-theme`, `test-splash`, `test-visual` (each prints its usage with `--help`). Boot surfaces are captured only without GL (`--display none`); niri skips software renderers, so desktop captures need GL and come from niri's own screenshots.

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
