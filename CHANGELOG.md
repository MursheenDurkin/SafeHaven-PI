# Changelog

All notable changes to SafeHaven Pi are documented here.

---

## [1.0-alpha] — March 2026

### First public release — built as part of BSc Computer Networks and Cybersecurity, UWTSD 2026

### Added
- 7-layer animated boot sequence with per-service status indicators
- Interactive security control menu with live system stats
- Full SAFEHAVEN ASCII logo on boot and control menu
- Three operating modes — Traveler (complete), Activist and Business (in progress)
- Live security log viewer — Suricata, Fail2ban, Cowrie, Pi-hole, WireGuard, system journal
- WireGuard QR code generator for adding devices to the VPN
- Pi-hole DNS block statistics view
- `--version`, `--status` and `--help` command line flags
- Last threat detected and domains blocked today in the status panel
- Safe configuration templates with `<CHANGE_THIS>` placeholders
- One-command installer covering all 7 security layers
- GPL v3 open source licence

### Security stack
- hostapd — WiFi access point
- dnsmasq — DHCP and DNS
- nftables — firewall and NAT
- WireGuard — VPN encryption
- Pi-hole — DNS filtering and ad blocking
- Suricata — intrusion detection (48,781 signatures)
- Fail2ban — brute force protection
- Cowrie — SSH honeypot
- Tailscale — remote management

---

## What's coming in v2.0

- DNS leak protection via nftables DNAT rule
- SSH restricted to eth0 only
- Flask HTTPS dashboard with self-signed certificate
- Fail2ban + Suricata integration — auto-ban Priority 1 threat IPs
- Captive portal pre-flight check for hotels and airports
- Full Tor routing for Activist Mode
- Per-device traffic isolation for Business Mode
