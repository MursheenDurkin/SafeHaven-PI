# V2 Ideas — SafeHaven Pi

> This document captures the roadmap for a hypothetical SafeHaven Pi v2.
> **It is not a commitment.** The v1.0-alpha repository is time-capsule
> locked after submission and will not receive further commits. If a v2
> ever exists, it will live in a separate repository.
>
> This file exists so that:
> - The scope of v1 is clearly demarcated
> - Anyone forking v1 knows what's already been considered for later
> - The author's design thinking is preserved for future reference

---

## Core architecture evolution

### 1. Real WireGuard per-user provisioning

**Current (v1):** Business Mode uses mock IPs (`10.8.0.X`) and simulated
traffic counters. User management stores hashed passwords but doesn't
generate WireGuard keypairs or peer configurations.

**v2:** When an admin creates a business user:
- Generate a new WireGuard keypair for that user
- Add a `[Peer]` entry to `wg0.conf` with a unique `AllowedIPs` range
- Return a downloadable `.conf` file (or QR code) to the admin
- Admin distributes the config to the user out-of-band

User then installs the WireGuard client with their config and connects
as a real VPN peer. All traffic metrics become real.

### 2. Per-user traffic isolation

**Current (v1):** All connected users share the same network namespace.
Anyone on the hotspot can see anyone else's traffic at layer 2.

**v2:** Each business user gets:
- Their own network namespace, OR
- iptables/nftables mark-based isolation per WireGuard peer IP

Prevents lateral movement between users in a shared Business Mode
deployment. Matches the security promise the product already makes.

### 3. Per-user bandwidth quotas

Add rate limits per WireGuard peer using `tc` or `nftables` traffic
shaping. Admin UI would gain a "Bandwidth" field on the Add User modal.

Particularly useful in the "conference hotspot" use case where a few
heavy users shouldn't saturate the uplink.

---

## Hardware

### 4. 5G / 4G cellular uplink — SIM7600G-H

Already acknowledged in v1's hardware section as "planned Phase 3". v2
would:
- Integrate the SIM7600G-H USB dongle as a first-class upstream option
- Add a Mode 5 "Cellular" or fold cellular into existing modes
- Handle APN configuration via the setup wizard
- Fall back gracefully to WiFi/Ethernet if cellular drops

Makes the Pi deployable in places with no WiFi infrastructure — journalist
in the field, event in a rural venue, travel with unreliable hotel WiFi.

### 5. Case with OLED status display

A small OLED screen (SSD1306 or similar over I²C) showing live status
without needing to SSH in:
- Mode name
- Connected clients count
- Threats blocked today
- Uptime

Turns the Pi from "magic box you must query" into "glanceable appliance."

### 6. Hardware security key integration

Use a YubiKey or similar for admin authentication instead of (or in
addition to) the password. WebAuthn integration in the Flask admin
login.

### 7. Dedicated crypto acceleration

Where hardware supports it (Pi 5's cryptographic extensions), route
WireGuard and Tor through hardware-accelerated paths. Measurable
throughput improvements for saturated VPN scenarios.

---

## Software / UX

### 8. Mobile companion app (native)

**Current (v1):** Mobile access is via Termux SSH — powerful but
technical.

**v2:** A lightweight native app (Flutter or React Native) that:
- Polls the Flask dashboard's existing `/api/*` endpoints
- Shows at-a-glance status widgets (threats, DNS, clients)
- Can toggle modes via API
- Sends push notifications on high-severity Suricata alerts

Keeps the privacy thesis intact — app talks only to *your* Pi, no
third-party cloud.

### 9. Threat alerts via local channels

When a Priority 1 Suricata event fires, notify the admin:
- Via the mobile companion app (above)
- Via a local LAN notification (mDNS? WebSocket push?)
- Via a hardware output (LED, buzzer, OLED flash)

Not via email/SMS/Slack — those are outbound dependencies that break
the privacy model.

### 10. Real-time dashboard via WebSockets

**Current (v1):** Dashboard polls `/api/*` every 2-10 seconds.

**v2:** Swap polling for WebSocket push. Lower server load, lower
client battery drain, near-instant update on new alerts.

### 11. Multi-admin with role-based access

Currently one admin user. v2 would support:
- Multiple admin users in `auth.json`
- Role field (`admin`, `viewer`, `operator`)
- Permission matrix (e.g. viewers can't delete business users)
- Audit log of admin actions

Makes SafeHaven Pi viable for small team deployments.

### 12. Export to SIEM

Optional feature: forward Suricata alerts to an external SIEM (Splunk,
Elastic, Graylog) over syslog. Opt-in only, disabled by default. Keeps
the privacy thesis intact — users explicitly choose to share data.

### 13. Captive portal branding

Let Business Mode admins upload a logo + set a custom welcome message
for the captive portal. Turns a generic "VPN Portal" into a branded
"Acme Conference WiFi" experience without touching code.

### 14. Per-user time-boxed access

Business Mode user creation gains an expiry field — "this account
auto-deletes in 24 hours / 7 days / at end-of-event". Useful for
conferences where accounts are meant to be ephemeral.

---

## Security / privacy hardening

### 15. Full disk encryption

Encrypt the SD card so a stolen Pi doesn't leak configs, keys, and
logs. Unlock via a boot password or USB key at power-on.

### 16. Signed commits / reproducible builds

GPG-sign all release commits. Provide a build script that produces
byte-reproducible installer artefacts so users can verify they got the
code the author wrote.

### 17. Tor bridges for Mode 2

Currently Mode 2 uses the vanilla Tor network. In environments where
Tor is blocked outright, add support for Tor bridges (obfs4, snowflake,
meek-azure).

### 18. DNS-over-HTTPS / DNS-over-TLS upstream

Currently Pi-hole's upstream resolver is plain 1.1.1.1 / 1.0.0.1. v2
would use DoH or DoT for the upstream query so the ISP / upstream
network can't see *which domains* the Pi is resolving.

---

## Mesh / multi-device

### 19. SafeHaven Pi mesh mode

Multiple SafeHaven Pi devices across a site (multiple floors of an
office, multiple hotel rooms) that share:
- Admin credentials (replicated via Tailscale)
- Business Mode user database (one user, multiple access points)
- Threat intelligence (an attack on one Pi warns all others)

Turns individual sovereign devices into a coordinated fabric.

### 20. SafeHaven-as-a-gateway

Run the SafeHaven stack on larger hardware (small x86 server) for
office deployments. Same software, more throughput, same privacy
guarantees.

---

## Deliberately *not* in v2

Things considered and explicitly deferred or rejected:

### Cloud-hosted version

A "SafeHaven as a Service" would contradict the entire product thesis.
Never.

### Ad-supported free tier

Same reason. No.

### AI/ML-based threat scoring

Considered and shelved. Suricata's rule-based detection is auditable
("this traffic matched rule N because of pattern P"). ML-based scoring
is opaque ("this looks bad with 72% confidence"). The transparency
trade-off isn't worth it for a product whose whole premise is "you can
inspect everything."

If v2 added any ML, it would run locally on the Pi (no cloud inference)
and be explicitly optional.

### Monetisation / licensing

The repository is GPL v3 forever. Any v2 must preserve this. There is
no commercial-licence path.

---

## How this list was built

Items here come from three sources:

1. **Things explicitly deferred from v1** — scope was cut to ship on time
2. **Limitations discovered while building** — "wouldn't it be nice if…"
3. **Assessor / mentor feedback** — suggestions that didn't fit v1 scope

This document is **not prescriptive**. A v2 author (even if that's me)
may ignore this list entirely. It's a snapshot of what seemed like a
good idea in April 2026 from the v1 author's vantage point.
