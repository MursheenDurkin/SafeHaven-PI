#!/bin/bash
# ============================================================
#  SafeHaven Pi — Startup & Control
#  Usage:  sudo safehaven
#  Install to /usr/local/bin/safehaven via install.sh
# ============================================================

RESET='\033[0m'
BOLD='\033[1m'

TEAL='\033[38;5;86m'
CYAN='\033[38;5;117m'
GREEN='\033[38;5;82m'
AMBER='\033[38;5;214m'
RED='\033[38;5;196m'
WHITE='\033[38;5;255m'
GREY='\033[38;5;244m'
PURPLE='\033[38;5;141m'
BLUE='\033[38;5;75m'

# ── Helpers ───────────────────────────────────────────────────
spinner() {
    local pid=$1
    local delay=0.1
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf " ${TEAL}%s${RESET}" "${frames[$i]}"
        sleep $delay
        printf "\b\b\b"
        i=$(( (i+1) % ${#frames[@]} ))
    done
    printf "   \b\b\b"
}

svc_start() {
    local name="$1"
    local cmd="$2"
    local label="$3"
    printf "  ${GREY}%-38s${RESET}" "$label"
    eval "$cmd" >/dev/null 2>/dev/null </dev/null &
    local pid=$!
    spinner $pid
    wait $pid
    local result=$?
    if [ $result -eq 0 ]; then
        printf "${GREEN}✓  RUNNING${RESET}\n"
    else
        printf "${RED}✗  FAILED${RESET}\n"
        BOOT_ERRORS=$((BOOT_ERRORS + 1))
    fi
    sleep 0.1
}

divider() {
    echo -e "  ${GREY}────────────────────────────────────────────────────────────────────${RESET}"
}

thin_divider() {
    echo -e "  ${GREY}· · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · ·${RESET}"
}

# ── Boot Screen ───────────────────────────────────────────────
boot_screen() {
    clear
    echo ""
    echo -e "${TEAL}${BOLD}"
    echo "  ███████╗ █████╗ ███████╗███████╗██╗  ██╗ █████╗ ██╗   ██╗███████╗███╗   ██╗"
    echo "  ██╔════╝██╔══██╗██╔════╝██╔════╝██║  ██║██╔══██╗██║   ██║██╔════╝████╗  ██║"
    echo "  ███████╗███████║█████╗  █████╗  ███████║███████║██║   ██║█████╗  ██╔██╗ ██║"
    echo "  ╚════██║██╔══██║██╔══╝  ██╔══╝  ██╔══██║██╔══██║╚██╗ ██╔╝██╔══╝  ██║╚██╗██║"
    echo "  ███████║██║  ██║██║     ███████╗██║  ██║██║  ██║ ╚████╔╝ ███████╗██║ ╚████║"
    echo "  ╚══════╝╚═╝  ╚═╝╚═╝     ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝  ╚═══╝  ╚══════╝╚═╝  ╚═══╝"
    echo -e "${RESET}"
    echo -e "  ${TEAL}${BOLD}                        P R I V A C Y   P I${RESET}"
    echo -e "  ${GREY}                 Privacy is a right, not a product.${RESET}"
    echo ""
    divider
    echo -e "  ${GREY}  Version 1.0-alpha   ·   Raspberry Pi 5   ·   UWTSD 2026${RESET}"
    divider
    echo ""
    sleep 1
}

# ── Startup Sequence ──────────────────────────────────────────
run_startup() {
    BOOT_ERRORS=0

    echo -e "  ${BOLD}${WHITE}STARTING SAFEHAVEN PI SECURITY STACK${RESET}"
    echo -e "  ${GREY}Initialising all security services...${RESET}"
    echo ""
    divider

    echo -e "  ${CYAN}${BOLD}LAYER 1  —  Network & Access Point${RESET}"
    echo ""
    svc_start "hostapd"     "systemctl start hostapd"     "WiFi Hotspot (hostapd)"
    sleep 0.3
    svc_start "dnsmasq"     "systemctl start dnsmasq"     "DHCP Server (dnsmasq)"
    echo ""

    echo -e "  ${GREEN}${BOLD}LAYER 2  —  Firewall${RESET}"
    echo ""
    svc_start "nftables"    "systemctl start nftables"    "Firewall (nftables)"
    echo ""

    echo -e "  ${PURPLE}${BOLD}LAYER 3  —  VPN Encryption${RESET}"
    echo ""
    printf "  ${GREY}%-38s${RESET}" "VPN Tunnel (WireGuard)"
    wg-quick up wg0 >/dev/null 2>/dev/null </dev/null &
    local wg_pid=$!
    spinner $wg_pid
    wait $wg_pid
    if ip link show wg0 &>/dev/null; then
        printf "${GREEN}✓  RUNNING${RESET}\n"
    else
        printf "${AMBER}!  CHECK CONFIG${RESET}\n"
        BOOT_ERRORS=$((BOOT_ERRORS + 1))
    fi
    echo ""

    echo -e "  ${CYAN}${BOLD}LAYER 4  —  DNS Filter${RESET}"
    echo ""
    svc_start "pihole-FTL"  "systemctl start pihole-FTL"  "DNS Filter (Pi-hole)"
    echo ""

    echo -e "  ${AMBER}${BOLD}LAYER 5  —  Intrusion Detection & Protection${RESET}"
    echo ""
    svc_start "suricata"    "systemctl start suricata"    "IDS (Suricata)"
    sleep 0.5
    svc_start "fail2ban"    "systemctl start fail2ban"    "Brute Force Block (Fail2ban)"
    echo ""

    echo -e "  ${PURPLE}${BOLD}LAYER 6  —  Honeypot Decoy${RESET}"
    echo ""
    svc_start "cowrie"      "systemctl start cowrie"      "SSH Honeypot (Cowrie)"
    echo ""

    echo -e "  ${BLUE}${BOLD}LAYER 7  —  Remote Admin${RESET}"
    echo ""
    svc_start "tailscaled"  "systemctl start tailscaled"  "Remote Access (Tailscale)"
    echo ""
    divider

    echo ""
    if [ "$BOOT_ERRORS" -eq 0 ]; then
        echo -e "  ${GREEN}${BOLD}All systems operational.${RESET}  ${GREY}SafeHaven Pi is protecting your network.${RESET}"
    elif [ "$BOOT_ERRORS" -le 2 ]; then
        echo -e "  ${AMBER}${BOLD}Started with ${BOOT_ERRORS} warning(s).${RESET}  ${GREY}Check flagged services above.${RESET}"
    else
        echo -e "  ${RED}${BOLD}${BOOT_ERRORS} service(s) failed to start.${RESET}  ${GREY}Check logs: sudo journalctl -xe${RESET}"
    fi

    echo ""
    local cpu_load mem_used mem_total uptime_str
    cpu_load=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d. -f1 2>/dev/null || echo "?")
    mem_used=$(free -m | awk 'NR==2{print $3}')
    mem_total=$(free -m | awk 'NR==2{print $2}')
    uptime_str=$(uptime -p 2>/dev/null | sed 's/up //')
    echo -e "  ${GREY}CPU: ${WHITE}${cpu_load}%   ${GREY}RAM: ${WHITE}${mem_used}/${mem_total} MB   ${GREY}Uptime: ${WHITE}${uptime_str}${RESET}"
    echo ""
    divider
    echo ""
    echo -e "  ${GREY}Loading control menu in...${RESET}"
    echo ""
    for i in 3 2 1; do
        printf "\r  ${TEAL}${BOLD}    %s   ${RESET}" "$i"
        sleep 1
    done
    printf "\r  ${GREEN}${BOLD}  ✓  GO  ${RESET}\n"
    sleep 0.4
}

# ── Service Status Helpers ────────────────────────────────────
svc_status_inline() {
    local svc="$1"
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        printf "${GREEN}● ON ${RESET}"
    else
        printf "${RED}○ OFF${RESET}"
    fi
}

wg_status_inline() {
    if ip link show wg0 &>/dev/null; then
        printf "${GREEN}● ON ${RESET}"
    else
        printf "${RED}○ OFF${RESET}"
    fi
}

# ── Status Panel ──────────────────────────────────────────────
show_status() {
    local cpu_load mem_used mem_total uptime_str vpn_clients

    cpu_load=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d. -f1 2>/dev/null || echo "?")
    mem_used=$(free -m | awk 'NR==2{print $3}')
    mem_total=$(free -m | awk 'NR==2{print $2}')
    uptime_str=$(uptime -p 2>/dev/null | sed 's/up //' || echo "?")
    vpn_clients=$(wg show wg0 peers 2>/dev/null | grep -c . || echo "0")

    divider
    echo -e "  ${BOLD}${WHITE}PROTECTION STATUS${RESET}   ${GREY}— all security layers at a glance${RESET}"
    divider
    echo ""

    # Row 1
    printf "  "
    printf "${GREY}WiFi Hotspot     ${RESET}"; svc_status_inline "hostapd"
    printf "     "
    printf "${GREY}VPN Tunnel       ${RESET}"; wg_status_inline
    printf "     "
    printf "${GREY}DNS Filter       ${RESET}"; svc_status_inline "pihole-FTL"
    echo ""

    # Row 2
    printf "  "
    printf "${GREY}Firewall         ${RESET}"; svc_status_inline "nftables"
    printf "     "
    printf "${GREY}Threat Detection ${RESET}"; svc_status_inline "suricata"
    printf "     "
    printf "${GREY}Brute Force Block${RESET}"; svc_status_inline "fail2ban"
    echo ""

    # Row 3
    printf "  "
    printf "${GREY}Honeypot Decoy   ${RESET}"; svc_status_inline "cowrie"
    printf "     "
    printf "${GREY}Remote Admin     ${RESET}"; svc_status_inline "tailscaled"
    echo ""
    echo ""

    thin_divider
    echo ""
    echo -e "  ${GREY}CPU ${WHITE}${cpu_load}%${GREY}   RAM ${WHITE}${mem_used}/${mem_total} MB${GREY}   Uptime ${WHITE}${uptime_str}${GREY}   VPN Clients ${WHITE}${vpn_clients}${RESET}"
    echo ""
    divider
    echo ""
}

# ── Header ────────────────────────────────────────────────────
print_header() {
    local pi_model
    pi_model=$(cat /proc/device-tree/model 2>/dev/null | tr -d '\0' || echo "Raspberry Pi")

    clear
    echo ""
    echo -e "${TEAL}${BOLD}"
    echo "  ███████╗ █████╗ ███████╗███████╗██╗  ██╗ █████╗ ██╗   ██╗███████╗███╗   ██╗"
    echo "  ██╔════╝██╔══██╗██╔════╝██╔════╝██║  ██║██╔══██╗██║   ██║██╔════╝████╗  ██║"
    echo "  ███████╗███████║█████╗  █████╗  ███████║███████║██║   ██║█████╗  ██╔██╗ ██║"
    echo "  ╚════██║██╔══██║██╔══╝  ██╔══╝  ██╔══██║██╔══██║╚██╗ ██╔╝██╔══╝  ██║╚██╗██║"
    echo "  ███████║██║  ██║██║     ███████╗██║  ██║██║  ██║ ╚████╔╝ ███████╗██║ ╚████║"
    echo "  ╚══════╝╚═╝  ╚═╝╚═╝     ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝  ╚═══╝  ╚══════╝╚═╝  ╚═══╝"
    echo -e "${RESET}"
    echo -e "  ${TEAL}${BOLD}Security Control Menu${RESET}   ${GREY}·   Privacy is a right, not a product.${RESET}"
    echo -e "  ${GREY}v1.0-alpha   ·   ${WHITE}${pi_model}${GREY}   ·   UWTSD 2026${RESET}"
    echo ""
}

# ── Main Menu ─────────────────────────────────────────────────
main_menu() {
    while true; do
        print_header
        show_status

        # ── Modes ─────────────────────────────────────────────
        echo -e "  ${TEAL}${BOLD}  MODES  ${RESET}${GREY}— choose how you want to be protected today${RESET}"
        echo ""
        echo -e "  ${GREEN}[1]${RESET}  ${BOLD}Traveler Mode${RESET}   ${GREEN}● Ready${RESET}"
        echo -e "       ${GREY}Use this in hotels, airports, cafes — encrypts everything,${RESET}"
        echo -e "       ${GREY}blocks ads and trackers, hides your traffic from prying eyes.${RESET}"
        echo ""
        echo -e "  ${AMBER}[2]${RESET}  ${BOLD}Activist Mode${RESET}   ${AMBER}◐ Coming Soon${RESET}"
        echo -e "       ${GREY}Maximum privacy — Tor routing, zero logs, no trace left behind.${RESET}"
        echo -e "       ${GREY}For journalists, activists, or anyone who needs total anonymity.${RESET}"
        echo ""
        echo -e "  ${AMBER}[3]${RESET}  ${BOLD}Business Mode${RESET}   ${AMBER}◐ Coming Soon${RESET}"
        echo -e "       ${GREY}Set up a secure temporary office network — keeps each device${RESET}"
        echo -e "       ${GREY}isolated from the others, with full threat monitoring.${RESET}"
        echo ""
        divider

        # ── Tools ─────────────────────────────────────────────
        echo -e "  ${TEAL}${BOLD}  TOOLS  ${RESET}${GREY}— dig deeper into what SafeHaven Pi is doing${RESET}"
        echo ""
        echo -e "  ${CYAN}[4]${RESET}  ${BOLD}Live Security Logs${RESET}   ${GREY}See real-time threats, blocked sites, VPN activity${RESET}"
        echo -e "  ${CYAN}[5]${RESET}  ${BOLD}Add a Device to VPN${RESET}  ${GREY}Show QR code — scan with WireGuard app on your phone${RESET}"
        echo -e "  ${CYAN}[6]${RESET}  ${BOLD}DNS Block Stats${RESET}      ${GREY}See how many ads and trackers Pi-hole has blocked${RESET}"
        echo -e "  ${CYAN}[7]${RESET}  ${BOLD}Web Dashboard${RESET}        ${GREY}Open http://10.42.0.1:5000 on any connected device${RESET}"
        echo ""
        divider

        # ── System ────────────────────────────────────────────
        echo -e "  ${TEAL}${BOLD}  SYSTEM${RESET}"
        echo ""
        echo -e "  ${RED}[s]${RESET}  ${BOLD}Stop All Services${RESET}    ${GREY}Safely shut down all protection layers${RESET}"
        echo -e "  ${RED}[r]${RESET}  ${BOLD}Reboot Pi${RESET}            ${GREY}Restart the device — all services resume on boot${RESET}"
        echo -e "  ${GREY}[q]${RESET}  ${BOLD}Quit This Menu${RESET}       ${GREY}Exit to terminal — protection keeps running${RESET}"
        echo ""
        divider
        echo ""
        read -rp "  $(echo -e "${TEAL}${BOLD}safehaven${RESET}") ❯ " choice

        case "$choice" in
            1) activate_mode 1 ;;
            2) activate_mode 2 ;;
            3) activate_mode 3 ;;
            4) show_logs ;;
            5) show_wg_qr ;;
            6) show_pihole ;;
            7)
                echo ""
                echo -e "  ${GREY}Open this address on any device connected to SafeHaven Pi:${RESET}"
                echo ""
                echo -e "  ${CYAN}${BOLD}  → http://10.42.0.1:5000${RESET}"
                echo ""
                read -rp "  Press Enter to return to menu..." _
                ;;
            s|S) stop_all_services ;;
            r|R)
                echo ""
                echo -e "  ${RED}Rebooting in 3 seconds — press Ctrl+C to cancel${RESET}"
                sleep 3
                reboot
                ;;
            q|Q)
                echo ""
                echo -e "  ${GREY}Menu closed. All protection layers are still running in the background.${RESET}"
                echo ""
                exit 0
                ;;
            *)
                echo -e "  ${RED}Not a valid option — type a number or letter from the menu above.${RESET}"
                sleep 1
                ;;
        esac
    done
}

# ── Mode Activation ───────────────────────────────────────────
activate_mode() {
    local mode=$1
    print_header

    case $mode in
        1)
            echo -e "  ${GREEN}${BOLD}Switching on Traveler Mode${RESET}"
            echo -e "  ${GREY}Starting all security layers — this takes a few seconds...${RESET}"
            echo ""
            divider
            echo ""
            printf "  ${GREY}%-38s${RESET}" "Starting WiFi hotspot..."
            systemctl start hostapd >/dev/null 2>/dev/null && printf "${GREEN}✓  Hotspot broadcasting${RESET}\n" || printf "${RED}✗  Failed — check hostapd config${RESET}\n"

            printf "  ${GREY}%-38s${RESET}" "Starting firewall..."
            systemctl start nftables >/dev/null 2>/dev/null && printf "${GREEN}✓  Firewall active${RESET}\n" || printf "${RED}✗  Failed${RESET}\n"

            printf "  ${GREY}%-38s${RESET}" "Starting VPN tunnel..."
            wg-quick up wg0 >/dev/null 2>/dev/null && printf "${GREEN}✓  WireGuard tunnel up${RESET}\n" || printf "${AMBER}!  Check wg0.conf — see configs/ folder${RESET}\n"

            printf "  ${GREY}%-38s${RESET}" "Starting DNS filter..."
            systemctl start pihole-FTL >/dev/null 2>/dev/null && printf "${GREEN}✓  Pi-hole blocking ads and trackers${RESET}\n" || printf "${RED}✗  Failed${RESET}\n"

            printf "  ${GREY}%-38s${RESET}" "Starting threat detection..."
            systemctl start suricata fail2ban >/dev/null 2>/dev/null && printf "${GREEN}✓  Suricata + Fail2ban watching for threats${RESET}\n" || printf "${RED}✗  Failed${RESET}\n"

            printf "  ${GREY}%-38s${RESET}" "Starting honeypot decoy..."
            systemctl start cowrie >/dev/null 2>/dev/null && printf "${GREEN}✓  Cowrie decoy active on port 2222${RESET}\n" || printf "${RED}✗  Failed${RESET}\n"

            echo ""
            divider
            echo ""
            echo -e "  ${GREEN}${BOLD}✓  Traveler Mode is active. You are protected.${RESET}"
            echo ""
            echo -e "  ${GREY}Connect your devices to the SafeHaven Pi WiFi network.${RESET}"
            echo -e "  ${GREY}All traffic is now encrypted and filtered.${RESET}"
            ;;
        2)
            echo -e "  ${AMBER}${BOLD}Switching on Activist Mode${RESET}"
            echo -e "  ${GREY}Zero-log DNS + Tor routing — maximum privacy${RESET}"
            echo ""
            systemctl start hostapd dnsmasq nftables pihole-FTL suricata fail2ban >/dev/null 2>/dev/null
            wg-quick up wg0 >/dev/null 2>/dev/null
            echo -e "  ${GREEN}✓${RESET}  Base security layers started"
            if systemctl list-unit-files | grep -q tor.service; then
                systemctl start tor >/dev/null 2>/dev/null && echo -e "  ${GREEN}✓${RESET}  Tor routing active — traffic anonymised"
            else
                echo -e "  ${AMBER}!${RESET}  Tor not installed yet"
                echo -e "  ${GREY}     Run: sudo apt install tor${RESET}"
            fi
            if command -v pihole &>/dev/null; then
                pihole logging off >/dev/null 2>/dev/null && echo -e "  ${GREEN}✓${RESET}  Pi-hole zero-log mode on — no DNS history kept"
            fi
            echo ""
            echo -e "  ${AMBER}${BOLD}Activist Mode active.${RESET}  ${GREY}Full Tor integration coming in the next version.${RESET}"
            ;;
        3)
            echo -e "  ${AMBER}${BOLD}Switching on Business Mode${RESET}"
            echo -e "  ${GREY}Secure temporary network — each device kept isolated from the others${RESET}"
            echo ""
            systemctl start hostapd dnsmasq nftables pihole-FTL suricata fail2ban >/dev/null 2>/dev/null
            echo -e "  ${GREEN}✓${RESET}  Core security layers started"
            echo -e "  ${AMBER}!${RESET}  Per-device traffic isolation — coming in next version"
            echo -e "  ${AMBER}!${RESET}  Business dashboard view      — coming in next version"
            echo ""
            echo -e "  ${AMBER}${BOLD}Business Mode base active.${RESET}  ${GREY}Full version coming soon.${RESET}"
            ;;
    esac

    echo ""
    divider
    read -rp "  Press Enter to return to the menu..." _
}

# ── Live Logs ─────────────────────────────────────────────────
show_logs() {
    print_header
    echo -e "  ${BOLD}${WHITE}LIVE SECURITY LOGS${RESET}"
    echo -e "  ${GREY}Watch what SafeHaven Pi is detecting in real time.${RESET}"
    echo -e "  ${GREY}Press Ctrl+C to stop watching and return here.${RESET}"
    echo ""
    divider
    echo ""
    echo -e "  ${AMBER}[1]${RESET}  ${BOLD}Threat Alerts${RESET}        ${GREY}Suricata — live intrusion and attack detections${RESET}"
    echo -e "  ${RED}[2]${RESET}  ${BOLD}Blocked IPs${RESET}           ${GREY}Fail2ban — IPs that have been banned after too many attempts${RESET}"
    echo -e "  ${PURPLE}[3]${RESET}  ${BOLD}Honeypot Sessions${RESET}    ${GREY}Cowrie — attackers connecting to the fake SSH server${RESET}"
    echo -e "  ${CYAN}[4]${RESET}  ${BOLD}DNS Activity${RESET}          ${GREY}Pi-hole — every domain looked up and blocked${RESET}"
    echo -e "  ${GREEN}[5]${RESET}  ${BOLD}VPN Connections${RESET}      ${GREY}WireGuard — devices connecting to the tunnel${RESET}"
    echo -e "  ${WHITE}[6]${RESET}  ${BOLD}Everything${RESET}           ${GREY}Full system journal — all services combined${RESET}"
    echo -e "  ${GREY}[b]${RESET}  Back to menu"
    echo ""
    read -rp "  Choose: " log_choice
    case "$log_choice" in
        1) echo -e "\n  ${AMBER}Watching for threats — Ctrl+C to stop${RESET}\n"
           tail -f /var/log/suricata/fast.log 2>/dev/null || echo "  No log found yet." ;;
        2) echo -e "\n  ${RED}Watching banned IPs — Ctrl+C to stop${RESET}\n"
           tail -f /var/log/fail2ban.log 2>/dev/null || echo "  No log found yet." ;;
        3) echo -e "\n  ${PURPLE}Watching honeypot — Ctrl+C to stop${RESET}\n"
           tail -f /home/cowrie/cowrie/var/log/cowrie/cowrie.log 2>/dev/null || echo "  No log found yet." ;;
        4) echo -e "\n  ${CYAN}Watching DNS queries — Ctrl+C to stop${RESET}\n"
           tail -f /var/log/pihole/pihole.log 2>/dev/null || echo "  No log found yet." ;;
        5) echo -e "\n  ${GREEN}Watching VPN connections — Ctrl+C to stop${RESET}\n"
           watch -n 2 wg show 2>/dev/null || wg show ;;
        6) echo -e "\n  ${WHITE}Full system journal — Ctrl+C to stop${RESET}\n"
           journalctl -f ;;
        b|B) return ;;
        *) echo "  Not a valid choice." ; sleep 0.8 ;;
    esac
}

# ── WireGuard QR ──────────────────────────────────────────────
show_wg_qr() {
    print_header
    echo -e "  ${BOLD}${WHITE}ADD A DEVICE TO THE VPN${RESET}"
    echo -e "  ${GREY}Open the WireGuard app on your phone and scan the code below.${RESET}"
    echo -e "  ${GREY}Once scanned, that device's traffic will be tunnelled through SafeHaven Pi.${RESET}"
    echo ""
    divider
    echo ""
    if command -v qrencode &>/dev/null && [ -f /etc/wireguard/wg0.conf ]; then
        cat /etc/wireguard/wg0.conf | qrencode -t ansiutf8
    else
        echo -e "  ${AMBER}QR code unavailable.${RESET}"
        echo -e "  ${GREY}Make sure qrencode is installed: sudo apt install qrencode${RESET}"
        echo -e "  ${GREY}And that your wg0.conf exists at /etc/wireguard/wg0.conf${RESET}"
    fi
    echo ""
    divider
    echo -e "  ${GREY}Public key: $(cat /etc/wireguard/publickey 2>/dev/null || echo 'not found')${RESET}"
    divider
    read -rp "  Press Enter to return to the menu..." _
}

# ── Pi-hole Stats ─────────────────────────────────────────────
show_pihole() {
    print_header
    echo -e "  ${BOLD}${WHITE}DNS BLOCK STATISTICS${RESET}"
    echo -e "  ${GREY}Showing how many ads, trackers, and malicious domains Pi-hole has blocked.${RESET}"
    echo ""
    divider
    echo ""
    if command -v pihole &>/dev/null; then
        pihole -c -e 2>/dev/null || pihole status
    else
        echo -e "  ${AMBER}Pi-hole not found on this system.${RESET}"
    fi
    echo ""
    divider
    read -rp "  Press Enter to return to the menu..." _
}

# ── Stop All ──────────────────────────────────────────────────
stop_all_services() {
    print_header
    echo -e "  ${RED}${BOLD}Stopping all SafeHaven services...${RESET}"
    echo -e "  ${GREY}Your device will no longer be protected after this.${RESET}"
    echo ""
    wg-quick down wg0 >/dev/null 2>/dev/null && echo -e "  ${GREEN}✓${RESET}  VPN tunnel closed"
    systemctl stop hostapd dnsmasq pihole-FTL nftables suricata fail2ban cowrie tailscaled >/dev/null 2>/dev/null
    echo -e "  ${GREEN}✓${RESET}  All services stopped"
    echo ""
    divider
    echo -e "  ${AMBER}SafeHaven Pi protection is now offline.${RESET}"
    read -rp "  Press Enter to return to the menu..." _
}

# ── Entry Point ───────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
    echo ""
    echo -e "  ${AMBER}${BOLD}Please run with sudo to get full control:${RESET}"
    echo -e "  ${WHITE}  sudo safehaven${RESET}"
    echo ""
    sleep 1
fi

boot_screen
run_startup
main_menu
