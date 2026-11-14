# Handoff

## Next task: P5, polish and identity (in progress)

**P5 is built and in review (2026-11-14).** Every P5 item is done: four themes (Ember, Birch, Evergreen, Frost), boot branding, the welcome panel (ADR 0016) and the user guide (`docs/guide/`). `tools/test-theme` and `tools/test-visual` pass (see STATUS). To accept P5:
- The user reviews the captures in `build/vm/test-visual/share/` and signs off.
- The user rebuilds the ISO (`sudo tools/build-iso`), then `tools/test-iso` and `tools/test-e2e` run. `test-e2e` now closes the welcome panel at the first login before its desktop checks.

1. **The release key: done on 2026-11-13** (`docs/reference/release-key.md`). The primary key is offline, the subkey is in the Actions secret `PYRE_SIGNING_SUBKEY`, and `pyre-keyring` 0.2.0 trusts it alongside the dev key. Release images drop the dev key in P7.
2. **The testing channel: live on 2026-11-13** (`docs/BUILDING.md`, "The testing channel"). Every push to `main` publishes signed packages to the `testing` release, and `pyre-release` 0.3.0 points installed systems at it. **Any package change needs a `pkgver`/`pkgrel` bump**, or the publish job fails. `tools/test-channel` checks that an installed VM updates from it.
3. **P5 theme system: started on 2026-11-13** (ADR 0015). A theme is a Noctalia palette in `themes/<id>/`, shipped by `pyre-themes`. Ember comes from the landing page. Noctalia's built-in templates color niri, foot, GTK 3/4 and btop, and `pyre theme` lists and sets themes. `tools/test-theme` (VM) passes. Next in P5:
   - Done: the Ember wallpaper (`tools/render-wallpaper`), live recolor of open foot and GTK windows (`pyre theme refresh`), the Limine boot menu (`pyre-boot-branding`), and the Plymouth splash (`tools/test-splash`).
   - Done too: the ISO's BIOS menu (the cabin splash and Ember's `MENU COLOR`s, `iso/UPSTREAM.md` item 9).
   - Done too: the login screen (Ember seeded until someone syncs, no Noctalia logo). Boot branding is complete: Limine, Plymouth, the ISO's BIOS menu and the greeter all wear Ember (ADR 0015).
   - Next in P5: curated alternative themes (license-checked palettes), the welcome flow, and user documentation. Then the P5 exit review: a full visual pass from boot splash to lock screen.
   - **The next ISO rebuild** (user, `sudo tools/build-iso`) brings Plymouth and the BIOS splash to the ISO and fresh installs. Then run:
     - `tools/test-iso`: it fails BIOS on the current ISO, which still shows releng's Arch logo, by design
     - `tools/test-e2e`: it unlocks through Plymouth's text mode (the test VMs use a serial console)
   - Curated alternative themes (license-checked palettes), and the welcome flow and user docs.
   - **Pending ISO rebuild (user, `sudo tools/build-iso`):** the next `tools/test-e2e` run checks Ember from the first login on a fresh install (`theme-ember` and the checks after it in the desktop stage).
4. **Optional: install images.** Publishing the ISO to the `testing` release (CI needs a privileged container for mkarchiso, and the 3.7 GB image is over GitHub's 2 GiB per-asset limit, so it must be split or slimmed) would unlock the landing page's "Install" pill. The pill waits for install images, not packages (`landing/README.md`).
5. **Landing page:** live at <https://bayrock.github.io/pyre-os/> (Pages source: GitHub Actions).

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
