# Development machine reference

This machine is the P6 daily-driver target, recorded at model level only. It informs hardware rules and the author's personal overlay. It does **not** set distribution defaults.

## Hardware

- CPU: AMD Ryzen 5 5600X. RAM: 16 GiB.
- GPU: NVIDIA GeForce RTX 3060 Ti. It uses `nvidia-open-dkms`, since GSP is supported. The current desktop sets `LIBVA_DRIVER_NAME=nvidia`, `__GLX_VENDOR_LIBRARY_NAME=nvidia`, and `NVD_BACKEND=direct`, with early-loaded modules and `nvidia_drm modeset=1`.
- Network: Intel Wi-Fi 6 AX200 (`iwlwifi`) and Intel I211 Ethernet (`igb`).
- Audio: AMD HD Audio, NVIDIA HDMI audio, and KEF LSX II USB speakers.
- Input: Wooting 60HE v2 and Rama Works M6-B keyboards (configured through the web apps VIA and Wootility), and a WLMouse Beast Max 8K mouse.
- Storage:
  - 120 GB SATA SSD running the current desktop: a 2 GiB ESP and LUKS2 with btrfs (`@`, `@home`, `@log`, `@pkg`, zstd:3), zram plus a hibernation swapfile.
  - 1 TB NVMe holding Windows with its own ESP, so the machine dual-boots.

## Displays

These are the current Hyprland names; niri's output names may differ.

| Output | Panel | Mode | Placement |
|---|---|---|---|
| DP-1 | LG 27GK750F | 1080p@60 | Rotated 270° (portrait), left |
| DP-3 | LG UltraGear | 1920x1080@240 | Main |
| HDMI-A-1 | TV | 1080p@60 | Above main; often disconnected |

All outputs run at scale 1. The current desktop's template sets `GDK_SCALE=2`, which is wrong here because XWayland apps render at double size. Do not carry it over.

## Author preferences (for the personal overlay, not defaults)

**Desktop and apps**
- Terminal: foot. Font: Liberation Mono, around 9 pt in foot.
- Shell: bash. Browser: Firefox (Wayland). Editors: VS Code, plus LazyVim with the monokai-pro theme.
- Current theme: ristretto. A custom "le-mans-sunset" theme is unfinished.
- mpv: `profile=high-quality`, `vo=gpu-next`, `hwdec=auto-safe`, deband, keep-open, save-position-on-quit, Japanese-then-English audio language.
- Bindings: F10 mutes Vesktop globally; Shift+F10 mutes the system microphone; Super+Ctrl+Shift+D, G, and V toggle personal shell plugins.
- Personal shell plugins: `music-visualizer`, `screen-glitch`, and `dance2shell` (Quickshell/QML; the author wrote them). ADR 0005 covers their future.
- Shell bar: the clock shows life-progress; a world clock shows NY, London, Dubai, Tokyo, and LA. The dock is unused.
- Login: autologin behind LUKS.

**Packages**
- Added beyond the current desktop's defaults:
  - Development: Godot, VS Code, clang/llvm, Android tools and scrcpy, mise with bun and zig.
  - Communication and media: vesktop, spotify, gimp.
  - Utilities: keepassxc, openrgb, adguardhome as a local DNS resolver, ncdu.
- Removed from the current desktop's defaults: LibreOffice, Obsidian, OBS, kdenlive, Pinta, Xournal++, moonlight, lazydocker, ghostty.

## Unknowns

- `/boot` contents and the ufw rules: reading them needs root.
- Whether dual-boot currently goes through Limine or the firmware boot menu.
