# shellcheck shell=bash
# Generate archinstall 4.5 JSON (ADR 0011): archinstall partitions, encrypts,
# creates the btrfs subvolumes, and installs the base system. The bootloader,
# swap, and snapshots are left to the boot-stack steps in boot.sh, and the
# greeter and user stubs to desktop.sh.

readonly ESP_MIB=2048
readonly LUKS_ITER_MS=2000
# pyre-desktop pulls in the whole system. Virtual dependencies with several
# providers are named as targets too, because pacman --noconfirm otherwise
# takes the first provider: jack2 (which conflicts with pipewire-jack), an
# arbitrary ttf-font, and an arbitrary xdg-desktop-portal-impl.
readonly INSTALL_PACKAGES=(pyre-desktop pipewire-jack noto-fonts xdg-desktop-portal-gnome)

# root_partition_mib DISK_BYTES: size of the LUKS partition in MiB. It starts
# after 1 MiB of alignment space and the ESP, and leaves the last MiB free
# for the backup GPT, as archinstall requires.
root_partition_mib() {
  local disk_mib=$(($1 / 1048576))
  printf '%d\n' $((disk_mib - 1 - ESP_MIB - 1))
}

# archinstall_config DISK_BYTES SECTOR_BYTES ESP_ID ROOT_ID: print the config JSON.
archinstall_config() {
  local disk_bytes="$1" sector="$2" esp_id="$3" root_id="$4" root_mib
  root_mib="$(root_partition_mib "$disk_bytes")"
  (( root_mib >= 16384 )) || die "disk too small: need at least $((ESP_MIB + 16384 + 2)) MiB"
  jq -n \
    --arg disk "${CFG[disk]}" --argjson ss "$sector" \
    --argjson esp_mib "$ESP_MIB" --argjson root_mib "$root_mib" --argjson iter "$LUKS_ITER_MS" \
    --arg esp_id "$esp_id" --arg root_id "$root_id" \
    --arg hostname "${CFG[hostname]}" --arg timezone "${CFG[timezone]}" \
    --arg locale "${CFG[locale]}" --arg keymap "${CFG[keymap]}" \
    --argjson packages "$(printf '%s\n' "${INSTALL_PACKAGES[@]}" | jq -R . | jq -s .)" '
    def size($v; $u): {value: $v, unit: $u, sector_size: {value: $ss, unit: "B"}};
    def part($id; $start; $len): {
      obj_id: $id, status: "create", type: "primary", dev_path: null,
      start: size($start; "MiB"), size: size($len; "MiB")
    };
    {
      "archinstall-language": "English",
      disk_config: {
        config_type: "manual_partitioning",
        device_modifications: [{
          device: $disk,
          wipe: true,
          partitions: [
            part($esp_id; 1; $esp_mib) + {
              fs_type: "fat32", mountpoint: "/boot", mount_options: [],
              flags: ["boot", "esp"], btrfs: []
            },
            part($root_id; 1 + $esp_mib; $root_mib) + {
              fs_type: "btrfs", mountpoint: null,
              mount_options: ["compress=zstd:3", "noatime"], flags: [],
              btrfs: [
                {name: "@", mountpoint: "/"},
                {name: "@home", mountpoint: "/home"},
                {name: "@log", mountpoint: "/var/log"},
                {name: "@pkg", mountpoint: "/var/cache/pacman/pkg"},
                {name: "@snapshots", mountpoint: "/.snapshots"}
              ]
            }
          ]
        }],
        disk_encryption: {
          encryption_type: "luks", partitions: [$root_id], lvm_volumes: [], iter_time: $iter
        }
      },
      hostname: $hostname,
      kernels: ["linux", "linux-lts"],
      locale_config: {kb_layout: $keymap, sys_lang: $locale, sys_enc: "UTF-8"},
      timezone: $timezone,
      ntp: true,
      network_config: {type: "nm"},
      packages: $packages,
      services: ["firewalld.service", "greetd.service", "bluetooth.service", "power-profiles-daemon.service"]
    }'
}

# archinstall_creds: print the credentials JSON. It holds secrets, so callers
# write it only to a 0600 file on the live system's tmpfs.
archinstall_creds() {
  jq -n --arg user "${CFG[username]}" --arg password "${CFG[password]}" \
    --arg luks "${CFG[luks_passphrase]}" '{
      encryption_password: $luks,
      users: [{username: $user, "!password": $password, sudo: true}]
    }'
}
