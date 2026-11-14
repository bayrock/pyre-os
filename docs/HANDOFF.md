# Handoff

## Next task: P6, the migration (the next steps need the machine's owner)

Everything P6 can prove in a VM is built and passing (STATUS has the table). What is left touches the host's disks and firmware, so **the owner runs it** and the agent prepares, tests in VMs, and fixes what the machine shows.

1. **Owner: rebuild the ISO**, so it carries `pyre-installer` 0.4.0, `pyre-cli` 0.3.1 and `pyre-desktop` 0.3.2:

   ```sh
   tools/build-pkgs && sudo tools/build-iso
   ```

   Then anyone runs the VM tests on it, without `--local-packages`: `tools/test-iso`, `tools/test-machine`, `tools/test-nvidia`, `tools/test-e2e`. Record the results in STATUS.
2. **Owner: the safety net and the install**, step by step in `docs/reference/migration.md`: the home archive, the whole-disk image, the USB stick started through its **"UEFI:"** entry (the machine boots in BIOS mode today), then `pyre-install` onto the 120 GB SSD with autologin and hibernation.
3. **On the installed machine:** `tools/hw-report`, then the overlay (`../pyre-overlay`, `./install`). Check what only hardware shows: the output names, 240 Hz and VRR, suspend and hibernate, Bluetooth, the USB audio, the bar on the portrait screen, the Windows entry.
4. **Fix what the machine shows.** Log each issue in STATUS's P6 table; critical ones block the exit.
5. **A week of daily use** with the issues logged is the exit criterion (ROADMAP).

While waiting for the owner, work that needs no hardware:

- Bundles in the installer (ARCHITECTURE: "still to come"). The offline repository does not carry bundle packages, so an offline install can only offer them when a network is up.
- Report upstream: limine-snapper-sync's rough edges (STATUS), and the "EFI fallback" entry `limine-install` makes of Limine's own fallback copy.

Standing facts:
- **The testing channel** (`docs/BUILDING.md`): every push to `main` publishes signed packages, so **any package change needs a `pkgver`/`pkgrel` bump**; `tools/check` runs `tools/check-bumps`. The release key's subkey is in the Actions secret `PYRE_SIGNING_SUBKEY` (`docs/reference/release-key.md`).
- **Install images** are not published yet. CI needs a privileged container for mkarchiso, and the ISO is over GitHub's 2 GiB per-asset limit. They unlock the landing page's "Install" pill (P7, or earlier if wanted).
- **Brand assets:** `docs/images/` (wordmark, preview, avatar; `tools/render-avatar`), the landing page at <https://bayrock.github.io/pyre-os/>. Themes and wallpapers come from `tools/theme-palettes` and `tools/render-wallpaper`.
- **VM tests:** `tools/test-e2e`, `test-machine`, `test-nvidia`, `test-iso`, `test-upgrade`, `test-channel`, `test-theme`, `test-splash`, `test-visual` (each prints its usage with `--help`). Boot surfaces are captured only without GL (`--display none`); niri skips software renderers, so desktop captures need GL and come from niri's own screenshots.
- **The overlay** is the author's own repository, outside this one and never part of the distribution. It holds personal settings only (ADR 0005, `docs/reference/dev-machine.md`).

## Dev loop reference

- **Full e2e:** `tools/test-e2e` (about 15 minutes), `tools/test-machine` (about 8), `tools/test-nvidia` (about 12: DKMS builds the driver for both kernels), and `tools/test-iso` (about 2 minutes).
- **Resume:** `--from STAGE` reuses the disk a previous run left in `build/vm/<tool>/`.
- **No ISO rebuild:** `tools/build-pkgs`, then `--local-packages` on `test-e2e`, `test-machine` or `test-nvidia`. The newest packages in `build/repo` replace the ISO's own in the live medium's offline repository and its installer, so the install is still offline.
- **By hand:** `tools/run-vm` and `tools/vm-ctl` (`docs/BUILDING.md`). A guest reaches files in `build/vm/<name>/share/` with `mount -t 9p -o trans=virtio pyre-share /mnt`.
- **ISO rebuilds** need the user to run `sudo tools/build-iso`. A first vendored-package build needs `tools/build-pkgs` in a terminal, for the chroot sudo. Batch requests for both.

## Boundaries

- Project root: the checkout. Remote: `origin` → `https://github.com/bayrock/pyre-os.git`, branch `main`. CI must stay green; the user can check the Actions tab, because `gh` is not installed.
- Host rules are in `AGENTS.md` under "Host safety". Dev tools and VMs are fine. Never touch desktop config, boot setup or disks. Installs happen only to qcow2 disks under `build/vm/`. New host packages need the user's approval.
