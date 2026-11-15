# Software

PyreOS is Arch Linux, so the whole Arch repository is yours, and the AUR too. PyreOS itself installs little: a terminal, a browser, a file manager and an editor. The rest is yours to choose.

## The Install menu

Open the launcher (**Super + Space**) and type `install`, or open the PyreOS menu (**Super + Alt + Space**):

- **Install › …** lists optional apps picked for PyreOS: a video player, an image viewer, a document viewer, the screen recorder, editors, coding agents, terminals, messengers and more. All but one come from Arch's own repositories. The exception is **Claude Code**, which Anthropic's own installer puts into your home; the row says so and asks first.
- **Install › Find a package…** searches everything in those repositories. Tab marks several, Enter installs.
- **Remove › …** lists what you installed from the menu.

An install opens a small terminal that asks for your password and shows what pacman does. It needs a network connection. On a machine installed without one, the first install offers an update first, which fetches the package lists.

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

The menu lists the bundles too, as **Install › dev bundle** and so on. The installer offers the `dev` bundle, and `pyre dev` sets up git with it; the Development page explains.

## Single apps

```
sudo pacman -S <package>   # install
pacman -Ss <words>         # search
sudo pacman -Rs <package>  # remove, with what it pulled in
```

Every pacman transaction is snapshotted, so trying an app is safe.

**The AUR** holds community packages that are not in Arch's repositories. PyreOS does not install an AUR helper for you; if you add `paru` or `yay`, `pyre update` upgrades your AUR packages too, and the menu gains **Install › Find in the AUR…**. Read a package's build script before you install it from the AUR.

**Flatpak** works as on any Arch system: `sudo pacman -S flatpak`.
