# Known Issues — SafeHaven Pi v1.0-alpha

An honest list of things that don't fully work, don't scale, or are limited
in the first release. Documented openly so users know what they're getting
and what's deliberately left for a future version.

Everything here is either **by design** (a conscious v1 scope decision) or
**acknowledged debt** (we know it could be better but shipped without it).
Nothing here is a silent surprise.

---

## By design

### Suricata rules don't auto-update

The emerging-threats rule set (~48,000 signatures) is bundled at install
time. It will not refresh itself — doing so would require the device to
phone home for rule updates, which contradicts the project's "no outbound
dependencies" principle.

**To update manually:** `sudo suricata-update && sudo systemctl restart suricata`.

The bundled rules remain useful for years because most attack patterns are
long-lived. Users running SafeHaven Pi in high-threat environments should
budget for a monthly manual refresh.

### Pi-hole gravity list is manual

The ad/tracker blocklists in Pi-hole do not automatically refresh. Same
reason as Suricata: refreshing pulls from a remote source, which breaks
the offline-first contract.

**To update manually:** `pihole -g` on the Pi.

### No phone-home updates

The codebase itself does not check GitHub for newer releases. This is by
design — auto-update would require the device to phone home, which
contradicts the project's "no outbound dependencies" principle.

Users who want to stay current should pull from the repository manually
(`git pull` in the install location) or watch the repo on GitHub for
new release notifications.

### VPN tunnel reachable only from the SafeHaven hotspot

Per-device VPN client configs (generated via `[6] Manage VPN Devices →
Add a Device`) use `Endpoint = 10.42.0.1:51820` — the Pi's address on
the SafeHaven hotspot subnet. A device can only complete a WireGuard
handshake while connected to that hotspot.

This is by design and follows the project's "carry your own trusted
network" thesis:

- The VPN's attack surface is limited to whoever can join the hotspot
  itself (protected by the hotspot's WPA2 password)
- No public WireGuard server is exposed to the open internet
- Encryption and DNS filtering layer *on top of* the trusted hotspot,
  rather than replacing it

Use cases that need "VPN-from-anywhere" (e.g. a journalist on an
external network connecting back to their Pi at home) are scoped for
v2 — likely via a Tailscale-based fallback endpoint, or DDNS plus
carefully-firewalled direct exposure.

### Mode 3 Business — mock backend

The Business Mode backend is functionally complete as a working product
(user management, captive portal, live session tracking, kick/disconnect)
but uses a simulated traffic layer. Specifically:

- **Per-user IP addresses** (`10.8.0.X`) are deterministic-per-session mock
  values, not real WireGuard peer allocations
- **Traffic counters** (downloaded/uploaded bytes) increment with realistic-
  looking pseudo-random values, not actual nftables accounting
- **Ping/latency** values are randomised within a plausible range
- **Per-user traffic isolation** is not enforced at the kernel level

All user accounts, passwords (hashed), sessions, add/delete/kick actions
are real. The mock only affects the *traffic reporting* layer — everything
else is live code.

Real WireGuard per-user provisioning and nftables-level isolation **for
the Business Mode captive portal** are scoped for v2.

Note this is distinct from the **Manage VPN Devices** menu (option `[6]`),
which provisions real WireGuard peers (fresh keypair per device, real
peer entries in `wg0.conf`, live status from `wg show`). The Business
Mode user model and the device manager are two separate systems
operating at different layers — the device manager is general-purpose
WireGuard onboarding; Business Mode adds an HTTP captive-portal layer
above it for multi-tenant scenarios.

### Single admin account

The admin authentication layer supports exactly one admin user per Pi.
There is no multi-admin support in v1.

The Business Mode user management layer (`/admin/users`) does support a
"role" field with `admin` / `user` values, but only the `user` role is
currently wired to the captive portal. Admin-role business users are
treated identically to regular users; the field is reserved for v2.

### No password recovery

If you forget the admin password, the recovery path is:

```
sudo python3 app.py --set-admin-password
```

There is no "forgot password" flow. This is intentional — the Pi is a
physical device in your possession. If an attacker has shell access to
run that command, they already own the device.

---

## Acknowledged debt

### Portal sessions reset on Flask restart

Currently-connected captive portal users are tracked in an in-memory
Python dict (`_portal_sessions`). If the Flask app restarts (e.g. Pi
reboot, manual stop/start), all active portal sessions are cleared.

Users' browsers will still have a valid cookie, but the server-side
session state is gone — the frontend detects this on the next status
poll and redirects them back to the login page. Clean UX, but they have
to re-authenticate.

Persisting portal sessions across restarts would require a small
SQLite database or similar. Not critical for v1.

### Dashboard "Loading..." on fresh installs

On a freshly-installed Pi where Suricata hasn't logged any events yet
(empty `/var/log/suricata/eve.json`), or where Cowrie's log path
differs, dashboard widgets may show "Loading..." indefinitely for the
affected panels.

The dashboard APIs return empty structures correctly; the frontend
just doesn't distinguish "no data yet" from "still fetching" perfectly.

Workaround: leave the Pi running for 24 hours before a demo so logs
populate, or trigger a manual Suricata alert (e.g. `curl testmynids.org/uid/index.html`).

### Cowrie log path is hardcoded

`app.py` expects Cowrie's JSON log at
`/home/cowrie/cowrie/var/log/cowrie/cowrie.json`.

If your Cowrie install uses a different path (e.g. ran the installer as
a different user), the `/api/cowrie` endpoint returns empty data. Adjust
the `COWRIE_LOG` constant near the top of `app.py` if needed.

### Untracked WireGuard peers in the device manager

The **Manage VPN Devices** menu (option `[6]`) tracks peers in
`/etc/safehaven/wg-devices.json` so each one can be referred to by a
friendly name. A peer added by other means — `sudo wg set wg0 peer
<pubkey> allowed-ips X/32` directly on the Pi, or a manually-edited
`/etc/wireguard/wg0.conf` — will show up in `wg show wg0` but not in
the JSON metadata.

The device manager flags these in the **List Devices** view with a
yellow `⚠` warning. Untracked peers continue to work normally (the
kernel and `wg-quick` see them as legitimate); they just can't be
renamed or removed by friendly name from the menu.

**Workaround for clean management:** remove the untracked peer with
`sudo wg set wg0 peer <pubkey> remove && sudo wg-quick save wg0`,
then re-add through `[6] → Add a Device` so it gets tracked properly.

### DNS-over-TLS rejected by Pi-hole

Pi-hole on the Pi listens for plain DNS queries on UDP/TCP port 53.
Clients that try DNS-over-TLS (port 853) — Android sometimes attempts
this when "Private DNS" is enabled — get a TCP RST and gracefully fall
back to plain DNS-over-UDP, which still routes through Pi-hole and gets
filtered.

This is harmless in practice: the entire WireGuard tunnel is encrypted
around the DNS query, so the upstream network (the Pi's own ISP / hotel
WiFi) cannot see *which domains* the client resolves. The unencrypted
leg is only inside the tunnel between client and Pi, on a private
subnet under your control.

A genuinely encrypted DNS path (DoH or DoT from the Pi to its upstream
resolver, replacing the plain DNS upstream Pi-hole defaults to) would
close the small remaining unencrypted gap on the Pi itself; that's a
v2 candidate.

### README screenshots are outdated

The screenshots in `assets/screenshots/` were captured early in
development and don't reflect the current state of the menu, dashboard,
or Business Mode pages. Planned for refresh before v1.0-alpha tag.

### Mobile dashboard layout works but is untested

The Flask dashboard is responsive and renders on mobile browsers, but
intensive testing was done primarily on desktop. Minor layout quirks
may exist on unusual screen sizes.

### No internationalisation

All text is English only. No i18n framework in place.

---

## Environment-specific caveats

### Raspberry Pi 4 is supported but constrained

SafeHaven Pi runs on Pi 4 (4GB / 8GB) as well as Pi 5. On the Pi 4:

- Expect higher CPU utilisation under sustained Suricata load
- Thermal throttling is more likely without active cooling
- RAM usage with the full stack hovers around 1.8-2.2 GB

The 4GB Pi 4 works but leaves little headroom. 8GB is recommended if
targeting this SKU.

### USB WiFi adapter required for hotspot

The Pi's built-in WiFi is used for the upstream connection (`wlan0`).
To create the SafeHaven hotspot, a USB WiFi adapter supporting AP mode
is required as `wlan1`.

Without a USB adapter, clients must connect via Ethernet. This is a
hardware limitation, not a software one.

### eduroam and similar WPA2-Enterprise networks

The Raspberry Pi OS network manager GUI has issues configuring eduroam
and similar 802.1x WPA-Enterprise networks reliably. The command-line
`nmcli` workflow works consistently — see TROUBLESHOOTING.md.

---

## What this list is not

This is not a roadmap of v2 features.

This is not a security disclosure list — if you find a genuine
vulnerability, see `SECURITY.md` for how to report.

This is a user-honest "here's what v1 doesn't do" document. If you
were about to open an issue asking "why doesn't X work" and X is here,
it's acknowledged and either deliberate or queued for later.
