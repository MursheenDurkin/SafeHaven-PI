# Changelog

All notable changes to SafeHaven Pi are documented here.

---

## [1.0-alpha] — May 2026

First public release. Built for the Emerging Trends hackathon (module
ACCB6019) at UWTSD, May 2026 — BSc Computer Networks and Cybersecurity
programme.

The exact state submitted to the hackathon is preserved in git as the
`v1.0-alpha-submission` tag, so anyone can always check out the original
snapshot. The project itself continues to be maintained as a personal
project — see `CONTRIBUTING.md` for how to file issues, fork, or
contribute fixes.

### Added — Core platform

- Animated 7-layer boot sequence with per-service status indicators
- Interactive security control menu with live system stats
- Full SAFEHAVEN ASCII logo on boot and control menu
- Responsive layout — wide block-font on terminals ≥80 cols, mobile
  layout on narrower screens (Termux on phones)
- Setup Wizard for first-run configuration: hotspot SSID + password,
  Pi hostname, admin password, WireGuard keypair generation
- Factory reset option `[f]` and `--factory-reset` CLI flag
- Reboot `[r]` and shutdown `[x]` options with confirmation prompts
- `--version`, `--status` and `--help` command-line flags
- Last-threat-detected and domains-blocked-today panels in the
  status view
- One-command installer covering all dependencies and services
- GPL v3 open-source licence

### Added — Operating modes

- **Mode 1 — Traveler.** Everyday public-WiFi protection. WireGuard
  tunnel, Pi-hole DNS filtering, Suricata intrusion detection, Fail2ban
  auto-banning, Cowrie SSH honeypot.
- **Mode 2 — Activist / Journalist.** Privacy-first configuration.
  Tor transparent proxy with two sub-options (Tor only, or Tor over
  WireGuard for double-layer protection). Zero-log DNS, traffic logs
  suppressed on activation.
- **Mode 3 — Business.** Captive portal LAN with per-user login,
  admin management panel, live session tracking, and graceful
  disconnect / kick. Mode-aware authentication isolates admin
  credentials from end-user credentials.
- **Mode 4 — Relaxed.** Full security stack with WireGuard disabled,
  for sites that block known VPN IP ranges.

### Added — VPN device manager (`[6] Manage VPN Devices`)

- Full add / list / edit / remove lifecycle for WireGuard peers
- **Add Device** generates a fresh keypair per device, allocates the
  next free IP from the live `wg0` subnet, and QR-encodes a client
  config for scanning. The client's private key is never written to
  disk on the Pi — once the QR is dismissed it's gone, exactly the
  one-time-use property a real VPN provider gives you.
- **List Devices** joins the per-device metadata file with live
  state from `wg show wg0 dump` to display handshake age, bytes
  transferred, and the endpoint each connected device joined from.
- **Edit Device Name** lets admins rename tracked devices without
  touching the WireGuard configuration.
- **Remove Device** atomically removes a peer from the running
  WireGuard interface, persists the change to `wg0.conf`, and cleans
  up the metadata file.
- Untracked peers (added by `wg set` directly or imported from a
  manually-edited config) are flagged in the list with a `⚠` warning
  but continue to function normally.
- Mobile-friendly vertical card layout for narrow terminals.
- Per-device metadata stored in `/etc/safehaven/wg-devices.json` —
  name, public key, IP, timestamp; never the private key.

### Added — Web dashboard

- HTTPS dashboard at `https://10.42.0.1:5000` with self-signed
  certificate
- Live counters — threats blocked, DNS queries filtered, connected
  clients, VPN uptime, CPU / RAM gauges, network-speed graph,
  threats-per-hour chart
- Admin login (`/login`) gating the dashboard in Business Mode; open
  access in single-user modes (Traveler / Activist / Relaxed)
- Business Mode captive portal at `/portal` for end-user login
- Business Mode admin panel at `/admin/users` for managing business
  users (create, edit, delete, kick live sessions)
- Auto-start on boot via `safehaven-dashboard.service` systemd unit
- Mobile breakpoints — 768 px tablet, 480 px phone
- Admin login error parameters cleared from the URL after a failed
  attempt
- Avatar / nav consistency across dashboard pages

### Added — Live log viewer (`[5]`)

- Real-time tail of Suricata, Fail2ban, Cowrie, Pi-hole, and
  WireGuard logs
- System journal viewer for general-purpose troubleshooting

### Added — System hygiene and infrastructure

- Self-healing wlan1 hotspot recovery — udev rule + systemd service
  + NetworkManager unmanaged-devices configuration, so a USB cable
  wiggle no longer requires a reboot
- Dedicated `safehaven-wlan1-ip.service` for assigning the gateway
  IP on hot-plug, with delay tuning to wait for driver init
- Dedicated `ip-forward.service` for enabling `net.ipv4.ip_forward=1`
  on boot (Pi OS Bookworm doesn't honour `sysctl.conf` reliably for
  this)
- `dnsmasq.conf` template includes `port=0` to coexist cleanly with
  Pi-hole on port 53
- Logrotate configuration for Suricata, Fail2ban, and Tor logs
- `.gitattributes` enforces LF line endings cross-platform so files
  shipped via `scp` from a Windows working tree work on the Pi

### Security stack (8 layers)

- **hostapd** — WPA2 hotspot on wlan1
- **WireGuard** — VPN tunnel terminating on the Pi (10.8.0.0/24)
- **Pi-hole v6** — DNS filtering with ~81,000-domain blocklist
- **nftables** — firewall, NAT (MASQUERADE out wlan0), DNS DNAT
  intercept, Fail2ban ban set
- **Suricata** — intrusion detection with ~48,000 signatures
- **Fail2ban** — auto-bans Priority 1 / 2 alert IPs for 24 hours via
  nftables
- **Cowrie** — SSH honeypot on port 2222
- **Tailscale** — remote admin access

### Fixed during pre-release review

- VPN device add-flow no longer QR-encodes the server's private key.
  The original implementation broadcast the Pi's keypair to every
  scanning device; rebuilt during pre-release with per-device fresh
  keypairs (see commit history).
- Mode activation no longer prints a false-alarm "check wg0.conf"
  warning when wg0 is already up — short-circuits the check before
  attempting `wg-quick up`.
- Mode activations now run `systemctl restart nftables` instead of
  just `start`, so previous-mode rules are flushed before the new
  mode is applied.
- Mobile layout threshold lowered so default 80-column Pi terminals
  get the wide block-font logo.
- Cowrie removed from logrotate (it manages its own rotation).

### Documentation

- `README.md` — quick start, mode reference, dashboard overview,
  hardware guide, control-menu section
- `KNOWN_ISSUES.md` — honest list of v1 limitations, split into
  "by design" vs "acknowledged debt"
- `TROUBLESHOOTING.md` — symptom-to-fix playbook for common issues
- `CONTRIBUTING.md` — maintenance policy and fork-and-extend
  guidance
- `SECURITY.md` — responsible-disclosure framing, GPL v3 fork-and-fix
  model

---

This entry covers the project as it shipped to the hackathon.
Maintenance and improvements continue past this point — future
entries in this CHANGELOG will record what comes next.

Forks are welcome — fork the code, take it in whatever direction
makes sense for you, and please do share what you build with it.
Bug fixes and small contributions back to this repo are welcome
too — see `CONTRIBUTING.md` for the maintenance policy.
