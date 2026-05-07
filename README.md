# SafeHaven Pi

![SafeHaven Pi](assets/safehaven_logo.png)

> **Privacy is a right, not a product.**

SafeHaven Pi is a portable, open-source network security device built on a Raspberry Pi 5. Plug it in, connect any device to its hotspot, and your traffic is automatically encrypted, filtered, and monitored before it reaches the wider internet — no apps, no subscriptions, no third-party trust required. It's designed for travellers, journalists, conference organisers, and anyone who'd rather carry their own trusted network than rely on a hotel's.

It runs eight integrated security layers — from the WiFi hotspot itself up through firewall, VPN tunnel, DNS filtering, intrusion detection, brute-force protection, and an SSH honeypot — plus Tailscale on a separate channel for remote admin. The full stack is wrapped in a single command-line interface and a live web dashboard. Four operating modes cover everyday public-WiFi use through to maximum-anonymity Tor routing.

This release is **v1.0-alpha**, the version submitted to a university hackathon in May 2026 — and the foundation the project keeps building from.

---

## Quick start

If you have a Raspberry Pi 4 or 5 with a USB WiFi adapter, the install is three commands:

```bash
# 1. Clone the repository
git clone https://github.com/MursheenDurkin/SafeHaven-PI.git
cd SafeHaven-PI

# 2. Run the installer (once — pulls all dependencies)
sudo bash install.sh

# 3. Launch the control menu
sudo bash safehaven.sh
```

That's it. Your Pi is now broadcasting an encrypted hotspot.

### First run — the Setup Wizard

The first time you launch, press **`w`** in the menu to open the Setup Wizard. It walks you through four steps so the Pi isn't running on defaults:

1. **Hotspot name and password** — the WiFi other devices will see and connect to
2. **Pi hostname** — change it from the well-known `raspberrypi` default
3. **Admin password** — replace the default Pi password
4. **WireGuard VPN keys** — generate a fresh keypair unique to your Pi

> None of this is stored in the repository. Every value is written directly to your Pi only — every user who clones this repo starts fresh, with no shared credentials, identifiable IPs, or leftover keys. You can re-run the wizard from the System menu any time.

---

## What you'll see

### Boot sequence

Every security layer starts up one by one. You can watch each service come online before the menu loads.

![Boot sequence](assets/screenshots/boot.png)

### Control menu

Once everything is running, the control menu loads. Live system status, current mode, last-detected threat, CPU and RAM usage all visible at a glance.

![Main control menu](assets/screenshots/menu.png)

### Activating a mode

Press a number to switch security profile. Each mode brings up its layers in sequence and confirms when it's ready.

![Mode 1 — Traveler Mode](assets/screenshots/mode1.png)

### Live security logs

Press **`5`** to open the log viewer and watch real-time threat detections, blocked DNS queries, banned IPs, or honeypot connections.

![Live log viewer](assets/screenshots/logs.png)

---

## How it protects you

SafeHaven Pi runs eight security layers simultaneously the moment you connect:

| Layer | Service | What it does |
|-------|---------|--------------|
| 1 | **hostapd** | Creates a WPA2-encrypted WiFi hotspot |
| 2 | **dnsmasq** | DHCP server — hands out tunnel IPs to connected devices |
| 3 | **nftables** | Firewall and NAT — controls and routes all traffic |
| 4 | **WireGuard** | VPN tunnel — encrypts everything between your devices and the Pi |
| 5 | **Pi-hole** | DNS filter — blocks ads, trackers, and known-malicious domains |
| 6 | **Suricata** | Intrusion detection — ~48,000 threat signatures |
| 7 | **Fail2ban** | Brute-force protection — auto-bans repeat attackers |
| 8 | **Cowrie** | SSH honeypot — lures attackers on port 2222 and logs every keystroke |

Plus **Tailscale** for secure remote management without exposing the Pi to the public internet.

---

## Operating modes

Four profiles let you match the Pi's behaviour to the situation:

### Mode 1 — Traveler

Everyday public-WiFi protection. Encrypts all traffic through WireGuard, filters DNS through Pi-hole, monitors for intrusions with Suricata. Connect and you're protected. The default for hotels, cafés, airports, and university WiFi.

### Mode 2 — Activist / Journalist

Privacy-first configuration. Adds Tor transparent proxy on top of (or instead of) WireGuard, enables zero-log DNS, and clears traffic logs on activation. Two sub-options at activation time:

- **Tor only** — maximum anonymity, WireGuard disabled
- **Tor over WireGuard** — double-layer protection, default

For situations where source protection is critical.

### Mode 3 — Business

Secure temporary network for conferences, shared offices, or pop-up workspaces. Adds:

- A **captive portal** at `/portal` where each user authenticates with their own credentials
- A **post-login status page** showing connection details and traffic
- An **admin management panel** at `/admin/users` for creating users, kicking live sessions, and viewing aggregate stats
- **Mode-aware authentication** — admin credentials are isolated from end-user credentials

### Mode 4 — Relaxed

Full security stack with WireGuard disabled. Pi-hole, the firewall, Suricata, Fail2ban, and Cowrie all stay active. Use this when sites detect and block known VPN IP ranges (some banks, streaming services, Cloudflare-protected pages) but you still want the rest of the protections.

---

## Managing VPN devices

Press **`[6] Manage VPN Devices`** from the main menu to open the device manager. From there you can:

| Option | What it does |
|--------|--------------|
| **`[a]` Add a Device** | Generates a fresh WireGuard keypair, allocates the next free IP, displays a one-time QR code. Scan it from the WireGuard mobile app to connect. The Pi never stores the device's private key — once you dismiss the QR, it's gone. |
| **`[l]` List Devices** | Shows every tracked device, the IP it was allocated, when each one last connected, the endpoint it's currently connected from, and how much data it's transferred through the tunnel. |
| **`[e]` Edit Device Name** | Rename a tracked device for easier admin. Doesn't touch the WireGuard configuration. |
| **`[r]` Remove a Device** | Atomically revokes a peer's access — removes it from the running interface, persists the change, and cleans up the metadata. Existing scanned configs on the user's phone stop working immediately. |

Per-device metadata (name, public key, IP, timestamp) is stored at `/etc/safehaven/wg-devices.json`. Private keys are never written to disk.

---

## Web dashboard

A live monitoring dashboard runs at **`https://10.42.0.1:5000`** on any device connected to the SafeHaven hotspot. The certificate is self-signed — your browser will warn once, then remember.

The main view shows:

- Threats blocked today (live from Suricata)
- DNS queries blocked by Pi-hole
- Connected clients
- VPN uptime and active peer count
- CPU / RAM gauges
- Network speed graph
- Threats-per-hour chart for the last 24 hours

In **single-user modes** (Traveler / Activist / Relaxed), the dashboard loads without authentication — anyone on the hotspot is implicitly the admin.

In **Business Mode**, the dashboard is gated behind admin login at `/login`, and end-users authenticate at the captive portal `/portal` instead.

### First-run setup

Before starting the dashboard for the first time, set the admin password and generate the self-signed certificate:

```bash
# Set the admin password
sudo python3 app.py --set-admin-password

# Generate the HTTPS certificate
sudo mkdir -p /etc/safehaven/ssl
sudo openssl req -x509 -newkey rsa:4096 -nodes \
  -keyout /etc/safehaven/ssl/key.pem \
  -out /etc/safehaven/ssl/cert.pem \
  -days 365 -subj "/CN=SafeHaven-Pi/O=SafeHaven/C=GB"
sudo chmod 600 /etc/safehaven/ssl/key.pem
```

The dashboard runs as a systemd service (`safehaven-dashboard.service`) and starts automatically on boot.

---

## Control menu reference

The interactive menu (`sudo bash safehaven.sh`) is the main way to control the Pi.

### Modes

| Key | Mode | What it does |
|:---:|------|--------------|
| `1` | Traveler | Everyday public-WiFi protection |
| `2` | Activist | Tor routing + zero logs for source protection |
| `3` | Business | Captive portal + per-user admin |
| `4` | Relaxed | Full stack minus VPN |

### Tools

| Key | Tool | What it does |
|:---:|------|--------------|
| `5` | Live Security Logs | Real-time view of threats, blocked sites, VPN activity |
| `6` | Manage VPN Devices | Add, list, edit, or remove devices on the VPN |
| `7` | DNS Block Stats | View Pi-hole's blocked-query counters |
| `8` | Web Dashboard | Open the browser dashboard at `https://10.42.0.1:5000` |
| `9` | Mobile Access (Termux) | Step-by-step guide for managing the Pi from your phone |
| `0` | Export Security Report | Save the last 24 hours of threats, bans, and DNS blocks to a single file |

### System

| Key | Action | What it does |
|:---:|--------|--------------|
| `w` | Setup Wizard | Configure hotspot, hostname, admin password, and WireGuard keys |
| `s` | Stop All Services | Safely shut down all protection layers |
| `r` | Reboot Pi | Restart the device — all services resume on boot |
| `x` | Shutdown Pi | Power off safely — prevents SD card corruption |
| `f` | Factory Reset | Wipe all credentials and sessions (keeps HTTPS certificate) |
| `q` | Quit | Exit to terminal — protection keeps running in the background |

The menu uses a responsive layout: wide block-font logo and three-column status panel on standard terminals, compact single-column on Termux.

---

## Hardware

### Required

- **Raspberry Pi 4 or 5** — 4GB or 8GB model. The extra RAM is needed to run all security services without slowdown. The Pi 5 is recommended for best performance, but the Pi 4 (4GB / 8GB) works well.
- **microSD card** — 32GB minimum, Class 10 or faster.

### Optional but strongly recommended — USB WiFi adapter

A USB WiFi adapter is what creates the SafeHaven hotspot that other devices connect to. Without one, clients connect via Ethernet only.

During development this project used the **Alfa Network AWUS036ACS**, which proved reliable across cafés, hotels, and university environments. Any USB adapter that supports AP mode on Linux will work — this is just what was tested.

| Spec | Value |
|------|-------|
| Standard | 802.11ac (WiFi 5) dual-band |
| 2.4 GHz speed | 150 Mbps |
| 5 GHz speed | 433 Mbps |
| Chipset | Realtek RTL8811AU |
| Antenna | External RP-SMA, 2 dBi dual-band |
| Linux support | Yes — in-kernel driver |
| AP mode | Confirmed on Raspberry Pi OS |

### Other extras

- **Case with cooling** — the Pi 5 runs warm under sustained Suricata load, a heatsink case is recommended
- **USB 3.0 hub** — useful if you're adding multiple peripherals
- **SIM7600G-H 4G dongle** — for cellular uplink in environments with no upstream WiFi (configurable but not core to v1)

---

## Mobile management (Termux)

You don't need a laptop to manage SafeHaven Pi. Any Android phone with [Termux](https://f-droid.org/packages/com.termux/) (recommended over the Play Store version) can SSH in and run the full menu.

```bash
# Inside Termux
pkg update && pkg install openssh

# Make sure your phone is on the same Tailscale network as the Pi
ssh <your-username>@<pi-tailscale-ip>

# Launch the menu
cd ~/SafeHaven-PI && sudo bash safehaven.sh
```

The menu auto-detects narrow terminals and switches to a single-column mobile layout — same protection, screen-appropriate view.

---

## Documentation

| Document | What's in it |
|----------|--------------|
| [`README.md`](README.md) | This file — project overview, install, mode and menu reference |
| [`BUSINESS_MODE.md`](BUSINESS_MODE.md) | Full Business Mode walkthrough — setup, admin and end-user flows, commands, files, troubleshooting |
| [`KNOWN_ISSUES.md`](KNOWN_ISSUES.md) | Honest list of v1 limitations — by design vs acknowledged debt |
| [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) | Symptom-to-fix playbook for common issues |
| [`CHANGELOG.md`](CHANGELOG.md) | Release notes for v1.0-alpha |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | How to fork and extend the project |
| [`SECURITY.md`](SECURITY.md) | Responsible disclosure and unmaintained-status framing |

If something isn't working, **start with `TROUBLESHOOTING.md`** — most issues are documented there with step-by-step fixes. If your concern is a known limitation, it's likely in `KNOWN_ISSUES.md`.

---

## Project structure

```
SafeHaven-PI/
├── install.sh                   ← Run once after cloning
├── safehaven.sh                 ← Main control script & menu
├── app.py                       ← Flask dashboard + auth + Business Mode API
├── safehaven-dashboard.html     ← Pi monitoring dashboard
├── login.html                   ← Admin login page
├── portal.html                  ← Captive portal login (end-user facing)
├── portal-connected.html        ← Post-login VPN status page
├── business-admin.html          ← Admin panel for managing business users
├── assets/
│   ├── safehaven_logo.png       ← Project logo
│   └── screenshots/             ← Documentation screenshots
├── configs/                     ← Service configuration templates
│   ├── hostapd.conf
│   ├── dnsmasq.conf
│   ├── wg0.conf                 ← Template only — real keys never committed
│   ├── torrc                    ← Tor transparent proxy config (Mode 2)
│   └── nftables-mode2.conf      ← Tor redirect rules
├── _teammate-originals/         ← Pristine versions of contributed HTML
├── README.md
├── KNOWN_ISSUES.md
├── TROUBLESHOOTING.md
├── CHANGELOG.md
├── CONTRIBUTING.md
├── SECURITY.md
└── LICENSE                      ← GPL v3
```

Runtime files written by the Pi (never committed):

```
/etc/safehaven/auth.json              ← Hashed admin credentials
/etc/safehaven/business-users.json    ← Hashed business-user credentials
/etc/safehaven/wg-devices.json        ← VPN device metadata (no private keys)
/etc/safehaven/secret.key             ← Flask session key
/etc/safehaven/ssl/cert.pem           ← HTTPS certificate
/etc/safehaven/ssl/key.pem            ← HTTPS private key
/tmp/safehaven-mode                   ← Current active mode
/var/lib/safehaven/.first-run         ← Marker to skip boot animation
```

---

## Built with

- [WireGuard](https://www.wireguard.com/) — VPN
- [Pi-hole](https://pi-hole.net/) — DNS filtering
- [Suricata](https://suricata.io/) — Intrusion detection
- [Fail2ban](https://www.fail2ban.org/) — Brute-force protection
- [Cowrie](https://github.com/cowrie/cowrie) — SSH honeypot
- [nftables](https://wiki.nftables.org/) — Firewall and NAT
- [Flask](https://flask.palletsprojects.com/) — Web dashboard
- [Tailscale](https://tailscale.com/) — Remote admin access

The engineering contribution of this project is the integration layer, the user-experience design, and the mode-based configuration model — the security tools themselves are battle-tested open-source projects used at production scale by other deployments worldwide.

---

## Academic context

SafeHaven Pi was built for a university cybersecurity hackathon, 2025–2026. The hackathon format means the project was scoped, designed, built, and delivered as a complete deployable system within a fixed window rather than as an open-ended research project.

---

## Licence

GPL v3. Free to use, modify, and distribute.

This project is licensed under the [GNU General Public License v3.0](https://www.gnu.org/licenses/gpl-3.0.en.html). The full text is in [`LICENSE`](LICENSE). What that means in plain terms:

**No warranty, no liability** — Sections 15 and 16 of the licence make clear that the software is provided as-is. If you use it and something goes wrong, that's your responsibility, not the authors'.

**No responsibility for misuse** — SafeHaven Pi was built as a defensive privacy and security tool. If anyone takes this code and uses it for malicious or unlawful purposes, that's their decision and their consequence — not the original authors'.

**Copyleft protection** — derivative works must also be GPL v3. You cannot take this open-source project, put it behind a paywall, make it proprietary, or charge for access to the code. It must remain free and open source.

**Attribution preserved** — anyone who uses or distributes this code must keep the original copyright notice and licence intact. You can fork and build on this project freely, but credit must remain where it belongs.

For full licence text and the philosophy behind GPL v3, see the [official GNU page](https://www.gnu.org/licenses/gpl-3.0.en.html).

---

## A Personal Note

This is my first ever major project on GitHub.

I've created small things here before — little scripts, fun experiments, things that never really went anywhere. But nothing like this. SafeHaven Pi is the first time I've built something from the ground up that actually does something meaningful, something I'm genuinely proud of.

If you've made it this far — thank you for reading. Whether you're a lecturer, a fellow student, a developer who stumbled across this, or just someone curious about privacy and security — I hope this has been interesting to look through.

This is a completely open source project. If you like what you see here and want to improve it, add features, fix things, take it in a different direction — please do. Fork it, build on it, make it better. And if you do, I'd genuinely love to see what you create. Share it with me.

---

### Project status

**v1.0-alpha** is the version submitted to a university hackathon in May 2026 — that's where this project started. The exact state submitted is preserved in git as the `v1.0-alpha-submission` tag, so anyone (future readers, future-me) can always see the original snapshot.

But this isn't where it ends. I built SafeHaven Pi as a hackathon submission and enjoyed working on it too much to leave it there. **The repository will keep getting updates** — bug fixes, doc improvements, the occasional new feature — for as long as I have the time and the project still feels alive. University is full of fun projects that get shelved the day after submission. I'd rather not let this be one of those.

If you find a bug, want to suggest something, or fix something yourself, the issues page is open and bug-fix pull requests are welcome. If you'd rather take it in your own direction, fork it — that's exactly what GPL v3 is for.

If a v2 of SafeHaven Pi ever exists it will likely live in a new repository as a substantively different product — newer hardware, newer architecture, fresh design decisions. v1 stays here as the foundation it grew from.

---

*Built with curiosity, coffee, late nights, and a lot of terminals.*
*— Durkin*
