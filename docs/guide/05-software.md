# Software

PyreOS is Arch Linux, so the whole Arch repository is yours, and the AUR too.

## Bundles

A bundle is a set of apps for one kind of work, installed in one step:

| Bundle | What's inside |
|---|---|
| `dev` | base-devel, git, GitHub CLI, lazygit, just, jq, Go, Node.js, Python with uv, rustup |
| `media` | Audacity, GIMP, Inkscape, Kdenlive, OBS Studio |
| `office` | LibreOffice, Thunderbird, spell checking |

```
pyre install              # the bundles, and which you have
pyre install dev media
pyre remove media
```

## Single apps

```
sudo pacman -S <package>   # install
pacman -Ss <words>         # search
sudo pacman -Rs <package>  # remove, with what it pulled in
```

Every pacman transaction is snapshotted, so trying an app is safe.

**The AUR** holds community packages that are not in Arch's repositories. PyreOS does not install an AUR helper for you; if you add `paru` or `yay`, `pyre update` upgrades your AUR packages too. Read a package's build script before you install it from the AUR.

**Flatpak** works as on any Arch system: `sudo pacman -S flatpak`.
