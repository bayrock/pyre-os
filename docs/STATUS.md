# Status

Last updated: 2026-11-13

## Current phase

**Between P4 and P5.** P4 was accepted on 2026-11-13. Next: the hosted testing channel (CI publishing with a release signing subkey), then P5, polish and identity.

**Carried over** (later phases unless reprioritized):

- **Website (P5, started early):** the landing page lives in `landing/`, and the `pages` workflow publishes it to <https://bayrock.github.io/pyre-os/>. It went live on 2026-11-13 and serves `landing/site/` byte for byte. It was checked locally at 360, 768 and 1280 px in headless Chromium.
- **Untested paths:** the interactive gum TUI (only `--config` has run), and real hardware (only QEMU with OVMF), including Bluetooth adapters (P6).
- **Not built yet:** the hibernation swapfile option; Windows chainload detection (`FIND_BOOTLOADERS=yes` untested); Plymouth theming (P5); `pyre hw apply` and `pyre reconcile --system` (P4).
- **Repository:** the installed system has no `[pyre]` repository, so PyreOS packages do not update after install until P4 hosting, and `[pyre]` packages are unsigned until P4.
- **Sizes:** the ESP is 2 GiB, while limine-snapper-sync recommends 4 GiB (entries are pruned at 85% usage). The ISO is now 3.0 GB, 1.4 GB of it the offline repo.
- **limine-snapper-sync 1.32.1 rough edges** (worth reporting upstream): each prompt wraps stdin in a new buffered reader and spins on EOF; it calls `stty` on `/dev/tty`, so it stops outside the foreground process group; it writes the backup's `info.xml` without fsync, so a power cut right after a restore leaves an orphaned backup.
- **From P3:** users created after install get bash's own `.bashrc` (P4 user reconcile, ADR 0013); with autologin the keyring stays locked until first use.
- **From P4:** `pyre hw` has run only against a simulated sysfs, so real GPUs wait for P6. The `-gaming` and `-lazyvim` bundles are deferred. `[pyre]` is not hosted yet: CI publishing needs a release signing subkey from the user.

## Accepted phases

**P4: Lifecycle** was accepted on 2026-11-13.

- **Exit run** (ISO `pyreos-2026.11.13-x86_64.iso`, sha256 `28851945…3d34a813`):
  - **`tools/test-upgrade`:** 50 checks in 10 min 18 s. An offline install (release N-1) updated to N with `pyre update`: both canary reconcile units ran, home and snap-pac snapshots were taken, the second reconcile was a no-op, `doctor` was clean, and the desktop came back. A deliberately broken N+1 lost its greeter; the pre-update snapshot booted from Limine, `pyre rollback` restored it, and a normal boot reached the desktop at N.
  - **`tools/test-e2e`:** 84 checks in 9 min 17 s. **`tools/test-iso`:** passed on UEFI and BIOS.
  - **Unit tests:** every reconcile unit has a bats test that runs it twice. CI is green.
- **Built:**
  - ADR 0014
  - `pyre-cli` 0.1.0: `update`, `snapshot`, `rollback`, `doctor`, `reconcile`, `hw`, `install`/`remove`; the ALPM hook and the login service
  - hardware rules for NVIDIA, AMD and Intel
  - the bundles `-dev`, `-media` and `-office`
  - `pyre-installer` 0.3.0, with `[pyre]` and the restored `pacman.conf`
  - dev-key signing in `build-pkgs`
  - `tools/test-upgrade` and `tools/lib/vmtest.sh`
- **Found by the tests:**
  - offline installs kept the ISO's `pacman.conf`, so they could never update
  - the live `[pyre]` section leaked into the target
  - `pyre rollback` missed overlay snapshot boots
  - the ISO build reused stale cached packages
  - CI lacked `diffutils`

**P3: Desktop core** was accepted on 2026-11-10. The user signed off on the two limits of the VM evidence.

- **Exit run** (ISO `pyreos-2026.11.10-x86_64.iso`, sha256 `643d1f50…6d9edce`, offline repository of 607 packages): `tools/test-e2e` passed 73 checks in 8 min 23 s from a fresh disk. The desktop stage ran on two monitors and covered login through noctalia-greeter, config layering, the keymap, notifications, clipboard history, screenshots, lock, unlock and idle lock, a portal screen-cast recording, a bar per output, audio with OSD, network, power profiles and the control center, with eight niri screenshots. `tools/test-iso` passed on UEFI and BIOS.
- **Accepted limits:** Bluetooth without an adapter (service and controls only; adapters in P6), and the lock screen shown by Noctalia and logind state rather than a picture (niri does not screenshot it; QEMU 11 cannot screendump virgl scanouts).
- **Built:** ADR 0013; `pyre-desktop` 0.1.0 (stack, apps, `defaults/`, `skel/`, `pyre-record`, the greeter PAM service); `pyre-installer` 0.2.0; `docs/KEYBINDINGS.md`; `run-vm --display headless --outputs N`, serial input, the 9p share and `vm-ctl click`; the `test-e2e` desktop stage.

**P2: Installer and base system** was accepted on 2026-11-08, when the user directed the start of P3.

- **Exit run** (ISO `pyreos-2026.11.08-x86_64.iso`, sha256 `0747c20d…a49d92759`): `tools/test-e2e`, headless UEFI with no network device, from a fresh 40 GB disk, passed all 29 checks in 6 min 22 s: offline `pyre-install --config`; LUKS unlock and login; layout, snapper, initramfs, zram, firewalld and no-secrets-in-logs checks; a snap-pac pre/post pair with Limine entries; booting that snapshot from Limine; `limine-snapper-sync --restore` and a normal boot into the restored `@`.
- **Accepted substitution:** the transaction is `pacman -U` (a reinstall from the package cache) rather than `pacman -Syu`, because the run is offline. Both go through the same ALPM hooks.
- `tools/test-iso` on the same ISO passed under UEFI (37 s) and BIOS (34 s).
- **Built:** ADRs 0011 (archinstall owns disks, `pyre-install` the boot stack) and 0012 (firewalld); `pyre-installer` 0.1.3, `pyre-base` 0.2.0, and the vendored `limine-mkinitcpio-hook` and `limine-snapper-sync`; `tools/build-pkgs` (devtools chroot), `tools/build-iso` (offline repo of 282 signed packages), `tools/run-vm --no-net`, and `tools/test-e2e`.

**P1: Build pipeline** was accepted on 2026-11-08.

- **Licenses**: `LICENSE` (MIT) and `LICENSE-ARTWORK` (CC BY-SA 4.0).
- **ISO profile**:
  - `iso/` is archiso `releng` v91, copied from the installed `archiso` 91-1 package.
  - Every boot entry carries the serial console through `kernel_params_x86_64`.
  - The full delta is listed in `iso/UPSTREAM.md`.
- **Packages:**
  - `pyre-release` (ADR 0010: an ALPM hook links `/etc/os-release` to `/usr/lib/pyre/os-release`)
  - `pyre-keyring` (development key)
  - `pyre-base` (meta-package)
  - `tools/build-pkgs` builds them into `build/repo/`, and the ISO installs `pyre-base` from `[pyre]`, listed after Arch's repositories.
- **Boot evidence:** `tools/test-iso` on the ISO built on 2026-11-07 passed both firmware paths.

  | Check | UEFI | BIOS |
  |---|---|---|
  | Serial login prompt | 37 s | 34 s |
  | `ID=pyreos` and `NAME="PyreOS"` | ✓ | ✓ |
  | `/etc/os-release` → `../usr/lib/pyre/os-release` | ✓ | ✓ |
  | Dev key in the live keyring | ✓ | ✓ |

  The first ISO, built before `[pyre]`, failed the identity checks, which confirms the test can fail.
- **CI:** `.github/workflows/check.yml` runs two jobs in `archlinux:latest`. The `check` job runs `tools/check`, and the `packages` job runs `tools/build-pkgs` and namcap. Both were green on the push of 2026-11-08, as reported by the user from the Actions tab.
- **Development key:** fingerprint `E150852868B407FB17F1149AE59B1D8F2343FD47`, UID "PyreOS Development Key (NOT FOR RELEASE)". The private key exists only in `build/keys/gnupg/` on the development machine.
- **Known gaps:**
  - Local package builds use plain `makepkg --nodeps`, because `devtools` is not installed.
  - `[pyre]` packages are unsigned until P4.
  - The releng guest agents were trimmed in P2 (`iso/UPSTREAM.md` item 6).

**P0: Reset** was accepted on 2026-11-07.

- The project was renamed to PyreOS. The docs and ADRs 0004–0009 were rewritten, and VirtualBox was retired.
- `tools/run-vm` booted the stock Arch 2026.11.01 ISO headless to `root@archiso`:
  - **UEFI:** `vm-ctl type` returned `PYRE-42` and `fw_platform_size=64`.
  - **BIOS:** `/sys/firmware/efi` was absent.
- Not yet exercised: booting from a qcow2 disk (P2) and the GL display modes (P3).

## Verified facts

- The host has `archiso`, `qemu-desktop`, `edk2-ovmf` (4m firmware), `shellcheck`, and `bats`. `/dev/kvm` is readable and writable by the user. Docker is installed, but the user is not in the `docker` group. `devtools` 1:1.5.3 was approved and installed on 2026-11-08.
- `archiso` 91-1 is the newest version in `extra`. Upstream tag `v92` exists but has not been packaged.
- On Arch, `/etc/os-release` belongs to no package. systemd's `tmpfiles.d/etc.conf` creates it as a symlink, and `filesystem` owns `/usr/lib/os-release` (ADR 0010).
- QEMU `sendkey` sent back-to-back drops keys in the guest, so `vm-ctl type` paces keys 30 ms apart.
- Arch sync DB on 2026-11-07:

  | Package | Version |
  |---|---|
  | `niri` | 26.04 |
  | `noctalia` | 5.3.0 |
  | `quickshell` | 0.3.2 |
  | `matugen` | 4.2.0 |
  | `archinstall` | 4.5 |
  | `limine` | 12.9 |
  | `snapper` | 0.13.2 |
  | `snap-pac` | 3.0.1 |
  | `greetd` | 0.10.3 |
  | `xwayland-satellite` | 0.8.3 |

  `limine-snapper-sync` is available only from the AUR and third-party repositories.
- `limine-snapper-sync` 1.32.1 and `limine-mkinitcpio-hook` (`limine-entry-tool` 1.40.0) are GPL-3.0 Java programs compiled with GraalVM `native-image`. The upstream source is gitlab.com/Zesko. Both Limine tools are UEFI only. The archinstall 4.5 findings are in ADR 0011.
- **Desktop stack, read from the `extra` packages and upstream docs on 2026-11-08** (niri 26.04, noctalia 5.4.1, noctalia-greeter 1.7.0, greetd 0.10.3):
  - niri reads `~/.config/niri/config.kdl`, falling back to `/etc/niri/config.kdl`, and writes its own default config to `~/.config` when both are missing. `include` is top-level and positional: later settings override earlier ones, `binds` override per key, and multipart sections such as `window-rule` are inserted in place. `include optional=true` and `~` paths need 26.04. Source: `docs/wiki/Configuration:-Include.md` at tag `v26.04`.
  - Noctalia merges every `*.toml` in `~/.config/noctalia/`, then GUI overrides in `~/.local/state/noctalia/settings.toml`, which win. An `[include] files = [...]` table takes files or directories, merged before the including file's own keys. There is no system-wide config directory. Source: `docs/user/configuration/index.mdx` at `v5.4.1`.
  - Noctalia covers the polkit agent (`[shell] polkit_agent`, off by default), the lock screen (`noctalia msg session lock`, also reached by `loginctl lock-session`), idle behaviours through `ext-idle-notify` (lock and screen-off seeded but disabled by default), clipboard history, notifications and OSDs. Telemetry defaults to off. Recording is an official plugin fetched from git, which PyreOS does not ship.
  - noctalia-greeter runs under greetd as `noctalia-greeter-session` (its own wlroots compositor) as user `greeter`. Its upstream setup rewrites `/etc/greetd/config.toml` by hand. Arch's `system-login` PAM stack already has `pam_systemd`, so its PAM patch is not needed.
  - archinstall 4.5 creates users before it installs the extra `packages`, so `/etc/skel` files from those packages never reach the first user.

## Open questions

Each question is listed under the phase that resolves it.

- **Testing channel:** the release key exists (`docs/reference/release-key.md`). The next step is the user filling the CI secret with `tools/release-key-ci`.
- **P7:** whether the "PyreOS" trademark and domains are available.
