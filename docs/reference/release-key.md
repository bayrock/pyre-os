# Release signing key

This is how the PyreOS release key is kept, used, renewed and revoked. ADR 0009 sets the model, and this document is the procedure that ADR asks for.

## What exists

- **Primary key:** `PyreOS Release Key`, ed25519, certify-only. It expires on 2031-11-12, and its fingerprint is `65D123DD9A18A346A94C38E6228693F6D58F0A7F`. It lives only offline.
- **Signing subkey:** ed25519, sign-only, made on 2026-11-13, fingerprint `279066B8C9E6FD17B3B9189C588DC5476F4A31E4`. It expires on 2028-11-12. CI holds a passphrase-less copy of it, alone, in the Actions secret `PYRE_SIGNING_SUBKEY`.
- **Public key:** `packages/pyre-keyring/release.asc`, holding the primary key and the subkey. `tools/dev-key` folds it into the `pyre.gpg` that pacman imports, and `pyre-trusted` trusts its primary fingerprint.

## Where the private key lives

The offline keyring is one directory, a `GNUPGHOME`, that holds:
- the primary secret key
- the subkey
- the revocation certificate, in `openpgp-revocs.d/<fingerprint>.rev`

The rules:
- Copies go on **two** offline drives, ideally LUKS with ext4. gpg warns about unsafe permissions on FAT.
- The passphrase is stored separately from both drives.
- No machine keeps a copy. Mount a drive, use the keyring in place, then unmount it.

None of this depends on the host OS. Reinstalling, or moving to PyreOS, changes nothing: what you need is a drive, the passphrase, a checkout of this repo, `gpg`, and `wl-copy`. PyreOS ships all of those. The Actions secret lives on GitHub and survives any reinstall.

## Refresh the CI copy

```bash
tools/release-key-ci /path/to/drive/pyre-release-key
```

The script:
1. asks for the passphrase in the terminal
2. copies only the newest valid signing subkey into a throwaway keyring under `$XDG_RUNTIME_DIR`
3. removes the passphrase from that copy
4. checks that the copy signs with no passphrase, holds no primary secret, and verifies against the public key alone
5. puts the copy on the clipboard for the `PYRE_SIGNING_SUBKEY` secret, then clears the clipboard after you press Enter (`--out FILE` writes a file instead)
6. writes the public key to `build/keys/pyre-release.asc`

Nothing secret is printed, and the scratch keyring is deleted on exit.

To update the secret, go to **bayrock/pyre-os → Settings → Secrets and variables → Actions**.

Run the script after any change to the subkey: after creating it, renewing it or rotating it.

## Renew before expiry

Extend the subkey at least a month before it expires. The primary key can be extended the same way.

```bash
export GNUPGHOME=/path/to/drive/pyre-release-key
gpg --quick-set-expire 65D123DD9A18A346A94C38E6228693F6D58F0A7F 2y '*'   # every subkey
gpg --quick-set-expire 65D123DD9A18A346A94C38E6228693F6D58F0A7F 5y       # primary, when needed
unset GNUPGHOME
tools/release-key-ci /path/to/drive/pyre-release-key
```

Then update the keyring package (the same three steps after any key change):
1. Copy `build/keys/pyre-release.asc` to `packages/pyre-keyring/release.asc`.
2. Run `tools/dev-key`, which rebuilds `pyre.gpg` and `pyre-trusted` from the release and dev keys.
3. Update `sha256sums` in its PKGBUILD, bump `pkgrel`, and publish it.

Clients only learn the new expiry from the keyring package.

## Rotate the subkey (lost or leaked CI secret)

```bash
export GNUPGHOME=/path/to/drive/pyre-release-key
gpg --edit-key 65D123DD9A18A346A94C38E6228693F6D58F0A7F   # "key N" for the old subkey, then "revkey", "save"
gpg --quick-add-key 65D123DD9A18A346A94C38E6228693F6D58F0A7F ed25519 sign 2y
unset GNUPGHOME
tools/release-key-ci /path/to/drive/pyre-release-key
```

Then:
1. Publish a `pyre-keyring` that carries the revoked subkey and the new one.
2. Rebuild and re-sign everything in the repository.

The primary fingerprint stays the same, so `pyre-trusted` does not change.

## Revoke the primary key (lost drive or leaked passphrase)

1. Take `openpgp-revocs.d/<fingerprint>.rev` from the surviving drive.
2. Delete the `:` before the `-----BEGIN` line, then import the certificate.
3. Create a new key, following the steps in the next section.
4. Publish a `pyre-keyring` with these changes:
   - the old fingerprint added to `pyre-revoked`
   - the new fingerprint in `pyre-trusted`
   - both public keys in `pyre.gpg`
5. Replace `PYRE_SIGNING_SUBKEY`.

## Creating a key from scratch

```bash
export GNUPGHOME=/path/to/drive/pyre-release-key
mkdir -m 700 "$GNUPGHOME"
gpg --quick-generate-key 'PyreOS Release Key' ed25519 cert 5y
PRIMARY=$(gpg --with-colons -K | awk -F: '$1=="fpr"{print $10; exit}')
gpg --quick-add-key "$PRIMARY" ed25519 sign 2y
gpg -K    # sec [C] and ssb [S]
unset GNUPGHOME
tools/release-key-ci /path/to/drive/pyre-release-key
```

**Pitfall:** `gpg --passwd` cannot remove a subkey's passphrase in a keyring where the primary key is only a stub. It stops at the primary key. `tools/release-key-ci` asks gpg-agent directly instead.
