# ADR 0012: firewalld is the default firewall

- Status: Accepted
- Date: 2026-11-08

## Context

ADR 0008 left the firewall to its own decision. The candidates in `extra` as of 2026-11-08:

| | `ufw` 0.36.2 | `firewalld` 2.5.2 | plain `nftables` 1.1.7 |
|---|---|---|---|
| Runtime | Python, iptables (nft backend) | Python, `python-dbus`, `python-gobject`, nftables | none (C) |
| NetworkManager | no integration | each connection gets a zone (`connection.zone`), for example `home` versus `public` Wi-Fi | none |
| Config layering | rules live in package-owned `backup=` files under `/etc/ufw` | vendor zones and services in `/usr/lib/firewalld/`, admin overrides in `/etc/firewalld/` | one admin file, `/etc/nftables.conf` |
| API | CLI only | D-Bus with polkit, which a later settings UI can drive | none |
| Containers and VMs | Docker bypasses its rules, a long-standing problem | Docker, libvirt and podman manage their own firewalld zones | manual |

Both front-ends need Python on the installed system. firewalld adds only the D-Bus and GObject bindings.

## Decision

- `pyre-base` depends on `firewalld`. The installer enables `firewalld.service`.
- The default zone is firewalld's stock `public`, which allows `ssh` and `dhcpv6-client`. `sshd` is not installed by default, so no port is open in practice. PyreOS ships no custom zone and does not edit `firewalld.conf`.
- Users mark trusted networks per connection through NetworkManager zones. Opening ports is `firewall-cmd`, or a later settings UI.

## Consequences

- The vendor-in-`/usr` and admin-in-`/etc` split matches ARCHITECTURE principle 2, with no PyreOS-owned config.
- The base system gains about 6.5 MB of firewalld packages, plus the Python D-Bus and GObject bindings.
- If a minimal or server profile appears later, it can choose plain `nftables` with its own ADR.
