#!/usr/bin/env python3
import json, os, random, re, subprocess, sys, time, secrets, getpass
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from functools import wraps
from urllib.parse import quote
import requests
from flask import Flask, jsonify, request, redirect, session, url_for
from flask_cors import CORS
from werkzeug.security import generate_password_hash, check_password_hash

HOTSPOT_IFACE     = "wlan1"
UPSTREAM_IFACE    = "wlan0"
WG_IFACE          = "wg0"
PIHOLE_API        = "http://localhost/api"
PIHOLE_CREDS_FILE = "/etc/pihole/cli_pw"
EVE_JSON          = "/var/log/suricata/eve.json"
COWRIE_LOG        = "/home/cowrie/cowrie/var/log/cowrie/cowrie.json"
FLASK_PORT        = 5000

# ── Authentication ──────────────────────────────────────────
AUTH_FILE             = "/etc/safehaven/auth.json"
SECRET_KEY_FILE       = "/etc/safehaven/secret.key"
BUSINESS_USERS_FILE   = "/etc/safehaven/business-users.json"
MODE_FILE             = "/tmp/safehaven-mode"
SESSION_HOURS         = 12
PUBLIC_PATHS          = {"/login", "/logout", "/health", "/api/mode"}
# Which mode numbers require dashboard authentication.
# Single-user modes (Traveler/Activist/Relaxed) trust anyone on the hotspot.
# Business Mode is multi-user so admin access must be gated.
AUTH_REQUIRED_MODES   = {3}
# Captive-portal routes — only active in Business Mode
PORTAL_PATHS_OPEN     = {"/portal", "/portal/login"}                     # accessible without a portal session
PORTAL_PATHS_SESSION  = {"/portal/connected", "/portal/api/status",
                         "/portal/api/disconnect"}                         # require portal session
# In-memory state for currently-connected portal users (resets on Flask restart).
# username -> {connected_since, client_ip, downloaded_bytes, uploaded_bytes}
_portal_sessions      = {}

def load_or_create_secret_key():
    """Load persistent Flask secret key; create it on first run."""
    try:
        if os.path.exists(SECRET_KEY_FILE):
            with open(SECRET_KEY_FILE, "rb") as f:
                key = f.read().strip()
                if key:
                    return key
        key = secrets.token_bytes(32)
        os.makedirs(os.path.dirname(SECRET_KEY_FILE), exist_ok=True)
        with open(SECRET_KEY_FILE, "wb") as f:
            f.write(key)
        os.chmod(SECRET_KEY_FILE, 0o600)
        return key
    except PermissionError:
        # Fall back to ephemeral key if we can't write (e.g. not root).
        # Sessions won't survive restart but the app still runs.
        return secrets.token_bytes(32)

app = Flask(__name__, static_folder='.')
app.secret_key = load_or_create_secret_key()
app.permanent_session_lifetime = timedelta(hours=SESSION_HOURS)
CORS(app, supports_credentials=True)

def run(cmd, timeout=5):
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return r.stdout.strip()
    except:
        return ""

def safe_json_lines(filepath, max_lines=5000):
    if not os.path.exists(filepath):
        return []
    try:
        raw = subprocess.run(f"tail -n {max_lines} {filepath}", shell=True, capture_output=True, text=True, timeout=5).stdout.splitlines()
        parsed = []
        for line in raw:
            line = line.strip()
            if line:
                try:
                    parsed.append(json.loads(line))
                except:
                    pass
        return parsed
    except:
        return []

def load_admin_credentials():
    """Load hashed admin credentials from the auth file; None if unset."""
    if not os.path.exists(AUTH_FILE):
        return None
    try:
        with open(AUTH_FILE) as f:
            return json.load(f)
    except Exception:
        return None

def check_admin_credentials(username, password):
    """Verify a username/password pair against the stored hash."""
    creds = load_admin_credentials()
    if not creds:
        return False
    return (creds.get("username") == username and
            check_password_hash(creds.get("password_hash", ""), password))

def set_admin_password_interactive():
    """CLI: python3 app.py --set-admin-password"""
    print("\n  SafeHaven Pi — Set admin credentials for the dashboard\n")
    username = input("  Username [admin]: ").strip() or "admin"
    while True:
        pw1 = getpass.getpass("  Password (min 8 chars): ")
        if len(pw1) < 8:
            print("  ✗ Too short. Try again.\n")
            continue
        pw2 = getpass.getpass("  Confirm password: ")
        if pw1 != pw2:
            print("  ✗ Passwords don't match. Try again.\n")
            continue
        break
    try:
        os.makedirs(os.path.dirname(AUTH_FILE), exist_ok=True)
        with open(AUTH_FILE, "w") as f:
            json.dump({
                "username": username,
                "password_hash": generate_password_hash(pw1),
                "created_at": datetime.now().isoformat(timespec="seconds"),
            }, f, indent=2)
        os.chmod(AUTH_FILE, 0o600)
        print(f"\n  ✓ Credentials written to {AUTH_FILE}")
        print(f"  ✓ Login at https://10.42.0.1:5000/login\n")
    except PermissionError:
        print(f"\n  ✗ Permission denied writing {AUTH_FILE}")
        print(f"    Run with sudo: sudo python3 app.py --set-admin-password\n")
        sys.exit(1)

def get_current_mode():
    """Read the active SafeHaven mode from /tmp/safehaven-mode. Returns int or 0."""
    try:
        if not os.path.exists(MODE_FILE):
            return 0
        with open(MODE_FILE) as f:
            first = f.readline().strip()
        if not first:
            return 0
        mode_num = first.split(":", 1)[0].strip()
        return int(mode_num) if mode_num.isdigit() else 0
    except Exception:
        return 0

def mode_requires_auth():
    """True if the current mode is one that gates the dashboard behind login."""
    return get_current_mode() in AUTH_REQUIRED_MODES

@app.before_request
def require_auth():
    """Gate access by path type and current mode.

    Three path families:
    1. /portal/*   — captive portal for end users (only active in Business Mode)
    2. /admin/*    — business admin panel (requires admin session, Business Mode only)
    3. everything else — the Pi monitoring dashboard (mode-aware auth)
    """
    path = request.path

    # Always allow public routes (login UI, logout, health, mode probe)
    if path in PUBLIC_PATHS:
        return None

    # ── Captive portal routes ─────────────────────────────────
    if path.startswith("/portal"):
        # Portal only exists in Business Mode
        if get_current_mode() != 3:
            if path.startswith("/portal/api/"):
                return jsonify({"ok": False, "error": "Portal inactive — not in Business Mode"}), 404
            return ("<h1>Captive portal inactive</h1>"
                    "<p>SafeHaven Pi is not currently in Business Mode.</p>"), 404

        # Open portal paths (login page, login submit) — no session needed
        if path in PORTAL_PATHS_OPEN:
            return None

        # Session-protected portal paths
        if path in PORTAL_PATHS_SESSION:
            if session.get("portal_user"):
                return None
            if path.startswith("/portal/api/"):
                return jsonify({"ok": False, "error": "Not logged in"}), 401
            return redirect("/portal")

        # Unknown /portal/* path — treat as not-found
        return jsonify({"ok": False, "error": "Not found"}), 404

    # ── Admin and dashboard routes ────────────────────────────
    # If this mode doesn't require admin auth, let everyone through
    if not mode_requires_auth():
        return None

    # Business Mode but no credentials yet — lock the dashboard
    if not load_admin_credentials():
        if path.startswith("/api/") or path.startswith("/admin/api/"):
            return jsonify({
                "ok": False,
                "error": "Dashboard locked — Business Mode requires admin credentials. "
                         "Run: sudo python3 app.py --set-admin-password"
            }), 503
        return ("<h1>Dashboard locked</h1>"
                "<p>Business Mode requires admin credentials.</p>"
                "<p>Run <code>sudo python3 app.py --set-admin-password</code> "
                "on the Pi, then reload.</p>"), 503

    # Already authenticated? Let through.
    if session.get("logged_in"):
        return None

    # API callers get 401 JSON so the dashboard can react gracefully
    if path.startswith("/api/") or path.startswith("/admin/api/"):
        return jsonify({"ok": False, "error": "Authentication required"}), 401

    # Everyone else gets bounced to the login page
    return redirect(url_for("login_page"))

def get_pihole_token():
    try:
        if not os.path.exists(PIHOLE_CREDS_FILE):
            return None
        with open(PIHOLE_CREDS_FILE) as f:
            password = f.read().strip()
        resp = requests.post(f"{PIHOLE_API}/auth", json={"password": password}, timeout=3)
        return resp.json().get("session", {}).get("sid")
    except:
        return None

def pihole_get(endpoint):
    try:
        sid = get_pihole_token()
        if not sid:
            return {}
        resp = requests.get(f"{PIHOLE_API}/{endpoint}", headers={"X-FTL-SID": sid}, timeout=3)
        return resp.json()
    except:
        return {}

def success(data):
    return jsonify({"ok": True, "timestamp": datetime.now().isoformat(), "data": data})

@app.route("/api/status")
def api_status():
    service_map = {
        "hostapd": "hostapd", "pihole": "pihole-FTL",
        "wireguard": f"wg-quick@{WG_IFACE}", "suricata": "suricata",
        "fail2ban": "fail2ban", "cowrie": "cowrie",
        "tailscale": "tailscaled", "nftables": "nftables",
    }
    services = {}
    for name, unit in service_map.items():
        out = run(f"systemctl is-active {unit}")
        services[name] = {"active": out == "active", "status": out or "unknown"}
    core = ["hostapd", "pihole", "wireguard", "suricata", "fail2ban"]
    return success({"services": services, "system_active": all(services[s]["active"] for s in core)})

@app.route("/api/stats")
def api_stats():
    cpu_raw = run("top -bn2 -d0.5 | grep 'Cpu(s)' | tail -1")
    cpu_percent = 0.0
    if cpu_raw:
        m = re.search(r"(\d+\.\d+)\s+id", cpu_raw)
        if m:
            cpu_percent = round(100.0 - float(m.group(1)), 1)
    mem_raw = run("free -m | grep Mem")
    ram_used_mb = ram_total_mb = ram_percent = 0
    if mem_raw:
        parts = mem_raw.split()
        if len(parts) >= 3:
            ram_total_mb = int(parts[1])
            ram_used_mb  = int(parts[2])
            if ram_total_mb > 0:
                ram_percent = round((ram_used_mb / ram_total_mb) * 100, 1)
    uptime_sec = 0
    uptime_human = "unknown"
    uptime_raw = run("cat /proc/uptime")
    if uptime_raw:
        uptime_sec = int(float(uptime_raw.split()[0]))
        d = uptime_sec // 86400
        h = (uptime_sec % 86400) // 3600
        m2 = (uptime_sec % 3600) // 60
        uptime_human = f"{d}d {h}h {m2}m"
    temp_c = None
    temp_raw = run("cat /sys/class/thermal/thermal_zone0/temp")
    if temp_raw and temp_raw.isdigit():
        temp_c = round(int(temp_raw) / 1000, 1)
    load_avg = []
    load_raw = run("cat /proc/loadavg")
    if load_raw:
        load_avg = [float(p) for p in load_raw.split()[:3]]
    return success({"cpu_percent": cpu_percent, "ram_used_mb": ram_used_mb,
                    "ram_total_mb": ram_total_mb, "ram_percent": ram_percent,
                    "uptime_seconds": uptime_sec, "uptime_human": uptime_human,
                    "temperature_c": temp_c, "load_avg": load_avg})

@app.route("/api/pihole")
def api_pihole():
    summary = pihole_get("stats/summary")
    if not summary:
        return success({"queries_today": 0, "blocked_today": 0, "blocked_percent": 0.0,
                        "domains_on_blocklist": 0, "clients_seen": 0, "status": "unknown"})
    queries = summary.get("queries", {})
    total   = queries.get("total", 0)
    blocked = queries.get("blocked", 0)
    percent = round((blocked / total * 100), 1) if total > 0 else 0.0
    return success({"queries_today": total, "blocked_today": blocked, "blocked_percent": percent,
                    "domains_on_blocklist": summary.get("gravity", {}).get("domains_being_blocked", 0),
                    "clients_seen": summary.get("clients", {}).get("active", 0),
                    "status": "enabled" if summary.get("status") != "disabled" else "disabled"})

@app.route("/api/threats")
def api_threats():
    lines = safe_json_lines(EVE_JSON, max_lines=20000)
    alerts_raw = [l for l in lines if l.get("event_type") == "alert"]
    total = len(alerts_raw)
    alerts = []
    for entry in alerts_raw[-50:]:
        a = entry.get("alert", {})
        alerts.append({"timestamp": entry.get("timestamp", ""), "src_ip": entry.get("src_ip", ""),
                        "dest_ip": entry.get("dest_ip", ""), "protocol": entry.get("proto", ""),
                        "signature": a.get("signature", ""), "severity": a.get("severity", 3),
                        "category": a.get("category", "")})
    alerts.reverse()
    return success({"total_alerts": total, "alerts": alerts})

@app.route("/api/threats/hourly")
def api_threats_hourly():
    lines = safe_json_lines(EVE_JSON, max_lines=50000)
    now = datetime.now()
    cutoff = now - timedelta(hours=24)
    hourly = defaultdict(int)
    for entry in lines:
        if entry.get("event_type") != "alert":
            continue
        ts_str = entry.get("timestamp", "")
        try:
            ts = datetime.fromisoformat(ts_str[:19])
            if ts >= cutoff:
                hourly[ts.strftime("%H:00")] += 1
        except:
            pass
    labels, counts = [], []
    for i in range(23, -1, -1):
        h = (now - timedelta(hours=i)).strftime("%H:00")
        labels.append(h)
        counts.append(hourly.get(h, 0))
    return success({"labels": labels, "counts": counts})

@app.route("/api/banned")
def api_banned():
    jails_raw = run("fail2ban-client status 2>/dev/null | grep 'Jail list' | cut -d: -f2")
    jails = [j.strip() for j in jails_raw.split(",") if j.strip()] if jails_raw else []
    banned_ips = []
    for jail in jails:
        raw = run(f"fail2ban-client status {jail} 2>/dev/null")
        if not raw:
            continue
        m = re.search(r"Banned IP list:\s*(.*)", raw)
        if m:
            for ip in m.group(1).strip().split():
                if ip:
                    banned_ips.append({"ip": ip, "jail": jail, "time_remaining": "< 24h"})
    return success({"total_banned": len(banned_ips), "banned_ips": banned_ips})

@app.route("/api/clients")
def api_clients():
    stations_raw = run(f"iw dev {HOTSPOT_IFACE} station dump 2>/dev/null")
    macs = re.findall(r"Station\s+([0-9a-f:]{17})", stations_raw, re.IGNORECASE)
    leases = {}
    lease_file = "/var/lib/misc/dnsmasq.leases"
    if os.path.exists(lease_file):
        with open(lease_file) as f:
            for line in f:
                parts = line.strip().split()
                if len(parts) >= 4:
                    mac = parts[1].upper()
                    leases[mac] = {"ip": parts[2], "hostname": parts[3] if parts[3] != "*" else "unknown"}
    clients = []
    for mac in macs:
        info = leases.get(mac.upper(), {"ip": "unknown", "hostname": "unknown"})
        clients.append({"mac": mac.upper(), **info})
    return success({"total_clients": len(clients), "clients": clients})

@app.route("/api/cowrie")
def api_cowrie():
    lines = safe_json_lines(COWRIE_LOG, max_lines=10000)
    sessions     = [l for l in lines if l.get("eventid") == "cowrie.session.connect"]
    commands     = [l for l in lines if l.get("eventid") == "cowrie.command.input"]
    attacker_ips = {s.get("src_ip") for s in sessions if s.get("src_ip")}
    cmd_by_session = defaultdict(int)
    for c in commands:
        cmd_by_session[c.get("session", "")] += 1
    recent = []
    for s in sessions[-10:]:
        recent.append({"timestamp": s.get("timestamp", "")[:19], "src_ip": s.get("src_ip", ""),
                        "commands": cmd_by_session.get(s.get("session", ""), 0)})
    recent.reverse()
    return success({"total_sessions": len(sessions), "total_commands": len(commands),
                    "unique_attacker_ips": len(attacker_ips), "recent_sessions": recent})

@app.route("/api/network")
def api_network():
    def read_bytes(iface):
        raw = run(f"cat /proc/net/dev | grep {iface}:")
        if not raw:
            return 0, 0
        parts = raw.split()
        try:
            return int(parts[1]), int(parts[9])
        except:
            return 0, 0
    rx1, tx1 = read_bytes(UPSTREAM_IFACE)
    time.sleep(0.5)
    rx2, tx2 = read_bytes(UPSTREAM_IFACE)
    dl_bps = max(0, (rx2 - rx1) * 2)
    ul_bps = max(0, (tx2 - tx1) * 2)
    return success({"download_bps": dl_bps, "upload_bps": ul_bps,
                    "download_mbps": round(dl_bps / 1_000_000, 2),
                    "upload_mbps": round(ul_bps / 1_000_000, 2), "iface": UPSTREAM_IFACE})

@app.route("/api/vpn")
def api_vpn():
    wg_check = run(f"ip link show {WG_IFACE} 2>/dev/null")
    if not wg_check:
        return success({"active": False, "uptime_seconds": 0, "uptime_human": "0d 0h 0m",
                        "peer_count": 0, "peers": []})
    uptime_raw = run(f"systemctl show wg-quick@{WG_IFACE} --property=ActiveEnterTimestamp 2>/dev/null")
    uptime_sec = 0
    uptime_human = "unknown"
    if uptime_raw and "=" in uptime_raw:
        ts_str = uptime_raw.split("=", 1)[1].strip()
        try:
            parts = ts_str.split()
            if len(parts) >= 3:
                dt = datetime.strptime(f"{parts[1]} {parts[2]}", "%Y-%m-%d %H:%M:%S")
                uptime_sec = int((datetime.now() - dt).total_seconds())
                d = uptime_sec // 86400
                h = (uptime_sec % 86400) // 3600
                m = (uptime_sec % 3600) // 60
                uptime_human = f"{d}d {h}h {m}m"
        except:
            pass
    wg_raw = run(f"wg show {WG_IFACE} 2>/dev/null")
    peers = []
    if wg_raw:
        current_peer = {}
        for line in wg_raw.splitlines():
            line = line.strip()
            if line.startswith("peer:"):
                if current_peer:
                    peers.append(current_peer)
                current_peer = {"public_key": line.split(":", 1)[1].strip()}
            elif line.startswith("endpoint:") and current_peer:
                current_peer["endpoint"] = line.split(":", 1)[1].strip()
            elif line.startswith("transfer:") and current_peer:
                m2 = re.search(r"([\d.]+)\s+\w+ received,\s+([\d.]+)", line)
                if m2:
                    current_peer["transfer_rx_mb"] = float(m2.group(1))
                    current_peer["transfer_tx_mb"] = float(m2.group(2))
            elif line.startswith("allowed ips:") and current_peer:
                current_peer["allowed_ips"] = line.split(":", 1)[1].strip()
        if current_peer:
            peers.append(current_peer)
    return success({"active": True, "uptime_seconds": uptime_sec, "uptime_human": uptime_human,
                    "peer_count": len(peers), "peers": peers})

@app.route("/api/all")
def api_all():
    from flask import current_app
    with current_app.test_client() as c:
        endpoints = ["status", "stats", "pihole", "threats", "banned", "clients", "cowrie", "vpn"]
        combined = {}
        for ep in endpoints:
            try:
                resp = c.get(f"/api/{ep}")
                data = resp.get_json()
                combined[ep] = data.get("data", {}) if data.get("ok") else {}
            except:
                combined[ep] = {}
    return success(combined)

@app.route("/")
def dashboard():
    return app.send_static_file("safehaven-dashboard.html")

@app.route("/login", methods=["GET"])
def login_page():
    # Already authenticated? Send them straight to the dashboard.
    if session.get("logged_in"):
        return redirect("/")
    return app.send_static_file("login.html")

@app.route("/login", methods=["POST"])
def login_submit():
    username = (request.form.get("username") or "").strip()
    password = request.form.get("password") or ""
    if check_admin_credentials(username, password):
        session.permanent = True
        session["logged_in"] = True
        session["username"]  = username
        return redirect("/")
    # Failure: bounce back with error=1 + pre-filled username
    return redirect(f"/login?error=1&u={quote(username)}")

@app.route("/logout")
def logout():
    session.clear()
    return redirect("/login")

@app.route("/health")
def health():
    return jsonify({"ok": True, "service": "SafeHaven Pi Dashboard API", "version": "1.0.0"})

# ══════════════════════════════════════════════════════════════════════
#  BUSINESS MODE — Captive Portal & User Management
# ══════════════════════════════════════════════════════════════════════

def load_business_users():
    """Load the list of Business Mode users (captive portal accounts)."""
    if not os.path.exists(BUSINESS_USERS_FILE):
        return []
    try:
        with open(BUSINESS_USERS_FILE) as f:
            data = json.load(f)
        return data if isinstance(data, list) else []
    except Exception:
        return []

def save_business_users(users):
    """Persist the Business Mode user list to /etc/safehaven/."""
    try:
        os.makedirs(os.path.dirname(BUSINESS_USERS_FILE), exist_ok=True)
        with open(BUSINESS_USERS_FILE, "w") as f:
            json.dump(users, f, indent=2)
        os.chmod(BUSINESS_USERS_FILE, 0o600)
        return True
    except Exception:
        return False

def find_business_user(username):
    for u in load_business_users():
        if u.get("username") == username:
            return u
    return None

def check_business_user_credentials(username, password):
    user = find_business_user(username)
    if not user:
        return False
    return check_password_hash(user.get("password_hash", ""), password)

def format_bytes(n):
    if n < 1024:         return f"{n} B"
    if n < 1024**2:      return f"{n/1024:.0f} KB"
    if n < 1024**3:      return f"{n/1024**2:.0f} MB"
    return f"{n/1024**3:.2f} GB"

def get_uptime_human():
    try:
        with open("/proc/uptime") as f:
            secs = int(float(f.read().split()[0]))
        d = secs // 86400
        h = (secs % 86400) // 3600
        m = (secs % 3600) // 60
        if d > 0: return f"{d}d {h}h"
        if h > 0: return f"{h}h {m}m"
        return f"{m}m"
    except Exception:
        return "—"

# ── Captive portal routes (end-user facing) ──────────────────

@app.route("/portal", methods=["GET"])
def portal_page():
    """Captive portal login page. Only served in Business Mode."""
    if session.get("portal_user"):
        return redirect("/portal/connected")
    return app.send_static_file("portal.html")

@app.route("/portal/login", methods=["POST"])
def portal_login():
    data = request.get_json(silent=True) or {}
    username = (data.get("username") or "").strip()
    password = data.get("password") or ""

    if not check_business_user_credentials(username, password):
        return jsonify({"success": False, "message": "Invalid username or password"}), 401

    # Establish portal session
    session.permanent = True
    session["portal_user"] = username

    # Track connection (mocked — real WireGuard per-user provisioning would plug in here)
    ip_suffix = (abs(hash(username)) % 240) + 10
    _portal_sessions[username] = {
        "connected_since": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "client_ip": f"10.8.0.{ip_suffix}",
        "downloaded_bytes": 0,
        "uploaded_bytes": 0,
    }
    # Update last_active on the user record
    users = load_business_users()
    for u in users:
        if u.get("username") == username:
            u["last_active"] = datetime.now(timezone.utc).isoformat(timespec="seconds")
    save_business_users(users)

    return jsonify({"success": True, "redirect": "/portal/connected"})

@app.route("/portal/connected", methods=["GET"])
def portal_connected_page():
    return app.send_static_file("portal-connected.html")

@app.route("/portal/api/status")
def portal_api_status():
    username = session.get("portal_user")
    sess = _portal_sessions.get(username) if username else None

    if not sess:
        # Session lost (e.g. Flask restart) — clear cookie and 401
        session.pop("portal_user", None)
        return jsonify({"ok": False, "error": "Session expired"}), 401

    # Simulate live traffic so stats move (real impl would read nftables counters)
    sess["downloaded_bytes"] += random.randint(80_000, 400_000)
    sess["uploaded_bytes"]   += random.randint(8_000, 40_000)

    user = find_business_user(username) or {}

    return jsonify({
        "ok": True,
        "username": username,
        "name": user.get("name", username),
        "email": user.get("email", username),
        "client_ip": sess["client_ip"],
        "server_ip": "10.8.0.1",
        "connected_since": sess["connected_since"],
        "downloaded_bytes": sess["downloaded_bytes"],
        "uploaded_bytes": sess["uploaded_bytes"],
        "ping_ms": random.randint(8, 20),
    })

@app.route("/portal/api/disconnect", methods=["POST"])
def portal_api_disconnect():
    username = session.pop("portal_user", None)
    if username:
        _portal_sessions.pop(username, None)
    return jsonify({"success": True})

# ── Admin routes (behind existing admin auth) ────────────────

@app.route("/admin/users", methods=["GET"])
def admin_business_users_page():
    return app.send_static_file("business-admin.html")

@app.route("/admin/api/users", methods=["GET"])
def admin_api_list_users():
    users = load_business_users()
    safe_users = []
    for u in users:
        # strip password hash before returning
        safe = {k: v for k, v in u.items() if k != "password_hash"}
        safe["online"] = u.get("username") in _portal_sessions
        safe_users.append(safe)

    # Aggregate "data today" across connected sessions (mock)
    total_bytes = sum(
        s.get("downloaded_bytes", 0) + s.get("uploaded_bytes", 0)
        for s in _portal_sessions.values()
    )

    return jsonify({
        "ok": True,
        "users": safe_users,
        "data_today": format_bytes(total_bytes),
        "uptime": get_uptime_human(),
    })

@app.route("/admin/api/users", methods=["POST"])
def admin_api_create_user():
    data = request.get_json(silent=True) or {}
    username = (data.get("username") or "").strip()
    password = data.get("password") or ""
    if not username or not password:
        return jsonify({"success": False, "message": "Username and password required"}), 400

    users = load_business_users()
    if any(u.get("username") == username for u in users):
        return jsonify({"success": False, "message": "User already exists"}), 409

    users.append({
        "username": username,
        "name":     data.get("name", username),
        "email":    data.get("email", ""),
        "role":     data.get("role", "user"),
        "password_hash": generate_password_hash(password),
        "created_at":  datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "last_active": None,
    })
    if not save_business_users(users):
        return jsonify({"success": False, "message": "Could not save user — check file permissions"}), 500

    return jsonify({"success": True})

@app.route("/admin/api/users/<username>", methods=["DELETE"])
def admin_api_delete_user(username):
    users = load_business_users()
    remaining = [u for u in users if u.get("username") != username]
    if len(remaining) == len(users):
        return jsonify({"success": False, "message": "User not found"}), 404
    if not save_business_users(remaining):
        return jsonify({"success": False, "message": "Could not save changes"}), 500
    # Also kick them if currently connected
    _portal_sessions.pop(username, None)
    return jsonify({"success": True})

@app.route("/admin/api/connected")
def admin_api_connected():
    now = datetime.now(timezone.utc)
    connected = []
    for username, sess in _portal_sessions.items():
        try:
            since = datetime.fromisoformat(sess["connected_since"])
            if since.tzinfo is None:
                since = since.replace(tzinfo=timezone.utc)
            connected_seconds = int((now - since).total_seconds())
        except Exception:
            connected_seconds = 0

        user = find_business_user(username) or {}
        connected.append({
            "username": username,
            "name":  user.get("name", username),
            "email": user.get("email", username),
            "client_ip": sess.get("client_ip", "—"),
            "downloaded_bytes": sess.get("downloaded_bytes", 0),
            "uploaded_bytes":   sess.get("uploaded_bytes", 0),
            "connected_seconds": connected_seconds,
        })

    return jsonify({"ok": True, "users": connected})

@app.route("/admin/api/kick/<username>", methods=["POST"])
def admin_api_kick(username):
    if username in _portal_sessions:
        _portal_sessions.pop(username)
        return jsonify({"success": True})
    return jsonify({"success": False, "message": "User not connected"}), 404

@app.route("/api/mode")
def api_mode():
    """Public endpoint — returns the current SafeHaven mode.

    Public because the login page and dashboard both need to know the mode
    before the user is authenticated (e.g. to decide whether to show the
    login UI at all, or to render a mode-specific dashboard layout).
    """
    mode_num = get_current_mode()
    mode_name = {
        0: "Idle",
        1: "Traveler",
        2: "Activist",
        3: "Business",
        4: "Relaxed",
    }.get(mode_num, "Unknown")
    return jsonify({
        "ok": True,
        "mode": mode_num,
        "name": mode_name,
        "auth_required": mode_num in AUTH_REQUIRED_MODES,
    })

if __name__ == "__main__":
    # CLI: set/reset admin credentials without starting the server
    if len(sys.argv) > 1 and sys.argv[1] in ("--set-admin-password", "--set-password"):
        set_admin_password_interactive()
        sys.exit(0)

    # Warn (don't refuse) if no credentials — the dashboard still works for
    # single-user modes. Credentials only block access in Business Mode.
    if not load_admin_credentials():
        print("\n  ⚠  No admin credentials configured.")
        print("     Traveler/Activist/Relaxed modes will work without login.")
        print("     Business Mode will be locked until you run:")
        print("       sudo python3 app.py --set-admin-password\n")

    ssl_cert = "/etc/safehaven/ssl/cert.pem"
    ssl_key  = "/etc/safehaven/ssl/key.pem"
    if os.path.exists(ssl_cert) and os.path.exists(ssl_key):
        print("\n  SafeHaven Pi — Dashboard API running on port {} (HTTPS)\n".format(FLASK_PORT))
        app.run(host="0.0.0.0", port=FLASK_PORT, debug=False, ssl_context=(ssl_cert, ssl_key))
    else:
        print("\n  SafeHaven Pi — Dashboard API running on port {} (HTTP — no cert found)\n".format(FLASK_PORT))
        app.run(host="0.0.0.0", port=FLASK_PORT, debug=False)
