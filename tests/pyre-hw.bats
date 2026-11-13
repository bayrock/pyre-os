#!/usr/bin/env bats
# pyre hw: rule matching from a fake sysfs, and an apply that is a no-op the
# second time.

setup() {
  repo="$BATS_TEST_DIRNAME/.."
  export PYRE_LIB="$repo/src/cli" PYRE_ROOT="$BATS_TEST_TMPDIR/root"
  export HW_RULES="$repo/src/hw/rules" HW_FILES="$repo/src/hw/files" LOG="$BATS_TEST_TMPDIR/log"
  mkdir -p "$PYRE_ROOT/proc" "$BATS_TEST_TMPDIR/bin"
  printf 'vendor_id\t: AuthenticAMD\n' >"$PYRE_ROOT/proc/cpuinfo"
  for tool in pacman limine-update; do
    printf '#!/bin/sh\necho "%s $*" >> "%s"\n[ "$1" = -Q ] && exit 1\nexit 0\n' "$tool" "$LOG" >"$BATS_TEST_TMPDIR/bin/$tool"
    chmod +x "$BATS_TEST_TMPDIR/bin/$tool"
  done
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

# pci SLOT VENDOR DEVICE CLASS: a fake PCI function.
pci() {
  local dev="$PYRE_ROOT/sys/bus/pci/devices/$1"
  mkdir -p "$dev"
  echo "0x$2" >"$dev/vendor"
  echo "0x$3" >"$dev/device"
  echo "0x$4" >"$dev/class"
}

pyre() {
  "$repo/src/cli/pyre" "$@"
}

@test "an RTX 3060 Ti matches the open NVIDIA rule only" {
  pci 0000:00:00.0 1022 1480 060000
  pci 0000:07:00.0 10de 2489 030000
  run pyre hw packages
  [ "$output" = "nvidia-open-dkms nvidia-utils libva-nvidia-driver linux-headers linux-lts-headers" ]
  run pyre hw detect
  [[ "$output" == *"10-nvidia-open"* ]]
  [[ "$output" != *"11-nvidia-legacy"* ]]
}

@test "a pre-Turing NVIDIA GPU gets the legacy note and no packages" {
  pci 0000:01:00.0 10de 1b80 030000
  run pyre hw detect
  [[ "$output" == *"11-nvidia-legacy"* ]]
  [[ "$output" == *"nouveau"* ]]
  run pyre hw packages
  [ -z "$output" ]
}

@test "AMD and Intel GPUs match their rules; a VM's virtio GPU matches none" {
  pci 0000:03:00.0 1002 73bf 030000
  pci 0000:00:02.0 8086 9a49 030000
  run pyre hw packages
  [ "$output" = "vulkan-radeon vulkan-intel intel-media-driver" ]
  rm -rf "$PYRE_ROOT/sys"
  pci 0000:00:01.0 1af4 1050 030000
  run pyre hw detect
  [[ "$output" == *"no rule matches"* ]]
}

@test "apply writes the NVIDIA drop-ins once; a second run changes nothing" {
  pci 0000:07:00.0 10de 2489 030000
  run pyre hw apply
  [ "$status" -eq 0 ]
  grep -qx 'MODULES+=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)' "$PYRE_ROOT/etc/mkinitcpio.conf.d/50-pyre-hw.conf"
  grep -qx 'KERNEL_CMDLINE\[default\]+=" nvidia_drm.modeset=1"' "$PYRE_ROOT/etc/limine-entry-tool.d/50-pyre-hw.conf"
  [ -f "$PYRE_ROOT/etc/nvidia/nvidia-application-profiles-rc.d/50-pyre-niri.json" ]
  grep -q '^pacman -S --needed --noconfirm nvidia-open-dkms' "$LOG"
  [ "$(grep -c '^limine-update' "$LOG")" -eq 1 ]

  : >"$LOG"
  run pyre hw apply --no-packages
  [ "$status" -eq 0 ]
  [[ "$output" == *"boot files unchanged"* ]]
  [ ! -s "$LOG" ]
}

@test "apply removes the drop-ins when the hardware is gone" {
  pci 0000:07:00.0 10de 2489 030000
  pyre hw apply --no-packages
  rm -rf "$PYRE_ROOT/sys"
  : >"$LOG"
  run pyre hw apply --no-packages
  [ "$status" -eq 0 ]
  [ ! -e "$PYRE_ROOT/etc/mkinitcpio.conf.d/50-pyre-hw.conf" ]
  [ ! -e "$PYRE_ROOT/etc/nvidia/nvidia-application-profiles-rc.d/50-pyre-niri.json" ]
  grep -q '^limine-update' "$LOG"
}
