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
