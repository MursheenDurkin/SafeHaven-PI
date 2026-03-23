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
ssh durkin@<your-tailscale-ip>
```

Your Pi's Tailscale IP is shown in the boot screen — or run `tailscale status` on the Pi to find it.

**4. Launch the menu**
```bash
cd /home/durkin/SafeHaven-PI && sudo bash safehaven.sh
```

The menu automatically detects your screen width and switches to a mobile-optimised layout on narrow screens.

> ⚠️ **Before making this repository public or sharing your setup:**
> Check your config files and remove any personal credentials.
> The `configs/` folder contains templates — never commit real passwords,
> WiFi credentials, or WireGuard private keys to GitHub.



---

## What it looks like when you run it

### Step 1 — Boot sequence
Every security layer starts up one by one. You can watch each service come online in real time before the menu loads.

![Boot sequence](assets/screenshots/boot.png)

---

### Step 2 — Control menu
Once everything is running, the control menu loads automatically. Every service is shown live — green means running, the stats bar shows CPU, RAM, uptime, VPN clients and IDS signatures loaded.

![Main control menu](assets/screenshots/menu.png)

---

### Step 3 — Activating a mode
Press `1` to activate Traveler Mode. Each security layer starts in sequence and confirms when it's up. Once all layers are active it tells you you're protected.

![Mode 1 — Traveler Mode](assets/screenshots/mode1.png)

---

### Step 4 — Live log viewer
Press `4` from the menu to open the log viewer. Choose any service — Suricata, Fail2ban, Cowrie, Pi-hole or WireGuard — and watch live traffic and threat detections in real time. These are all live feeds, not simulated output.

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

### Mode 2 — Activist / Journalist 🚧 In Progress
Privacy-first configuration. Adds Tor routing, enables zero-log DNS, and disables all traffic logging. For situations where source protection is critical.

### Mode 3 — Business 🚧 Planned
Secure temporary LAN for conferences or remote work. Adds multi-client traffic isolation and a business-focused dashboard view.

---

## Dashboard

The Flask web dashboard is accessible at `http://10.42.0.1:5000` on any device connected to the SafeHaven hotspot. It shows:

- Threats blocked (live from Suricata)
- DNS queries blocked % (Pi-hole API)
- Connected clients (dnsmasq + WireGuard)
- VPN uptime
- CPU / RAM gauges
- Network speed graph
- Threats per hour chart

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
├── install.sh              ← Run once after cloning
├── safehaven.sh            ← Main startup script
├── assets/
│   ├── safehaven_logo.png  ← Project logo
│   └── screenshots/        ← Screenshots for documentation
├── scripts/
│   └── safehaven_menu.sh   ← Control menu
├── configs/                ← Service configuration files
└── dashboard/              ← Flask web dashboard
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

## Academic Context

SafeHaven Pi is a final-year project for BSc Computer Networks and Cybersecurity at UWTSD (2025–2026), submitted as part of the ACCB6019 Emerging Trends module.

---

## Licence

GPL v3 — open source, free to use, modify, and distribute.

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
