# shellcheck shell=bash
# The desktop steps pyre-install owns after archinstall returns (ADR 0013).
# archinstall installs pyre-desktop and enables its services; these steps
# configure greetd and give the first user the PyreOS stubs.

TARGET="${TARGET:-/mnt}"

# greetd_config: the greetd config for noctalia-greeter, with an optional
# autologin session. The installer writes /etc/greetd/config.toml once; greetd
# lists it in backup=(), so it is the admin's afterwards.
greetd_config() {
  cat <<'EOF'
# Written by pyre-install; yours to edit. See greetd(5).
[terminal]
vt = 1

[default_session]
command = "noctalia-greeter-session"
user = "greeter"
EOF
  [[ "${CFG[autologin]}" == true ]] || return 0
  cat <<EOF

# Log in automatically once after boot (the disk is unlocked first); logging
# out returns to the greeter.
[initial_session]
command = "niri-session"
user = "${CFG[username]}"
EOF
}

write_greetd_config() {
  greetd_config >"$TARGET/etc/greetd/config.toml"
  info "greetd: noctalia-greeter$([[ "${CFG[autologin]}" == true ]] && printf ', autologin for %s' "${CFG[username]}")"
}

# keyring_pam FILE: print greetd's PAM file with gnome-keyring added, so the
# login password creates and unlocks the "login" keyring and apps never prompt
# for a new keyring password. Unchanged if the module is already there.
keyring_pam() {
  local file="$1"
  if grep -q pam_gnome_keyring "$file"; then
    cat -- "$file"
    return 0
  fi
  awk '
    { lines[NR] = $0 }
    $1 == "auth" { last_auth = NR }
    $1 == "session" { last_session = NR }
    END {
      for (i = 1; i <= NR; i++) {
        print lines[i]
        if (i == last_auth) print "auth       optional     pam_gnome_keyring.so"
        if (i == last_session) print "session    optional     pam_gnome_keyring.so auto_start"
      }
    }' "$file"
}

write_greetd_pam() {
  local pam="$TARGET/etc/pam.d/greetd" new
  new="$(keyring_pam "$pam")"
  printf '%s\n' "$new" >"$pam"
  info "greetd PAM: gnome-keyring unlocks with the login password"
}

# User reconcile gives the first user the PyreOS stubs (its unit
# user/001-home-stubs): archinstall creates the user before it installs
# pyre-desktop, so /etc/skel/.config arrives too late for useradd.
seed_user_home() {
  local user="${CFG[username]}"
  [[ -d "$TARGET/home/$user" ]] || die "archinstall did not create /home/$user"
  in_target runuser -u "$user" -- env HOME="/home/$user" pyre reconcile --user >/dev/null ||
    die "pyre reconcile --user failed for $user"
  info "user stubs and reconcile state for $user"
}

# The git identity the user gave, if any (ADR 0022). pyre dev git writes it
# into the user's own ~/.config/git/config, with the keyring as the place
# git keeps passwords and tokens.
seed_git_identity() {
  local user="${CFG[username]}" args=()
  [[ -z "${CFG[git_name]}" ]] || args+=(--name "${CFG[git_name]}")
  [[ -z "${CFG[git_email]}" ]] || args+=(--email "${CFG[git_email]}")
  (( ${#args[@]} )) || return 0
  in_target runuser -u "$user" -- env HOME="/home/$user" pyre dev git "${args[@]}" ||
    die "pyre dev git failed for $user"
  info "git identity for $user"
}

# keyring_file: a gnome-keyring keyring without a password (its plain format).
keyring_file() {
  printf '[keyring]\ndisplay-name=Default keyring\nctime=%s\nmtime=0\nlock-on-idle=false\nlock-after=false\n' "$(date +%s)"
}

# With autologin nobody types a password at login, so gnome-keyring can
# neither unlock nor create a keyring from it, and the first app that stores a
# secret gets a "choose a password for the new keyring" dialog. An autologin
# install gets a default keyring without a password instead (ADR 0018): the
# disk encryption protects it at rest, and it is all that stands before an
# autologin session anyway.
seed_autologin_keyring() {
  local user="${CFG[username]}" dir
  [[ "${CFG[autologin]}" == true ]] || return 0
  dir="/home/$user/.local/share/keyrings"
  # Written as the user from the inherited stdin: another user cannot reopen
  # root's pipe through /dev/stdin.
  in_target runuser -u "$user" -- install -d -m 700 "$dir"
  # shellcheck disable=SC2016 # $1 belongs to the inner shell
  keyring_file | in_target runuser -u "$user" -- sh -c 'umask 077 && cat >"$1"' sh "$dir/Default_keyring.keyring"
  # shellcheck disable=SC2016
  printf 'Default_keyring' | in_target runuser -u "$user" -- sh -c 'cat >"$1"' sh "$dir/default"
  info "keyring: a default keyring without a password, for autologin"
}

# Hardware rules (pyre hw): their packages come from the live medium's
# repositories through pacstrap, because the target's pacman.conf points at
# network mirrors; then the rules write their drop-ins in the target.
# snap-pac is installed by now, and SNAP_PAC_SKIP keeps this transaction, like
# the rest of the installation, from leaving snapshots behind.
hw_setup() {
  local pkgs
  pkgs="$(in_target pyre hw packages)"
  if [[ -n "$pkgs" ]]; then
    # shellcheck disable=SC2086 # a space-separated package list
    SNAP_PAC_SKIP=y pacstrap -C /etc/pacman.conf -G -M "$TARGET" --noconfirm --needed $pkgs
  fi
  in_target pyre hw apply --no-packages
  info "hardware rules: ${pkgs:-none matched}"
}

desktop_setup() {
  step "Configuring the desktop (ADR 0013)"
  write_greetd_config
  write_greetd_pam
  hw_setup
  seed_user_home
  seed_git_identity
  seed_autologin_keyring
}
