# ADR 0002: Niri and Noctalia as the proposed desktop

- Status: Accepted (2026-11-07). Niri confirmed by the project author; shell specifics in ADR 0005
- Date: 2026-11-04

## Context

The desired desktop is Wayland-first, keyboard-oriented, modular, and visually cohesive. The host runs a Hyprland/Quickshell-based desktop, but the distribution should make independent choices.

## Decision

Retain Niri as proposed compositor and Noctalia as proposed shell. Do not make Hyprland the default. Validate the pair on the ISO/installed VM before final commitment, including startup, portals, notification, lock/idle, audio/network controls, screenshots, screen sharing, multi-monitor operation, and NVIDIA behavior.

## Consequences

The host configuration cannot simply be copied: compositor settings, shell protocol, package ownership, and keybindings differ. Noctalia v5 is a major change from the Quickshell-based v4 and requires clean configuration. If VM evidence shows a material integration or reliability problem, revisit this ADR with concrete alternatives.

## References

- https://yalter.github.io/niri/
- https://github.com/niri-wm/niri/releases
- https://github.com/noctalia-dev/noctalia/releases
- https://github.com/noctalia-dev/noctalia-docs/blob/main/src/content/docs/noctalia/getting-started/installation.mdx

## Update 2026-11-07

The project author confirmed Niri as the compositor. Niri 26.04 (in Arch `extra`) has built-in blur, an overview, config includes, and automatic xwayland-satellite integration. Its NVIDIA guidance is the `GLVidHeapReuseRatio=0` application profile. Noctalia v5 is accepted separately in ADR 0005. VM validation still gates P3 acceptance. If a blocking defect turns up, revisit with evidence.
