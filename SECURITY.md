# Security Policy

This document explains the security posture of SafeHaven Pi v1.0-alpha and what to do if you find a vulnerability.

---

## ⚠️ Project status — important to read first

SafeHaven Pi is a **time-capsule academic release, locked at v1.0-alpha**. The project was built for the Emerging Trends hackathon (module ACCB6019) at UWTSD and submitted in May 2026; after submission the repository receives no further commits. This is by design — the repository is preserved as a snapshot of the version that was submitted.

What this means for security:

- **No patches will be issued for this repository.** Not because vulnerabilities don't matter, but because there is no maintainer actively shipping fixes here.
- **Confirmed vulnerabilities will be documented**, not silently ignored. They get added to `KNOWN_ISSUES.md` with mitigation guidance so users know what to avoid.
- **The code is GPL v3, open source.** If you find a bug, you have every right (and the licence permits it) to fork the repository and ship a fix to your own users.

This is the honest position. Unlike commercial software with an SLA, an unmaintained open-source project transfers the patching responsibility to its users. That's how the licence is designed.

---

## What you can do

### If you find a vulnerability

You have three good options:

1. **Report it for awareness.** Use GitHub's *Security* tab → *Report a vulnerability* (private advisory). This won't get patched here, but documenting it helps anyone running this code understand the risk and apply mitigations.
2. **Fork the repository and fix it yourself.** GPL v3 protects your right to do this. Your fork can be maintained, accept patches, and ship updates to your users.
3. **Both.** Report it for awareness AND share your fork link in the report so other users can find your patched version.

### How to report

From the repository page on GitHub:
**Security tab → Report a vulnerability**

This creates a private advisory only the maintainer can see. Public issues should not be used for vulnerability reports.

Include:
- A clear description
- The affected component (`safehaven.sh`, `app.py`, captive portal, etc.)
- Reproduction steps
- The realistic impact
- A link to your fork if you've already patched it

### What happens after you report

Realistic expectations:

- The report **will be acknowledged** when seen, not on a guaranteed timeline
- The vulnerability **will be added to KNOWN_ISSUES.md** if confirmed
- The advisory **will be made public** so users know to mitigate or migrate
- The code in this repository **will not be modified** — it stays locked

If you want a fix to ship to users, the fastest path is your own fork.

---

## Why this approach

Software has bugs. All software. Including SafeHaven Pi. The questions for any unmaintained project are:

1. Are users told honestly that it's unmaintained? (Yes — see this doc and the README's Time Capsule Notice)
2. Can users see the source to assess and mitigate risks themselves? (Yes — GPL v3, open repository)
3. Can users fork and patch? (Yes — that's what open source is for)
4. Are known issues documented honestly? (Yes — see KNOWN_ISSUES.md)

Pretending otherwise — promising patches that won't come, keeping vulnerabilities quiet to preserve a sense of "complete" — does more damage than admitting the project's status clearly.

This is the same model as countless older open-source projects: the original author moves on, the code remains useful, and the community (whoever that turns out to be) maintains forks for as long as the underlying need exists.

---

## Scope

### ✅ In scope (vulnerabilities worth reporting)

- The SafeHaven Pi shell scripts (`safehaven.sh`, `install.sh`)
- The Flask backend (`app.py`) and authentication layer
- Configuration templates in `configs/`
- The captive portal and admin panel HTML files
- Documentation that could mislead users into an insecure state

### ❌ Out of scope (report upstream — those projects are actively maintained)

These are external projects SafeHaven Pi integrates but does not maintain. Vulnerabilities in them should be reported to their own maintainers:

- **WireGuard** — [wireguard.com/contact](https://www.wireguard.com/contact/)
- **Pi-hole** — [pi-hole.net](https://pi-hole.net/)
- **Suricata** — [Open Information Security Foundation](https://oisf.net/)
- **Fail2ban** — [github.com/fail2ban/fail2ban](https://github.com/fail2ban/fail2ban)
- **Cowrie** — [github.com/cowrie/cowrie](https://github.com/cowrie/cowrie)
- **nftables** — [netfilter.org](https://www.netfilter.org/)
- **Tailscale** — [tailscale.com/security](https://tailscale.com/security)
- **Flask** / **Werkzeug** — [github.com/pallets/flask](https://github.com/pallets/flask)
- **Raspberry Pi OS** — [raspberrypi.com](https://www.raspberrypi.com/)

If you find a vulnerability in *how SafeHaven Pi uses* one of these tools (insecure default config, missing access control around them), that IS in scope here.

---

## Safe harbour

If you research and report a vulnerability in good faith following these guidelines:

- We will not pursue legal action
- We will credit you in the disclosure (if you wish)
- We will work with you on disclosure timing where it matters

What "good faith" means:

- Don't access, modify, or destroy data that isn't yours
- Don't run denial-of-service attacks against deployed instances
- Don't disclose publicly before the maintainer has had a reasonable chance to respond
- Don't exfiltrate data — proof of concept is enough

---

## Credentials policy

This repository contains **only template configuration** with placeholder values such as `<CHANGE_THIS>`, `<your-username>`, and `<your-tailscale-ip>`. **No real credentials, private keys, or passwords should ever be committed.**

The Setup Wizard (menu option `[w]`) is the intended way to configure a Pi — every value generated is written to `/etc/safehaven/` on the device only and never enters the git history.

If you find anything that looks like a real credential committed to this repository (current state OR git history), please report it immediately as a vulnerability — we'd want to know even if patches aren't shipping, so the disclosure can warn other users.

---

## Hardening recommendations for users running this code

While these aren't vulnerabilities in the traditional sense, anyone running SafeHaven Pi should know:

- **The SD card is unencrypted by default.** Anyone with physical access can read configs, hashes, and keys
- **The admin password is the primary credential** — set a strong one with `sudo python3 app.py --set-admin-password`
- **The HTTPS certificate is self-signed.** Browsers warn — that's normal — but verify the certificate fingerprint matches the one on your Pi if you suspect tampering
- **WireGuard private keys are sensitive.** If your Pi is lost, stolen, or sold, regenerate them via the Setup Wizard
- **Tor exit nodes (Mode 2) can observe unencrypted traffic.** This is a property of Tor, not a SafeHaven bug — but use Mode 2 with that understanding
- **Threat signatures don't auto-update.** Manual refresh required (`sudo suricata-update`) for current detection coverage. See KNOWN_ISSUES.md for context

If you're running this code in a higher-risk setting and want active patches, **fork it and maintain your fork** — that's the model the licence is built for.

---

## Acknowledgements

Anyone who responsibly discloses a valid vulnerability will be acknowledged here (with their consent).

*No vulnerabilities reported at the time of v1.0-alpha submission.*
