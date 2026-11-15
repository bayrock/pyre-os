# Status

Last updated: 2026-11-15

## Current phase

**P6, daily driver on the development machine (active).** Everything about the machine that needs no real hardware is built and passes in VMs. The ISO is one rebuild behind the packages (below), so the order is: rebuild the ISO, run the four ISO tests, then the owner's backups and install (`docs/reference/migration.md`).

| Step | State | Evidence |
|---|---|---|
| Migration plan | Written; the owner reviews and runs it | `docs/reference/migration.md` |
| Interactive installer (gum) | Done | `tools/test-machine`, install stage: every prompt typed at the keyboard |
| Hibernation (ADR 0017) | Done in the VM | swapfile in `@swap`, resume arguments, hibernate, power off, resume into the same boot and niri |
| Windows boot entry (ADR 0017) | Done in the VM | the entry below PyreOS, kept across a transaction, chainloads the other disk's boot manager; that disk's checksum never changes |
| Three outputs, one portrait | Done in the VM | positions and a 270° transform from the user's `config.kdl`, a bar on each, an 800x1280 screenshot |
| Suspend | Done in the VM | suspend, wake, locked, unlock, outputs back |
| Autologin keyring (ADR 0018) | Done in the VM | no dialog, `secret-tool` round trip, power-off in seconds |
| NVIDIA install path | Done in the VM, without the GPU | `tools/test-nvidia`: the rule's packages from the offline repository, DKMS for both kernels in the installer's chroot, the modules in both initramfs images, a normal boot |
| `pyre hw` on the real GPU | Detection only | read-only on the machine: the RTX 3060 Ti matches `10-nvidia-open` |
| An ISO with the new packages | **Behind: rebuild before the install.** `pyreos-2026.11.14-x86_64.iso` (sha256 `0ff3ef15…64064568`) passed the four VM tests below, but carries `pyre-cli` 0.3.1 and `pyre-desktop` 0.3.2: the old keymap and default apps, no menu | `tools/build-pkgs && sudo tools/build-iso` (the owner), then the four tests |
| Agent skill (ADR 0019) | Done in the VM | `tools/test-e2e`, first boot: `pyre` linked into `~/.claude/skills` and `~/.agents/skills` at the first login |
| Night light | Done in the VM, without the tint | `tools/test-e2e`, desktop: off by default, the 20:00 to 07:00 schedule, `Mod+Ctrl+N` and the schedule in Noctalia's log. QEMU's display has no gamma table, so the tint waits for the machine |
| Keymap, key list and PyreOS menu (ADR 0021) | Done in the VM | `tools/test-e2e`, desktop: the config validates; `Mod+K` lists 125 keys and `Mod+Alt+Space` the menu, in the launcher; a row chosen there and one found by the ordinary search both act; `Mod+Escape`, `Mod+Ctrl+L`, `Mod+W`, `Mod+Shift+2` and `Mod+Tab`; no recorder by default and a notice that says where it is, then the recorder installed through the menu's own code path and a recording made |
| Remind me (ADR 0020) | Done in the VM | `tools/test-remind`: `/remind 3h …` and plain "remind me …" in the launcher, `pyre remind` in a terminal, a reminder that fires and stays, one cancelled from the launcher, and one that came due while the machine was off, shown at the next login |
| The author's overlay | Scaffolded, untested on the machine | a local repository outside this one (`../pyre-overlay`): outputs, keys, foot, mpv, package lists |
| Real hardware: driver under niri, 240 Hz and VRR, sleep, Bluetooth, audio, peripherals | Waits for the install | `tools/hw-report` collects it in one run |
| Migration, then a week of daily use | Waits for the owner | the exit criterion |

**P6 runs** (2026-11-14, on the rebuilt ISO itself, with `pyre-installer` 0.4.0, `pyre-cli` 0.3.1, `pyre-desktop` 0.3.2 and `pyre-base` 0.5.1; the same tests had passed before the rebuild with `--local-packages`):

- **`tools/build-iso`** ended with `tools/verify-iso`: the root image matches its recorded checksum, and the offline repository in the image is file for file what was staged.
- **`tools/test-iso`:** passed on UEFI and BIOS.
- **`tools/test-e2e`:** every stage, 94 checks in 9 min 25 s.
- **`tools/test-machine`:** all four stages, 74 checks in 7 min 41 s. The interactive installer, typed at the keyboard, onto a disk that held an MBR table, FAT and LUKS, next to a stand-in Windows disk; then every row marked "Done in the VM" above. The desktop powered off in 4 s.
- **`tools/test-nvidia`:** both stages, 20 checks in 13 min 13 s. The installer applied the NVIDIA rule with no failed hook and no snapshots; DKMS built `nvidia-open` 620.70.06 for both kernels; each initramfs holds the four modules; the system boots and unlocks; a second apply changes nothing, and an apply without the GPU removes the drop-ins.
- **After that ISO** (2026-11-14, `--local-packages`, with `pyre-cli` 0.5.0 and `pyre-desktop` 0.5.0: the keymap, key list and menu, on top of the agent skill, night light and reminders): `tools/test-e2e` passed every stage from a fresh install, 124 checks. On overlays of that install, `tools/test-remind` passed 45 checks, `tools/test-theme` 83 and `tools/test-visual` 38, with the welcome panel, its guide and every theme captured. `test-machine` and `test-nvidia` have not run with these packages; they run on the rebuilt ISO.
- **CI** is green on `main` (check, packages and publish), and the testing channel carries `pyre-cli` 0.5.0 and `pyre-desktop` 0.5.0 since 2026-11-15.
- **`tools/check`:** passes, with new bats tests for the swapfile and resume arguments, ESP detection, the autologin keyring, the resume-offset check, `HW_SYS`, and the boot-branding hook before Limine exists.

**Found on the way:**

- **The machine boots in legacy BIOS mode today** (MBR disk, no EFI variables); Windows on the other disk is UEFI. PyreOS installs on UEFI only, so the USB must be started through its "UEFI:" entry. `pyre-install` refuses a BIOS boot before asking anything.
- **`FIND_BOOTLOADERS` never finds Windows on another disk:** `limine-install` only looks on its own ESP, where the one loader it found was Limine's own fallback copy (the "EFI fallback" menu entry, now gone). The installer adds the Windows entry itself.
- **Autologin put a keyring dialog on the desktop:** Noctalia asks the secret service at start. While the dialog was open a shutdown took 92 s, because Noctalia did not stop; with the passwordless default keyring it takes 2 s.
- **QEMU's TCO watchdog reset every resumed guest** a few seconds after a successful resume: the kernel that boots only to resume never loads the watchdog driver. `tools/run-vm` straps the watchdog to not reboot. Real firmware arms no such timer.
- **The hibernate stage runs without GL.** After a hibernation QEMU is a new process, and a GL guest's host-side resources go with the old one; hibernating a GL guest was not tried. Suspend keeps the process, and runs with GL.
- **NVIDIA sleep needs no setup:** with `nvidia-open` 595 and later, `nvidia-utils` disables its own suspend services (ADR 0017).
- **On an 800 px wide output the default bar's clock and media widget overlap.** The machine's portrait screen is 1080 px wide; check it there.
- **Two defects the NVIDIA install showed,** both fixed: the driver transaction ran after snap-pac without `SNAP_PAC_SKIP`, so such an install began with a snapshot pair; and `pyre-base`'s boot-branding hook failed during every install, because it ran before `/etc/default/limine` existed (`pyre-base` 0.5.1).
- **One ISO build produced a damaged image** (2026-11-14): one bit of one offline package differed from the cached file, which itself still verifies. The squashfs matched its recorded checksum and the ISO on disk matched its cached copy, so the bit flipped while the image was being built; the host logged no machine-check or filesystem error. pacman's signature check stopped the install at that package. `tools/build-iso` now ends with `tools/verify-iso` and removes an image that fails. If it happens again, test the development machine's memory.
- **A build without enough disk space** failed in xorriso after removing the previous ISO of the same date; `tools/build-iso` now needs 12 GiB free before it starts.
- **Three VM tests at once ran the development machine out of memory** (2026-11-14): three sessions in three worktrees each started an install test, and `systemd-oomd` ended the editor and every session in it. Every VM test and `tools/run-vm` now takes one lock for the whole machine (`tools/lib/vmlock.sh`), so a second job waits or is refused.
- **QEMU's keyboard cannot press Alt+Print.** A guest sees Alt go down and up and never the Print key (read from the guest's event device, 2026-11-14): the kernel's SysRq handling takes the key, and what it re-injects does not arrive. Ctrl+Print and Shift+Print arrive. `tools/test-e2e` therefore runs `pyre-record` itself, and the key is on the hardware list; the desktop this machine runs today binds the same key for recordings.
- **An offline install has package lists**, the ISO's own, so the PyreOS menu can install at once on a fresh machine with a network. Once they are old, pacman fails to fetch and the menu says to update first.
- **A `[pyre]` database newer than the channel's breaks a plain `pacman -Sy`** after the server changes: pacman keeps the newer file and fetches only the channel's signature, which does not match ("invalid or corrupted database"). It happens in tests that switch a guest from the local repository to the channel right after a local build, never on a real install. `test-visual`, `test-theme` and `test-splash` now force the refresh.
- **`tools/test-visual` captured a bare desktop as "the welcome panel"** when its base disk had been logged into before. It now makes the login a first one and checks that the panel is open.
- **The serial log sometimes shows a character of the guest's output twice** (its input arrived intact in 150 long commands). When it hit a probe's end marker the probe never finished. Markers now match with any character doubled (`tools/lib/vmtest.sh`).

**Carried over** (later phases unless reprioritized):

- **Website (P5, started early):** the landing page lives in `landing/`, and the `pages` workflow publishes it to <https://bayrock.github.io/pyre-os/>. It went live on 2026-11-13 and serves `landing/site/` byte for byte. It was checked locally at 360, 768 and 1280 px in headless Chromium.
- **Untested paths:** real hardware (only QEMU with OVMF), including Bluetooth adapters; installing next to another system on the same disk (out of scope, ADR 0008).
- **Not built yet:** bundles in the installer.
- **Repository:** the `testing` channel is live (below). There is no `stable` channel or promotion script yet (P7), and installs from ISOs built before `pyre-release` 0.3.0 have no `[pyre]` server.
- **Sizes:** the ESP is 2 GiB, while limine-snapper-sync recommends 4 GiB (entries are pruned at 85% usage). With the NVIDIA modules each initramfs is 102 MB, and a fresh install uses 320 MiB of the ESP (16%). The ISO is now 3.0 GB, 1.4 GB of it the offline repo.
- **limine-snapper-sync 1.32.1 rough edges** (worth reporting upstream): each prompt wraps stdin in a new buffered reader and spins on EOF; it calls `stty` on `/dev/tty`, so it stops outside the foreground process group; it writes the backup's `info.xml` without fsync, so a power cut right after a restore leaves an orphaned backup.
- **From P3:** users created after install get bash's own `.bashrc` (P4 user reconcile, ADR 0013). Turning autologin on after the install does not create the passwordless keyring (ADR 0018).
- **From P4:** the `-gaming` and `-lazyvim` bundles are deferred. `[pyre]` is hosted on the `testing` channel since 2026-11-13.

## Accepted phases

**P5: Polish and identity** was accepted on 2026-11-14, by the user after reviewing the `tools/test-visual` captures.

- **Exit run** (ISO `pyreos-2026.11.14-x86_64.iso`, sha256 `e0a8f165…2eb8072a4`): `tools/test-visual` passed, one boot captured from the Limine menu through the splash, the login screen, the welcome panel and its guide, and the desktop in every theme, to a lock and unlock. `tools/test-theme` passed: live recolor of open foot and GTK windows in all four themes, and the welcome panel's theme buttons. `tools/test-iso` passed on UEFI and BIOS, and `tools/test-e2e` passed 93 checks.
- **Accepted limit:** the lock screen itself is not captured, because niri does not screenshot it (as in P3). The lock is shown by Noctalia's state and logind's LockedHint.
- **Built:** ADRs 0015 (themes are Noctalia palettes) and 0016 (the welcome panel). Four original themes: Ember, Birch, Evergreen and Frost (`pyre-themes` 0.3.0). The Limine menu, the Plymouth splash, the ISO's BIOS menu and the login screen in Ember (`pyre-base` 0.5.0, `pyre-cli` 0.3.0). The welcome panel, the user guide, the `pyreos` icon and the fastfetch flame (`pyre-desktop` 0.3.1). Brand assets in `docs/images/`. Details are under "Theme system" below.

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
- **Testing channel** (2026-11-13): the `publish` job in `check.yml` runs `tools/publish-testing` on every push to `main`, into the GitHub Release `testing` (`Server = https://github.com/bayrock/pyre-os/releases/download/testing`). The first run published 11 packages. A sandboxed pacman trusting only `pyre-keyring` 0.2.0 synced and verified all of them, and a client trusting only the dev key was refused. `tools/test-channel` (VM) result: see below.
- **Theme system (P5, 2026-11-13, ADR 0015):**
  - `pyre-themes` 0.1.0 ships Ember (`themes/ember/`). It comes from the landing page's colors and passes `tools/check-themes` (WCAG contrast for text and ANSI colors).
  - `pyre-cli` 0.2.0 adds `pyre theme` and the reconcile unit `002-theme-palettes`.
  - `pyre-desktop` 0.2.0 selects Ember in Noctalia and enables Noctalia's niri, foot, GTK 3/4 and btop templates. It adds `adw-gtk-theme`, plus user stubs that already include the generated files.
  - `tools/test-theme` passed on an overlay of the e2e disk, which tests the upgrade path for an existing user:
    - after login, `pyre theme set ember` gives `custom Ember`
    - niri, foot, GTK and btop files carry Ember, and the niri and foot configs validate
    - a live switch to Noctalia's palette recolors the shell and the niri focus ring, and `pyre theme set` brings Ember back
  - **Wallpaper** (`pyre-themes` 0.2.0): Ember's wallpaper is the landing page's cabin at night, rendered by `tools/render-wallpaper` (3840×2160 JPEG with a light grain against banding, 1.2 MB). It is Noctalia's default wallpaper, and `pyre theme set` sets it.
  - **Live recolor** (`pyre-cli` and `pyre-desktop` 0.2.1): Noctalia's `pyre-live` template runs `pyre theme refresh` on every palette change. Open foot terminals get OSC color sequences, and open GTK windows get a color-scheme nudge.
  - `tools/test-theme` checks with screen pixels that an open foot and an open nautilus recolor on a live switch and back. The user unit `003-theme-state` migrates 0.2.0's theme record file.
  - **Limine boot menu** (`pyre-base` 0.4.0): "PyreOS" in gold, Ember's colors, and the wallpaper. `pyre-boot-branding` keeps a marked block at the top of `limine.conf`, applied by a pacman hook and by `pyre-install`. `tools/test-theme` checks that the block survives `limine-update` and that the menu shows the wallpaper. Limine 12 takes `RRGGBB` values for `interface_*_colour`, not v11's palette indexes.
  - **Boot splash** (`pyre-base` 0.5.0, `pyre-installer` 0.3.2): an original Plymouth script theme. It shows the mark on Ember's sky, a three-ember loader, and the unlock prompt.
    - `pyre-install` adds the `plymouth` hook and `quiet splash`. Existing installs opt in by hand.
    - `tools/test-splash` checks it on an overlay of the e2e disk: the mark, four bullets for four keys, and an unlock through the splash.
    - The test runs without GL (`--display none`), because QEMU has no capturable surface at the boot console with GL, and with `plymouth.ignore-serial-consoles`, because Plymouth falls back to text mode when a serial console is configured.
    - The shared VM unlock step also accepts the passphrase request itself, which `quiet` keeps on the serial console.
  - **Login screen** (`pyre-cli` 0.2.2): the system unit `002-greeter-appearance` seeds Ember into the greeter's `sync.toml` until someone syncs, and creates `greeter.toml` with `hide_logo = true` when missing. Checked in the VM on the software-rendered greeter (`--display none`): the cabin wallpaper, a warm card, the orange accent, and no Noctalia logo. `tools/test-theme` and `tools/test-e2e` check the seeded files.
  - Learned along the way: the serial log sometimes doubles a character of the guest's output, so long files are read through the 9p share instead.
  - **ISO BIOS menu:** `iso/syslinux/splash.png` is now the cabin at night (`tools/render-wallpaper`, 640×480), and the menu uses Ember's colors. `tools/test-iso` captures both firmwares' menus and fails a BIOS menu that isn't the Ember splash. It fails on the ISO built on 2026-11-13, which shows releng's Arch logo, until the next rebuild.
  - **Alternative themes** (`pyre-themes` 0.3.0, 2026-11-14): Birch (light), Evergreen and Frost, all original, each the Ember cabin at another hour or season. `tools/theme-palettes` generates every palette (it replaces `tools/ember-palette`, and Ember's own colors are byte-identical), and `tools/render-wallpaper` renders every wallpaper plus a 1640×400 banner. Ember carries Birch as its light variant, and the reverse. `check-themes` exempts white rather than black from the ANSI contrast check on light variants.
  - **Welcome panel** (ADR 0016, `pyre-desktop` 0.3.0, `pyre-cli` 0.3.0): the Noctalia plugin `pyre/welcome`, "Welcome home.", with the theme buttons, the main keys, updates, `pyre doctor`, the settings and the guide. `pyre welcome` opens it, and niri runs `pyre welcome --first-login` once.
  - **User guide** (`docs/guide/`, installed to `/usr/share/doc/pyre/guide/`): first steps, keys (`docs/KEYBINDINGS.md`), themes, updates and snapshots, software, troubleshooting. The panel renders it.
  - `tools/test-theme` passed on 2026-11-14 with both added: the panel opens by itself at the first login, shows the guide, and its Birch button switches the theme. Then every theme sets its wallpaper and GTK mode, and recolors an open foot and nautilus (screen pixels). Two layout bugs found in the VM were fixed: the footer was clipped, and the guide's scroll area had no height.
  - **Exit review** (`tools/test-visual`, passed 2026-11-14): one boot of an overlay of the e2e disk with the new packages and the Plymouth boot step, captured in order: the Limine menu, the splash's unlock prompt and progress, the login screen, the welcome panel and its guide at the first login, the desktop (foot running fastfetch, and nautilus) in Ember, Birch, Evergreen and Frost, and the control center. Then it locks with Super+Alt+L (checked through Noctalia's state and logind's LockedHint) and unlocks with the password. The boot surfaces are QEMU captures without GL; niri skips software renderers, so the desktop runs with GL and is captured by niri. The lock screen is the one surface not captured (niri does not capture it, the limit accepted in P3). Waiting for the user's sign-off.
  - Fixed after the review: fastfetch showed the Arch logo, since it does not know `ID=pyreos`. `pyre-desktop` 0.3.1 ships `/etc/xdg/fastfetch/config.jsonc`, a system-wide default (a user's own config wins), with the flame mark in ASCII in the mark's gradient, and `tools/test-visual` checks it. The test's launcher capture used a wrong key name, and its captures now run with do-not-disturb, so niri's screenshot toasts stay out.
  - **On the ISO built on 2026-11-14** (`pyreos-2026.11.14-x86_64.iso`, sha256 `e0a8f165…2eb8072a4`): `tools/test-iso` passed on UEFI and BIOS, with the BIOS menu now the Ember cabin splash. `tools/test-e2e` passed all stages, 93 checks, from a fresh install: Ember on the login screen, the welcome panel at the first login, Ember in Noctalia, niri and foot, and the stubs untouched.
  - **Brand assets** (`docs/images/`): the README's wordmark (light and dark, linked to the landing page), the P5 preview image, and the avatar (`tools/render-avatar`): the flame on Ember's night sky, for the GitHub organization and project thumbnails.
- **e2e on the rebuilt ISO (2026-11-13):** `tools/test-e2e` passed every stage, including the new `pacman-unlocked` check after rollback.
- **Fixed on the way:** a restored snap-pac "pre" snapshot carries `/var/lib/pacman/db.lck`, so pacman stayed locked after `pyre rollback`. `pyre-base` 0.3.1 clears it at boot with a tmpfiles rule.
- **Release key** (2026-11-13, `docs/reference/release-key.md`): primary `65D123DD9A18A346A94C38E6228693F6D58F0A7F`, certify-only, kept offline. Signing subkey `279066B8C9E6FD17B3B9189C588DC5476F4A31E4`, expiring 2028-11-12, held in the Actions secret `PYRE_SIGNING_SUBKEY`. `pyre-keyring` 0.2.0 trusts it alongside the dev key.
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
- **Night light, read from Noctalia 5.5.0 on 2026-11-14** (`docs/user/services/night-light.mdx`, `docs/user/services/location.mdx` and `src/system/gamma_service.cpp` at tag `v5.5.0`):
  - Noctalia sets the color temperature itself through `wlr-gamma-control`, which niri implements, so no separate gamma daemon is needed.
  - `[nightlight] enabled` follows the `[location]` schedule, and `force` holds the night temperature at once (4000 K against 6500 K by default). The schedule fades over an hour around each boundary; everything else applies at once.
  - An enabled night light with no coordinates and no custom schedule does nothing but log a warning. A custom schedule (`custom_schedule`, `sunset`, `sunrise`) needs no location and overrides coordinates.
  - `nightlight-toggle`, `nightlight-force-toggle`, the control center's button and the bar widget change the running shell only, and a new login starts from the saved settings. The settings window writes the saved value.
  - `noctalia msg status` does not report night light; the shell logs `[gamma] target <N>K (day=… night=… force=…)` when the temperature it asks for changes. Noctalia logs to `~/.cache/noctalia/noctalia.log`, not to the journal.
  - QEMU's virtio display has no gamma table: niri reports "setting gamma is not supported" and Noctalia logs "gamma control failed for an output". A VM proves the key, the defaults and the schedule, never the tint.

## Open questions

Each question is listed under the phase that resolves it.

- **P7:** whether the "PyreOS" trademark and domains are available.
