# Contributing

SafeHaven Pi is open source and contributions are welcome.

If you've improved something, fixed a bug, added a feature, or just have an idea — please share it.

---

## ⚠️ Important — this repository is time-capsule locked

This repository represents **SafeHaven Pi v1.0-alpha**, the version submitted as a final-year project at UWTSD in 2026. **No further code will be merged into this repository.**

What that means for you:

- 🟢 **Forks are welcome.** Take this code, build on it, take it in your own direction, run with it.
- 🟢 **Issues are welcome.** Bug reports, design discussions, questions, ideas — all welcome on the issue tracker.
- 🔴 **Pull requests against this repo will not be merged.** This isn't because we don't appreciate the effort — it's because v1.0-alpha is preserved as a snapshot.

If a v2 of SafeHaven Pi ever exists, it will live in a separate repository and accept PRs there.

---

## Reading the code first

Before making changes, the best background reading is:

- [`README.md`](README.md) — what the project does and how it's structured
- [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) — known failure modes and their fixes
- [`KNOWN_ISSUES.md`](KNOWN_ISSUES.md) — limitations of v1 (by design vs. acknowledged debt)

If you're hitting a problem, check those first — many "bugs" are actually documented behaviour.

---

## How to fork and build on this

1. **Fork** the repository on GitHub
2. **Clone your fork** locally
3. **Create a branch** for your changes: `git checkout -b feature/your-idea`
4. **Make and test** your changes on a real Raspberry Pi
5. **Commit** with a conventional message (see below)
6. **Push** to your fork: `git push origin feature/your-idea`
7. **Document** what you've done in your fork's README so others can find it

If your fork takes the project in a meaningfully new direction, it's nice (but not required) to mention this repository as the origin.

---

## Commit message conventions

This project uses a lightweight prefix convention you can follow if you want consistency in your fork:

| Prefix | When to use | Example |
|--------|-------------|---------|
| `feat:` | New user-visible feature | `feat: add factory reset option` |
| `fix:` | Bug fix | `fix: dnsmasq port=0 to avoid Pi-hole conflict` |
| `docs:` | Documentation changes only | `docs: clarify Mode 2 sub-options` |
| `chore:` | Tidy-up / housekeeping | `chore: harden .gitignore` |
| `refactor:` | Code change with no behaviour change | `refactor: extract auth helpers from app.py` |

---

## Areas a v2 (or your fork) might explore

The areas where the project has obvious room to grow:

- **Real per-user WireGuard provisioning** in Business Mode (currently uses a mock traffic layer)
- **Kernel-level traffic isolation** between connected users
- **Cellular uplink support** (SIM7600G-H or similar) for true portability
- **Native mobile companion app** (today's mobile UX is browser + Termux SSH)
- **Multi-admin support** with role-based access control
- **Tor bridge support** (obfs4 / snowflake) for environments where Tor itself is blocked
- **Full-disk encryption** on the SD card with boot-time unlock
- **Reproducible builds** with signed release artefacts
- **Mesh / fleet mode** for coordinated deployments across multiple Pis
- **Internationalisation** of the menu and dashboard

See `KNOWN_ISSUES.md` for the full list of v1 limitations.

---

## Code style and guidelines

- **Keep it accessible** — this project is designed for non-technical users to install and use
- **Test on real hardware** — Pi 5 is the primary target, Pi 4 (4GB / 8GB) is supported
- **Plain English comments** — assume your reader is a fellow student, not a kernel engineer
- **No real credentials in git** — all configs use `<CHANGE_THIS>` or template placeholders
- **Update documentation** when you change behaviour — README, TROUBLESHOOTING, or KNOWN_ISSUES as appropriate
- **Respect GPL v3** — derivatives must remain GPL v3, attribution preserved

---

## Reporting bugs

For non-security bugs:
- Open a GitHub issue with a clear description
- Include the relevant log output
- State what you expected vs. what happened
- Mention your Pi model and OS version

For **security** vulnerabilities, see [`SECURITY.md`](SECURITY.md) — please don't file public issues for those.

---

## Questions or ideas?

Open an issue on GitHub and let's talk. All ideas are welcome, no matter how small.

*Built with curiosity, coffee, late nights, and a lot of terminals.*
*— Durkin*
