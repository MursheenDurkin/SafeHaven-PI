#!/bin/bash
# ============================================================
#  SafeHaven Pi — Installer
#  Run once after cloning the repository:
#    sudo bash install.sh
# ============================================================

RESET='\033[0m'
BOLD='\033[1m'
TEAL='\033[38;5;86m'
GREEN='\033[38;5;82m'
AMBER='\033[38;5;214m'
RED='\033[38;5;196m'
WHITE='\033[38;5;255m'
GREY='\033[38;5;244m'
CYAN='\033[38;5;117m'

INSTALL_DIR="/opt/safehaven"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_banner() {
    clear
    echo -e "${TEAL}${BOLD}"
    echo "  ╔══════════════════════════════════════════════════════════╗"
    echo "  ║                                                          ║"
    echo "  ║           SafeHaven Pi  —  Installer                    ║"
    echo "  ║           Privacy is a right, not a product.            ║"
    echo "  ║                                                          ║"
    echo "  ╚══════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
    echo -e "  ${GREY}This will install and configure all SafeHaven Pi services.${RESET}"
    echo -e "  ${GREY}Estimated time: 3-5 minutes depending on connection speed.${RESET}"
    echo ""
}

step() {
    echo -e "  ${TEAL}▶${RESET}  $1"
}

ok() {
    echo -e "  ${GREEN}✓${RESET}  $1"
}

warn() {
    echo -e "  ${AMBER}!${RESET}  $1"
}

fail() {
    echo -e "  ${RED}✗${RESET}  $1"
}

divider() {
    echo -e "  ${GREY}──────────────────────────────────────────────────────────${RESET}"
}

# ── Root check ────────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root:  sudo bash install.sh${RESET}"
    exit 1
fi

print_banner
read -rp "  Press Enter to begin installation, or Ctrl+C to cancel... "
echo ""

# ── Step 1: System update ─────────────────────────────────────
divider
echo -e "  ${BOLD}${WHITE}[1/6]  System Update${RESET}"
divider
step "Updating package lists..."
apt-get update -qq && ok "Package lists updated." || warn "Update had warnings — continuing."
echo ""

# ── Step 2: Install dependencies ─────────────────────────────
divider
echo -e "  ${BOLD}${WHITE}[2/6]  Installing Dependencies${RESET}"
divider

PACKAGES=(
    hostapd
    dnsmasq
    wireguard
    wireguard-tools
    suricata
    fail2ban
    qrencode
    iptables
    iptables-persistent
    nftables
    curl
    git
    python3
    python3-pip
    python3-flask
)

for pkg in "${PACKAGES[@]}"; do
    step "Installing $pkg..."
    if apt-get install -y -qq "$pkg" &>/dev/null; then
        ok "$pkg installed."
    else
        warn "$pkg — install may have failed, check manually."
    fi
done

# Pi-hole (separate installer)
if ! command -v pihole &>/dev/null; then
    step "Installing Pi-hole..."
    curl -sSL https://install.pi-hole.net | bash /dev/stdin --unattended &>/dev/null \
        && ok "Pi-hole installed." \
        || warn "Pi-hole install failed — install manually: https://pi-hole.net"
else
    ok "Pi-hole already installed."
fi

# Cowrie honeypot
if [ ! -d "/home/cowrie/cowrie" ]; then
    step "Installing Cowrie honeypot..."
    useradd -r -s /bin/false cowrie 2>/dev/null || true
    mkdir -p /home/cowrie
    git clone -q https://github.com/cowrie/cowrie /home/cowrie/cowrie 2>/dev/null \
        && ok "Cowrie cloned." \
        || warn "Cowrie clone failed — install manually."
    cd /home/cowrie/cowrie && pip3 install -q -r requirements.txt 2>/dev/null && cd - &>/dev/null
else
    ok "Cowrie already installed."
fi

# Tailscale
if ! command -v tailscale &>/dev/null; then
    step "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh &>/dev/null \
        && ok "Tailscale installed." \
        || warn "Tailscale install failed."
else
    ok "Tailscale already installed."
fi

echo ""

# ── Step 3: Copy configs ───────────────────────────────────────
divider
echo -e "  ${BOLD}${WHITE}[3/6]  Installing Configuration Files${RESET}"
divider

# Create install directory
mkdir -p "$INSTALL_DIR"
cp -r "$SCRIPT_DIR/configs/"* "$INSTALL_DIR/" 2>/dev/null || warn "No configs folder found — you may need to configure services manually."

# Copy scripts
cp "$SCRIPT_DIR/safehaven.sh" /usr/local/bin/safehaven
chmod +x /usr/local/bin/safehaven
ok "safehaven command installed → run with:  sudo safehaven"

# Install logrotate config to keep SD card from filling up over time
if [ -f "$SCRIPT_DIR/configs/logrotate-safehaven" ]; then
    cp "$SCRIPT_DIR/configs/logrotate-safehaven" /etc/logrotate.d/safehaven
    chmod 644 /etc/logrotate.d/safehaven
    ok "Log rotation installed → /etc/logrotate.d/safehaven"
else
    warn "logrotate-safehaven not found — long-running Pis may fill the SD card."
fi

# Install the wlan1 gateway-IP systemd unit (needed for hotspot + Tor)
if [ -f "$SCRIPT_DIR/configs/safehaven-wlan1-ip.service" ]; then
    cp "$SCRIPT_DIR/configs/safehaven-wlan1-ip.service" /etc/systemd/system/safehaven-wlan1-ip.service
    chmod 644 /etc/systemd/system/safehaven-wlan1-ip.service
    systemctl daemon-reload
    systemctl enable safehaven-wlan1-ip.service &>/dev/null \
        && ok "wlan1 gateway-IP service installed and enabled" \
        || warn "wlan1 gateway-IP service installed but could not be enabled."
else
    warn "safehaven-wlan1-ip.service not found — wlan1 may not get an IP at boot."
fi

# Install udev rule so the wlan1 service auto-triggers on hot-plug
# (BindsTo/PartOf handles device-gone but doesn't reliably trigger on
# device-appears for USB adapters — this rule closes the gap)
if [ -f "$SCRIPT_DIR/configs/90-safehaven-wlan1.rules" ]; then
    cp "$SCRIPT_DIR/configs/90-safehaven-wlan1.rules" /etc/udev/rules.d/90-safehaven-wlan1.rules
    chmod 644 /etc/udev/rules.d/90-safehaven-wlan1.rules
    udevadm control --reload-rules
    ok "udev rule installed — wlan1 service auto-triggers on hot-plug"
else
    warn "90-safehaven-wlan1.rules not found — hotspot may not auto-recover on USB hot-plug."
fi

# Tell NetworkManager to leave wlan1 alone (hostapd needs exclusive access)
if [ -f "$SCRIPT_DIR/configs/99-safehaven-wlan1.conf" ]; then
    mkdir -p /etc/NetworkManager/conf.d
    cp "$SCRIPT_DIR/configs/99-safehaven-wlan1.conf" /etc/NetworkManager/conf.d/99-safehaven-wlan1.conf
    chmod 644 /etc/NetworkManager/conf.d/99-safehaven-wlan1.conf
    systemctl restart NetworkManager 2>/dev/null \
        && ok "NetworkManager config installed — wlan1 left unmanaged for hostapd" \
        || warn "NetworkManager config installed but service could not be restarted."
else
    warn "99-safehaven-wlan1.conf not found — NetworkManager may fight hostapd for wlan1."
fi

echo ""

# ── Step 4: Enable services ────────────────────────────────────
divider
echo -e "  ${BOLD}${WHITE}[4/6]  Enabling Services on Boot${RESET}"
divider

SERVICES=(hostapd dnsmasq nftables suricata fail2ban)
for svc in "${SERVICES[@]}"; do
    systemctl enable "$svc" &>/dev/null \
        && ok "$svc enabled on boot." \
        || warn "$svc could not be enabled."
done
echo ""

# ── Step 5: IP forwarding ──────────────────────────────────────
divider
echo -e "  ${BOLD}${WHITE}[5/6]  Network Configuration${RESET}"
divider

step "Enabling IP forwarding..."
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p &>/dev/null
ok "IP forwarding enabled."

step "Creating WireGuard keypair (if not present)..."
if [ ! -f /etc/wireguard/privatekey ]; then
    wg genkey | tee /etc/wireguard/privatekey | wg pubkey > /etc/wireguard/publickey
    chmod 600 /etc/wireguard/privatekey
    ok "WireGuard keys generated."
    echo -e "  ${CYAN}Public key: $(cat /etc/wireguard/publickey)${RESET}"
else
    ok "WireGuard keys already exist."
fi

echo ""

# ── Step 6: Final setup ────────────────────────────────────────
divider
echo -e "  ${BOLD}${WHITE}[6/6]  Final Setup${RESET}"
divider

# Create a symlink so 'sudo safehaven' works from anywhere
ln -sf /usr/local/bin/safehaven /usr/local/bin/safehaven-pi 2>/dev/null

# Add SafeHaven to sudoers so menu works without repeated password prompts
if ! grep -q "safehaven" /etc/sudoers 2>/dev/null; then
    echo "# SafeHaven Pi — allow service management without password" >> /etc/sudoers
    echo "pi ALL=(ALL) NOPASSWD: /usr/local/bin/safehaven" >> /etc/sudoers
    ok "Sudoers updated."
fi

ok "Installation complete."
echo ""
divider
echo -e "  ${TEAL}${BOLD}SafeHaven Pi is ready.${RESET}"
echo ""
echo -e "  To start SafeHaven Pi, run:"
echo -e "  ${CYAN}${BOLD}  sudo safehaven${RESET}"
echo ""
echo -e "  ${GREY}Note: Configure your wg0.conf, hostapd.conf and${RESET}"
echo -e "  ${GREY}nftables.conf before first run if not already done.${RESET}"
divider
echo ""
