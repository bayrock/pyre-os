# Building and testing

PyreOS builds and boot-tests on any Arch-based machine with KVM, including the development host. All generated output goes under the repository's ignored `build/` directory:

| Path | Contents |
|---|---|
| `build/out/` | ISO images |
| `build/work/` | mkarchiso work directory |
| `build/vm/<name>/` | Disposable VM disks, UEFI variables, serial logs, control sockets |
| `build/repo/` | Local package repository *(P1)* |
| `build/chroot/` | devtools clean chroot for vendored packages, owned by root. Remove it with `sudo rm -rf build/chroot`. |
| `build/pkgsrc/`, `build/pkgbuild/` | Downloaded sources and makepkg build directories |

## One-time setup

Install the approved development tools. This needs your password:

```sh
sudo pacman -S --needed archiso qemu-desktop edk2-ovmf shellcheck bats devtools
```

These tools only add packages. They do not change desktop configuration, services, or boot setup. KVM requires that `/dev/kvm` is readable and writable by your user.

## Checks

```sh
tools/check   # everything offline: shellcheck, Python syntax, iso/ profile, bats, markdown links, whitespace
```

Run it before every commit. `tools/check-profile` runs as part of it and can also be run on its own.

## Build packages

```sh
tools/dev-key      # once: development signing key in build/keys/; assembles packages/pyre-keyring/ from it and release.asc
tools/build-pkgs   # every packages/*/PKGBUILD -> build/repo/ (the local [pyre] repo); run as your user
```

`tools/build-pkgs name …` rebuilds only the named packages.

- **PyreOS packages** have no `makedepends`. They are rebuilt on every run with `makepkg --nodeps`.
- **Vendored packages** have `makedepends`, for example the GraalVM-built Limine tools. They build in a devtools clean chroot at `build/chroot/`, which asks for your sudo password, so run the first build in a terminal.
  - The build downloads about 330 MB of sources into `build/pkgsrc/` and needs network access for Gradle.
  - A built version is reused until its `pkgver`/`pkgrel` changes. Pass `--rebuild` to force a rebuild.
- CI passes `--syncdeps` instead, which installs the `makedepends` into its throwaway container.
- **Signing.** When the development key is in `build/keys/gnupg/`, every package and the repository database are signed with it (ADR 0014). `pyre-keyring` trusts that key, and installed systems require signed `[pyre]` packages. Without the key, CI included, packages are unsigned.

## Build the ISO

```sh
tools/build-pkgs && sudo tools/build-iso
```

The ISO installs `pyre-base` and `pyre-installer` from `build/repo/`, so build packages first.

Every build starts from scratch:

1. The wrapper runs `tools/check-profile` and removes a leftover `build/work`, refusing if anything is still mounted under it.
2. It copies `iso/` to `build/profile/` and adds the **offline repository**: the dependency closure of `iso/offline.x86_64`, downloaded into `build/offline/cache/` and placed at `/opt/pyre-offline` in the image, together with the `core.db`, `extra.db` and `pyre.db` it was resolved against.
3. Arch packages come from one explicit mirror, `PYRE_MIRROR` (default `https://geo.mirror.pkgbuild.com/$repo/os/$arch`), never the host's mirrorlist. So the live system and the offline repository match.
4. It runs `mkarchiso -r` on the staged profile, so the work directory is deleted after a successful build.

Output stays inside `build/`:

- The ISO goes to `build/out/`, owned by the invoking user.
- The full mkarchiso log goes to `build/logs/build-iso-<time>.log`. The terminal shows only a summary, or the last 40 log lines on failure. Pass `--verbose` to stream the whole log.

mkarchiso downloads packages through the host's pacman cache. A releng build needs about 10 GB of free space while it runs.

## Boot-test in a VM

```sh
tools/test-iso     # scripted: UEFI + BIOS headless boot, serial login, os-release and keyring probe
tools/test-e2e     # the P2 and P3 scenarios: offline install, unlock, desktop checklist,
                   # snapshot pair, snapshot boot, rollback
tools/test-upgrade # the P4 scenario: N-1 -> N upgrade with pyre update, then a broken
                   # update rolled back to a working desktop
```

`tools/test-upgrade` builds releases N and N+1 under `build/upgrade/`: every PyreOS package gets `pkgrel` raised and a canary reconcile unit per scope, and N+1 also breaks the greeter. It serves them on `127.0.0.1:8080`, where the guest's `[pyre]` points. Its stages share `tools/lib/vmtest.sh` with `test-e2e`.

`tools/test-e2e` runs on a fresh `build/vm/test-e2e/` disk, with the GL `headless` display. Its stages:

1. **install:** no network device; the offline repository only.
2. **first-boot:** checks the installed system.
3. **desktop:** boots with a network and two monitors, logs in through the greeter, and walks the P3 daily-interaction checklist.
4. **snapshot-boot** and **rollback.**

Evidence:

- one serial log per stage (`serial-<stage>.log`)
- the desktop screenshots (`share/desktop-*.png`)
- on a failure, a QMP screendump (`fail-<stage>.png`; it fails while a GL scanout is up)

The test credentials are fixed and not secret.

**Why the desktop screenshots come from niri.** niri refuses software rendering, so the desktop needs virgl. QEMU 11 cannot `screendump` a virgl scanout ("no surface"), so the harness takes niri screenshots in the guest and copies them out through the 9p share. niri does not screenshot the lock screen, so the lock checks use Noctalia's and logind's lock state instead.

For manual work:

```sh
tools/run-vm build/out/pyreos-*.iso                         # UEFI, GL window, 40G disposable disk
tools/run-vm --bios build/out/pyreos-*.iso                  # legacy BIOS path
tools/run-vm --no-disk --display none build/out/pyreos-*.iso  # headless live boot, no GL
tools/run-vm --display headless --outputs 2 --boot-disk     # GL with no window, two monitors
tools/run-vm --boot-disk                                    # boot the installed disk
tools/run-vm --no-net ...                                   # no network device (offline installs)
tools/run-vm --fresh ...                                    # wipe this VM's disk and UEFI vars first
```

While a VM runs, control it from another terminal:

```sh
tools/vm-ctl status
tools/vm-ctl screendump build/vm/pyreos-dev/screen.png
tools/vm-ctl type 'uname -a\n'          # keyboard, through QMP sendkey
tools/vm-ctl serial $'uname -a\n'       # serial console input, sent verbatim
tools/vm-ctl sendkey ctrl-alt-f2
tools/vm-ctl click 640 400              # virtio tablet; --size is the whole output layout
tools/vm-ctl quit
```

The serial console (ttyS0) is logged to `build/vm/<name>/serial.log` and takes input on `serial.sock`. The stock Arch ISO prints only bootloader output there, because its kernel command line has no serial console. The PyreOS profile adds one in P1.

**Headless GL.** `--display headless` runs QEMU's D-Bus display with GL on a private session bus. `run-vm` gives each head a size through `SetUIInfo`, so all `--outputs` monitors connect. Neither `egl-headless` nor SDL's offscreen driver connects more than the first head. QEMU allows only one GL virtio GPU, and niri rejects software-rendered display-only GPUs.

**Share.** Each VM has a 9p share at `build/vm/<name>/share/`. Mount it in the guest with `mount -t 9p -o trans=virtio pyre-share /mnt`.

Use `--name` to keep several VMs side by side, for example `--name upgrade-test`.

## CI

CI arrives in P1. It runs the same scripts: shellcheck and bats, package builds in clean chroots, and an ISO build in a privileged Arch container.
