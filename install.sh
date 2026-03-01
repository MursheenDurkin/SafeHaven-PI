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

cp "$SCRIPT_DIR/safehaven_menu.sh" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/safehaven_menu.sh"
ok "Menu script installed."

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
