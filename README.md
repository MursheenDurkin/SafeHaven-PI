# SafeHaven Pi

![SafeHaven Pi](assets/safehaven_logo.png)

> **Privacy is a right, not a product.**

A portable, open-source network security device built on a Raspberry Pi 5. Connect any device to its hotspot and your traffic is automatically encrypted, filtered, and monitored — no apps, no subscriptions, no trust required.

---

## Quick Start

### 1. Clone the repository
```bash
git clone https://github.com/MursheenDurkin/SafeHaven-PI.git
cd SafeHaven-PI
```

### 2. Run the installer (once)
```bash
sudo bash install.sh
```

### 3. Start SafeHaven Pi
```bash
sudo bash safehaven.sh
```

That's it. Three commands and you're protected.

### First run — the Setup Wizard

The first time you launch SafeHaven, open the **Setup Wizard** from the menu (press `w`). It walks you through four steps so your Pi isn't running on defaults:

1. **Hotspot name & password** — the WiFi other devices see when they connect
2. **Pi hostname** — change it from the well-known `raspberrypi` default
3. **Admin (sudo) password** — change it from the default Pi password
4. **WireGuard VPN keys** — generate a fresh keypair unique to your Pi

> **None of this is stored in the GitHub repository.**
> All values are written directly to your Pi only. Every user who clones this repo starts fresh — no shared credentials, no identifiable IPs, no leftover keys. You can re-run the wizard any time from the System menu.

### Managing SafeHaven Pi from your phone (Termux)

You don't need a laptop to manage SafeHaven Pi. If you have an Android phone, you can access the full control menu over SSH using Termux.

**1. Install Termux**
Download Termux from [F-Droid](https://f-droid.org/packages/com.termux/) (recommended over the Play Store version).

**2. Install OpenSSH**
```bash
pkg update && pkg install openssh
```

**3. Connect via Tailscale**
The Pi must be on your Tailscale network. Open the Tailscale app on your phone and make sure it's active, then:
```bash
ssh <your-username>@<your-tailscale-ip>
```

Your Pi's Tailscale IP is shown in the boot screen — or run `tailscale status` on the Pi to find it.

**4. Launch the menu**
```bash
cd /home/<your-username>/SafeHaven-PI && sudo bash safehaven.sh
```

The menu automatically detects your screen width and switches to a mobile-optimised layout on narrow screens.

> ⚠️ **A note on sharing your setup**
> The Setup Wizard keeps your credentials on the Pi — they never touch the repo.
> If you manually edit files in `configs/` or push your own fork, double-check
> you aren't committing real passwords, WiFi credentials, or WireGuard keys.
> The `configs/` folder contains templates only.



---

## What it looks like when you run it

### Step 1 — Boot sequence
Every security layer starts up one by one. You can watch each service come online in real time before the menu loads.

![Boot sequence](assets/screenshots/boot.png)

---

### Step 2 — Setup Wizard (first run only)
The first time you launch SafeHaven Pi, press `w` to open the Setup Wizard. It walks you through four steps: hotspot name and password, Pi hostname, admin password, and WireGuard VPN keys. Every value is generated on your Pi — nothing is stored in this repository. You can re-run the wizard any time from the System menu.

---

### Step 3 — Control menu
Once everything is running, the control menu loads automatically. Every service is shown live — green means running, the stats bar shows CPU, RAM, uptime, VPN clients and IDS signatures loaded.

![Main control menu](assets/screenshots/menu.png)

---

### Step 4 — Activating a mode
Press `1` to activate Traveler Mode. Each security layer starts in sequence and confirms when it's up. Once all layers are active it tells you you're protected.

![Mode 1 — Traveler Mode](assets/screenshots/mode1.png)

---

### Step 5 — Live log viewer
Press `5` from the menu to open the log viewer. Choose any service — Suricata, Fail2ban, Cowrie, Pi-hole or WireGuard — and watch live traffic and threat detections in real time. These are all live feeds, not simulated output.

![Live log viewer](assets/screenshots/logs.png)

---


---

## Recommended Hardware

### Required
- **Raspberry Pi 4 or 5** — must be the 4GB or 8GB model. The extra RAM is needed to run all security services simultaneously without slowdown. The Pi 5 is recommended for best performance but the Pi 4 (4GB/8GB) works well too.
- **MicroSD card** — 32GB minimum, Class 10 or faster

> The Pi's built-in WiFi is used to connect to the internet upstream.
> A USB WiFi adapter creates the SafeHaven hotspot that clients connect to.
> Without a USB adapter the Pi can still run all security services,
> but clients connect via ethernet rather than WiFi.

### Optional — USB WiFi Adapter (Recommended for Hotspot)
A USB WiFi adapter is not strictly required but is strongly recommended if you want to create a wireless hotspot for other devices to connect to.

During the development and testing of this project the **Alfa Network AWUS036ACS** was used. It worked reliably throughout the build and the range was noticeably better than the Pi's built-in antenna, making it ideal for use in cafes, hotels, and university environments.

| Spec | Value |
|------|-------|
| Standard | 802.11ac (WiFi 5) dual-band |
| 2.4GHz speed | 150 Mbps |
| 5GHz speed | 433 Mbps |
| Chipset | Realtek RTL8811AU |
| Antenna | External RP-SMA, 2dBi dual-band |
| Linux support | Yes — in-kernel driver |
| AP mode | Yes — confirmed working on Raspberry Pi OS |

Search: `Alfa Network AWUS036ACS` on Amazon or your local electronics retailer. Any USB WiFi adapter that supports AP mode on Linux will work — this is simply what was used during this build.

### Optional
- **Case with cooling** — the Pi 5 runs warm under load, a heatsink case is recommended
- **USB 3.0 hub** — if adding the 4G dongle and USB adapter simultaneously
- **SIM7600G-H 4G USB dongle** — for cellular uplink in Mode 4 (planned Phase 3)

---
## What it does

SafeHaven Pi runs seven security layers simultaneously the moment you connect:

| Layer | Service | What it does |
|-------|---------|-------------|
| 1 | **hostapd** | Creates a WPA3-encrypted WiFi hotspot |
| 2 | **nftables** | Firewall — blocks and routes all traffic |
| 3 | **WireGuard** | Encrypts all traffic through a VPN tunnel |
| 4 | **Pi-hole** | DNS filter — strips ads, trackers, malware domains |
| 5 | **Suricata** | Intrusion detection — 48,781 threat signatures |
| 5 | **Fail2ban** | Brute force protection — auto-bans repeat attackers |
| 6 | **Cowrie** | SSH honeypot — lures and logs attackers on port 2222 |

---

## Operating Modes

### Mode 1 — Traveler ✅ Complete
For anyone using public WiFi. Encrypts all traffic through WireGuard, filters DNS through Pi-hole, monitors for intrusions with Suricata. Connect and you're protected.

### Mode 2 — Activist / Journalist ✅ Complete
Privacy-first configuration. Adds Tor routing, enables zero-log DNS, and clears all traffic logs on activation. Two sub-options: Tor only (maximum anonymity) or Tor over WireGuard (double layer protection). For situations where source protection is critical.

### Mode 3 — Business ✅ Complete
Secure temporary LAN for conferences or remote work. Includes a captive portal login (`/portal`) where each user authenticates with their own credentials, a post-login status page showing their VPN session, and an admin management panel (`/admin/users`) for creating users, kicking live connections, and viewing aggregate stats. End-user sessions and admin sessions are separated so admin credentials are never exposed to captive-portal users. Mode 3 activation also gates the main Pi monitoring dashboard behind admin login. (Real per-user WireGuard provisioning and kernel-level traffic isolation are scoped for a future release.)

### Mode 4 — Relaxed ✅ Complete
Full security stack without VPN. Pi-hole DNS filtering, nftables firewall, Suricata IDS, Fail2ban and Cowrie all remain active. WireGuard is disabled so sites that block known VPN IP ranges (e.g. Cloudflare-protected sites) remain accessible. Use when normal browsing is being interrupted by VPN detection.

---

## Dashboard

The Flask web dashboard is accessible at `https://10.42.0.1:5000` (self-signed certificate) on any device connected to the SafeHaven hotspot.

**Pi monitoring dashboard** — the main view:
- Threats blocked (live from Suricata)
- DNS queries blocked % (Pi-hole v6 API)
- Connected clients (dnsmasq + WireGuard)
- VPN uptime and peer count
- CPU / RAM gauges
- Network speed graph (live)
- Threats per hour chart (last 24h)

**Admin login** — the dashboard is gated behind `/login` when the Pi is in Business Mode. In single-user modes (Traveler / Activist / Relaxed) the dashboard loads without authentication, since anyone on the hotspot is implicitly the admin.

**Business Mode captive portal** — a separate login page at `/portal` for end users connecting in Mode 3. Authenticates against a dedicated business-user database (hashed passwords in `/etc/safehaven/business-users.json`), completely isolated from the admin credential store.

**Business Mode admin panel** — at `/admin/users`, reachable from the dashboard header in Business Mode. Manages business users: create, edit, delete, and kick live sessions. Shows live counts of connected users, total users, data throughput, and Pi uptime.

**First run:** configure the admin password with `sudo python3 app.py --set-admin-password` before starting the dashboard. Generate the self-signed certificate with:
```bash
sudo mkdir -p /etc/safehaven/ssl
sudo openssl req -x509 -newkey rsa:4096 -nodes \
  -keyout /etc/safehaven/ssl/key.pem \
  -out /etc/safehaven/ssl/cert.pem \
  -days 365 -subj "/CN=SafeHaven-Pi/O=SafeHaven/C=GB"
sudo chmod 600 /etc/safehaven/ssl/key.pem
```

---

## Requirements

- Raspberry Pi 5 (recommended) or Pi 4
- Two network interfaces (built-in WiFi + USB adapter, or built-in + ethernet)
- Raspberry Pi OS (64-bit, Bookworm)
- Internet connection for initial setup

---

## Project Structure

```
SafeHaven-PI/
├── install.sh                   ← Run once after cloning
├── safehaven.sh                 ← Main control script & menu
├── app.py                       ← Flask dashboard + auth + Business Mode API
├── safehaven-dashboard.html     ← Pi monitoring dashboard (main view)
├── login.html                   ← Admin login page (Hexgrid Field design)
├── portal.html                  ← Captive portal login (end-user facing)
├── portal-connected.html        ← Post-login VPN status page for portal users
├── business-admin.html          ← Admin panel for managing business users
├── assets/
│   ├── safehaven_logo.png       ← Project logo
│   └── screenshots/             ← Screenshots for documentation
├── configs/                     ← Service configuration templates
│   ├── hostapd.conf
│   ├── dnsmasq.conf
│   ├── wg0.conf                 ← Template only — real keys never committed
│   ├── torrc                    ← Transparent proxy config for Mode 2
│   └── nftables-mode2.conf      ← Tor redirect rules
├── _teammate-originals/         ← Pristine versions of contributed HTML
├── README.md                    ← This file
├── KNOWN_ISSUES.md              ← Honest list of v1 limitations
├── TROUBLESHOOTING.md           ← Symptom → fix playbook
├── CHANGELOG.md                 ← Release notes
├── CONTRIBUTING.md              ← Contribution guidelines
├── SECURITY.md                  ← Responsible disclosure
└── LICENSE                      ← GPL v3
```

**Runtime files written to the system** (not in the repo, never committed):

```
/etc/safehaven/auth.json              ← Hashed admin credentials
/etc/safehaven/business-users.json    ← Hashed business-user credentials
/etc/safehaven/secret.key             ← Flask session key
/etc/safehaven/ssl/cert.pem           ← HTTPS certificate
/etc/safehaven/ssl/key.pem            ← HTTPS private key
/tmp/safehaven-mode                   ← Current active mode (for auth gate)
/var/lib/safehaven/.first-run         ← Marker to skip boot animation
```

---

## Built With

- [WireGuard](https://www.wireguard.com/) — VPN
- [Pi-hole](https://pi-hole.net/) — DNS filtering
- [Suricata](https://suricata.io/) — Intrusion detection
- [Fail2ban](https://www.fail2ban.org/) — Brute force protection
- [Cowrie](https://github.com/cowrie/cowrie) — SSH honeypot
- [Flask](https://flask.palletsprojects.com/) — Dashboard
- [Tailscale](https://tailscale.com/) — Remote admin access

---

## Documentation

- [`KNOWN_ISSUES.md`](KNOWN_ISSUES.md) — limitations in v1 (by design vs. acknowledged debt)
- [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) — common problems and fixes
- [`CHANGELOG.md`](CHANGELOG.md) — release history
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — how to contribute (despite the time-capsule lock)
- [`SECURITY.md`](SECURITY.md) — responsible disclosure

---

## Academic Context

SafeHaven Pi is a final-year project for BSc Computer Networks and Cybersecurity at UWTSD (2025–2026), submitted as part of the ACCB6019 Emerging Trends module.

---

## Licence

GPL v3 — open source, free to use, modify, and distribute.

This project is licensed under the [GNU General Public License v3.0](https://www.gnu.org/licenses/gpl-3.0.en.html) — you are free to use, modify, and distribute this software under the same licence terms. See the full [LICENSE](LICENSE) file for details.

### What does this mean in plain terms?

If you don't want to read the full licence, here's what GPL v3 means for this project:

**No warranty, no liability (Sections 15 & 16)**
SafeHaven Pi is provided "as is" with no warranty of any kind. If you use this software and something goes wrong, that is your responsibility — not the authors'.

**No responsibility for misuse**
This software was built as a defensive privacy and security tool — a VPN, firewall, and intrusion detection system designed to protect people. If someone chooses to take this code and use it for malicious or unlawful purposes, liability falls entirely on them, not on the original authors. We built this for good. What others choose to do with it is their decision and their consequence.

**Copyleft protection**
If anyone takes this code, modifies it, and distributes their version, they must also release it under the GPL v3 licence. You cannot take this open-source project, put it behind a paywall, make it proprietary, or charge for access to the code. It must remain free and open source — forever.

**Attribution**
Anyone who uses or distributes this code must keep the original copyright notice and licence intact. You cannot strip the authors' names from it or claim it as your own work. You are welcome to reference, fork, and build upon this project — but credit must remain where it belongs.

- [Read the full GPL v3 licence](https://www.gnu.org/licenses/gpl-3.0.en.html)
- [GitHub Repository](https://github.com/MursheenDurkin/SafeHaven-PI)


---

## A Personal Note

This is my first ever major project on GitHub.

I've created small things here before — little scripts, fun experiments, things that never really went anywhere. But nothing like this. SafeHaven Pi is the first time I've built something from the ground up that actually does something meaningful, something I'm genuinely proud of.

If you've made it this far — thank you for reading. Whether you're a lecturer, a fellow student, a developer who stumbled across this, or just someone curious about privacy and security — I hope this has been interesting to look through.

This is a completely open source project. If you like what you see here and want to improve it, add features, fix things, take it in a different direction — please do. Fork it, build on it, make it better. And if you do, I'd genuinely love to see what you create. Share it with me.

---

### 🔒 Time Capsule Notice

**This repository is now locked.**

What you see here is the final state of SafeHaven Pi v1.0-alpha — the version built as part of my final year BSc Computer Networks and Cybersecurity project at UWTSD in 2026. No further code will be pushed to this repository. It will stay exactly as it is, forever.

Think of it as a time capsule. A snapshot of what one person built, with the tools available, in the time available, for the first time.

If a second version of SafeHaven Pi ever exists, it will live in a new repository. But this one — this is where it started.

---

*Built with curiosity, coffee, late nights, and a lot of terminals.*
*— Durkin*
