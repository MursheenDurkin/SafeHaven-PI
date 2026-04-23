# Troubleshooting — SafeHaven Pi

Problems people have actually hit while running SafeHaven Pi, and how
to fix them. Organised by symptom so you can skim for the one that
matches what you're seeing.

If you hit something not listed here, check `KNOWN_ISSUES.md` first —
some things are deliberate limitations rather than bugs.

---

## Hotspot / WiFi

### 🔴 Hotspot doesn't appear when clients scan for it

**Symptom:** Phone/laptop doesn't see `SafeHaven-Pi` in the WiFi list.

**Check:**
```bash
systemctl is-active hostapd
iw dev wlan1 info    # should show "type AP"
```

**Common causes:**

1. **USB WiFi adapter not plugged in** — obvious but common. Check `lsusb`
   for your adapter and `ip link show wlan1` to confirm it's detected.

2. **Adapter doesn't support AP mode.** Check with:
   ```bash
   iw list | grep -A 10 "Supported interface modes"
   ```
   Look for `* AP` in the output. If it's not there, this adapter can't
   create a hotspot. Swap it for one that supports AP mode (the Alfa
   AWUS036ACS used in development is known to work).

3. **Driver not loaded.** For RTL8812AU-based adapters (like the AWUS036ACS),
   the `88XXau` kernel module must be loaded:
   ```bash
   sudo modprobe 88XXau
   lsmod | grep 88
   ```
   If not present, reinstall the driver — see README section on hardware.

### 🔴 Clients connect but get no internet

**Symptom:** Phone connects to `SafeHaven-Pi` successfully but shows
"No internet, secured" and websites don't load.

**Check:**
```bash
# Is IP forwarding enabled?
cat /proc/sys/net/ipv4/ip_forward     # should print 1

# Is NAT configured?
sudo nft list ruleset | grep masquerade
```

**Common causes:**

1. **IP forwarding not enabled.** Fix:
   ```bash
   sudo sysctl -w net.ipv4.ip_forward=1
   echo "net.ipv4.ip_forward=1" | sudo tee /etc/sysctl.d/99-safehaven.conf
   ```

2. **Missing NAT masquerade rule.** Fix:
   ```bash
   sudo nft add rule ip nat postrouting oifname wlan0 masquerade
   ```

3. **No upstream connection.** Is `wlan0` actually connected to the
   internet?
   ```bash
   ping -c 3 1.1.1.1
   ```

### 🔴 Clients authenticate then immediately disconnect (auth loop)

**Symptom:** Phone shows "Connected", then "Connecting…", then "Connected"
repeatedly. Never settles.

**Common cause:** WPA handshake mismatch with certain USB WiFi adapters,
especially RTL8812AU in AP mode with 802.11n enabled.

**Fix:** Edit `/etc/hostapd/hostapd.conf` and:
- Set `ieee80211n=0`
- Add `wpa_pairwise=CCMP` and `rsn_pairwise=CCMP`
- Set `max_num_sta=10`

Restart hostapd: `sudo systemctl restart hostapd`.

### 🔴 wlan1 has no IP address after reboot

**Symptom:** Hotspot broadcasts but clients can't get IPs; Tor (Mode 2)
fails to start because it can't bind to `10.42.0.1`.

**Check:**
```bash
ip addr show wlan1 | grep inet
```

If no `inet 10.42.0.1/24` line, the `safehaven-wlan1-ip.service` oneshot
didn't run at boot.

**Fix:**
```bash
# Assign manually for now
sudo ip addr add 10.42.0.1/24 dev wlan1

# Then investigate why the service failed
systemctl status safehaven-wlan1-ip.service
sudo journalctl -b -u safehaven-wlan1-ip.service
```

If the service failed because hostapd had started-then-failed-then-recovered,
the fix in v1.0 uses `Wants=` (not `Requires=`) so future boots should
handle this gracefully.

---

## Tor / Mode 2 (Activist)

### 🔴 "Starting Tor..." fails during Mode 2 activation

**Common causes, in order of likelihood:**

1. **Tor isn't installed.**
   ```bash
   which tor
   ```
   If nothing prints, install it:
   ```bash
   sudo apt update && sudo apt install -y tor
   ```

2. **Tor can't bind to `10.42.0.1:9040` / `:9053`** — wlan1 doesn't have
   the gateway IP. See "wlan1 has no IP address" above.

3. **torrc is missing transparent-proxy directives.** If `/etc/tor/torrc`
   got replaced by a package update, you can see the default (no `TransPort`
   / `DNSPort` lines). The SafeHaven version lives in the repo at
   `configs/torrc` and Mode 2 activation now auto-deploys it:
   ```bash
   sudo cp configs/torrc /etc/tor/torrc
   sudo systemctl restart tor@default
   ```

### 🔴 check.torproject.org says "Not Tor"

**Symptom:** Mode 2 looks active (all green ticks) but the test page
says traffic isn't going through Tor.

**Check:**
```bash
# Are the redirect rules loaded?
sudo nft list table inet safehaven | grep -E "9040|9053"

# Is Tor actually listening?
sudo ss -tlnp | grep tor
```

Tor should be listening on `10.42.0.1:9040` (TransPort) and `10.42.0.1:9053`
(DNSPort). If it's only on `127.0.0.1:9050`, the SafeHaven torrc isn't
deployed — see above.

---

## Pi-hole

### 🔴 "Domains blocked today: ?" in the status panel

**Cause:** Pi-hole v6 moved stats behind an authenticated API, and the
status-bar code needs the session header (`X-FTL-SID`) plus properly
escaped JSON.

This was fixed in a commit around v1.0-alpha — if you're seeing `?`, you
may have pulled an older version or manually edited the file. The correct
lines in `safehaven.sh` are:

```bash
-d "{\"password\":\"${ph_cli_pw}\"}"    # JSON with escaped quotes
-H "X-FTL-SID: ${ph_sid}"               # correct header name
```

### 🔴 Pi-hole dashboard shows 0 blocked forever

**Check:**
```bash
# Is Pi-hole actually running and resolving?
systemctl is-active pihole-FTL
dig @10.42.0.1 google.com +short      # should return an IP
dig @10.42.0.1 doubleclick.net +short # should return 0.0.0.0 or similar
```

If the second `dig` returns a real IP (not `0.0.0.0`), Pi-hole isn't
using its gravity list. Update it:
```bash
pihole -g
```

---

## Dashboard / Flask

### 🔴 `https://10.42.0.1:5000` refuses to connect

**Symptom:** Browser says `ERR_CONNECTION_REFUSED` or similar.

**Cause:** The Flask dashboard isn't running. Menu option `[8]` just
tells you the URL; it doesn't start the service.

**Fix:**
```bash
cd ~/SafeHaven-PI
sudo python3 app.py
```

You should see the banner `SafeHaven Pi — Dashboard API running on port 5000`.

Leave that terminal running, or use `nohup` / systemd for a persistent
service (see KNOWN_ISSUES.md on the missing systemd unit).

### 🔴 Flask starts but says "HTTP — no cert found"

**Symptom:** Dashboard works but your browser warns loudly about
unencrypted HTTP, or the menu's `https://` link doesn't work.

**Cause:** No self-signed certificate at `/etc/safehaven/ssl/`.

**Fix:**
```bash
sudo mkdir -p /etc/safehaven/ssl

sudo openssl req -x509 -newkey rsa:4096 -nodes \
  -keyout /etc/safehaven/ssl/key.pem \
  -out /etc/safehaven/ssl/cert.pem \
  -days 365 \
  -subj "/CN=SafeHaven-Pi/O=SafeHaven/C=GB"

sudo chmod 600 /etc/safehaven/ssl/key.pem
sudo chmod 644 /etc/safehaven/ssl/cert.pem
```

Restart Flask — it'll now auto-detect the cert and serve HTTPS.

### 🔴 Flask won't start: "No admin credentials configured"

**Symptom:** `sudo python3 app.py` exits with a warning about missing
credentials.

**Fix:** Set the admin password once:
```bash
sudo python3 app.py --set-admin-password
```

Follow the prompts. Password is stored hashed in
`/etc/safehaven/auth.json`.

### 🔴 Dashboard loads but widgets say "Loading..." forever

**Cause:** One or more of the underlying log files / APIs aren't
returning data.

**Check each data source:**
```bash
curl -k https://localhost:5000/api/stats
curl -k https://localhost:5000/api/threats
curl -k https://localhost:5000/api/pihole
curl -k https://localhost:5000/api/clients
curl -k https://localhost:5000/api/vpn
```

A widget stuck on "Loading..." usually means its endpoint is returning
`{"ok": true, "data": {}}` (empty) rather than throwing an error. Most
common cause: no logged events yet. Leave the Pi running for 24 hours
and it'll populate.

### 🔴 "ModuleNotFoundError: No module named 'flask_cors'"

**Fix:**
```bash
sudo apt install -y python3-flask-cors python3-requests
```

### 🔴 "Dashboard locked — Business Mode requires admin credentials"

**Symptom:** 503 error when in Business Mode, saying credentials needed.

**Cause:** Business Mode auth gate is active but `/etc/safehaven/auth.json`
doesn't exist.

**Fix:**
```bash
sudo python3 app.py --set-admin-password
```

This is by design — Business Mode refuses to run unprotected rather
than exposing the dashboard to the hotspot silently.

---

## Admin / Portal auth

### 🔴 Admin login keeps showing "Invalid credentials" after refresh

Fixed in v1.0-alpha — the login form now strips the error query params
after reading them so refresh shows a clean page. If you still see it,
you're running an older version; pull from main.

### 🔴 Captive portal returns 404 — "Not in Business Mode"

**By design.** The portal only exists when the Pi is actively in Mode 3.
Activate Business Mode first:
- From the menu, press `3`
- Or manually: `echo "3:Business Mode" | sudo tee /tmp/safehaven-mode`

### 🔴 Portal login says "Invalid credentials" for a user I just created

**Check:**
```bash
sudo cat /etc/safehaven/business-users.json
```

The user should appear in the list with a `password_hash` field. If
not, the admin create-user flow didn't write to disk — most likely a
permissions issue. Ensure `/etc/safehaven/` is writable by the user
running Flask (Flask should be running as root via `sudo`).

---

## Git / repository issues

### 🔴 `git pull` fails on Windows with "directory deletion failed"

**Symptom:** `Deletion of directory 'scripts' failed. Should I try again?`

**Cause:** Windows file handle lock. OneDrive sync or File Explorer is
holding the folder open.

**Fix:**
1. Press `n` to skip the retry
2. Close any File Explorer windows showing that folder
3. Pause OneDrive syncing temporarily (right-click tray icon)
4. Run: `Remove-Item scripts -Recurse -Force`

### 🔴 safehaven.sh shows as "binary" in git

**Symptom:** `grep` on `safehaven.sh` says `binary file matches`, GitHub
renders it as binary.

**Cause:** Null bytes injected by OneDrive sync at some point (the file
gets saved as UTF-16 with null bytes between every character, or picks
up corruption during sync).

**Fix:**
```bash
cp safehaven.sh safehaven.sh.bak
tr -d '\0' < safehaven.sh > safehaven.sh.clean
wc -l safehaven.sh safehaven.sh.clean    # should be equal
file safehaven.sh.clean                   # should say text, not binary
bash -n safehaven.sh.clean && mv safehaven.sh.clean safehaven.sh
chmod +x safehaven.sh
```

Fixed in v1.0-alpha — the file in the repo is clean UTF-8.

---

## University / enterprise networks

### 🔴 eduroam (WPA2-Enterprise) GUI dialog won't connect

**Symptom:** The "Authentication required by Wi-Fi network" dialog for
eduroam won't accept your credentials, or the Connect button stays greyed
out.

**Cause:** The GUI dialog doesn't expose all the options eduroam needs,
and error messages are unhelpful.

**Fix:** Use `nmcli` directly:
```bash
sudo nmcli connection add type wifi con-name eduroam ifname wlan0 ssid eduroam \
  wifi-sec.key-mgmt wpa-eap \
  802-1x.eap peap \
  802-1x.phase2-auth mschapv2 \
  802-1x.identity "YOUR_STUDENT_ID@student.uwtsd.ac.uk" \
  802-1x.password "YOUR_UWTSD_PASSWORD"

sudo nmcli connection up eduroam
```

Adjust for your institution's username format.

### 🔴 Captive portal networks (hotel / café WiFi)

**Symptom:** Pi connects to a WiFi that requires a browser login ("click
here to accept terms") but the Pi has no browser.

**Workarounds:**

1. **Register the Pi's MAC address on the portal from another device.**
   Get the MAC with `ip link show wlan0`. Most captive portals allow
   MAC-registered exemption.

2. **Use `wayvnc` to remote into the Pi's desktop from your phone** and
   click through the portal from there.

3. **Tether from your phone temporarily** (USB or personal hotspot) to
   get online initially, then switch to the captive WiFi once registered.

---

## When all else fails

### 🔴 Something's broken and I have no idea what

**Step 1:** Check the `safehaven.sh` menu's status panel. The 7-service
row at the top shows which services are up/down at a glance.

**Step 2:** Pull the systemd status for everything:
```bash
systemctl is-active hostapd dnsmasq pihole-FTL suricata fail2ban cowrie tailscaled
```
Any `inactive` or `failed` is your starting point.

**Step 3:** Look at the boot-time journal for failing services:
```bash
sudo journalctl -b -u <service-name> --no-pager
```

**Step 4:** As a last resort — the project is designed to be
rebuildable from the repo. If one Pi is broken beyond debugging:
```bash
# On a freshly-flashed Pi:
git clone https://github.com/MursheenDurkin/SafeHaven-PI.git
cd SafeHaven-PI
sudo bash install.sh
sudo bash safehaven.sh
```

You're back where you started in about 20 minutes.
