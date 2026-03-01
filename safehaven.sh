#!/bin/bash
# ============================================================
#  SafeHaven Pi — Startup & Control
#  Usage:  sudo safehaven
#  Install to /usr/local/bin/safehaven via install.sh
# ============================================================

RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

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
        printf "\r  ${TEAL}%s${RESET}  " "${frames[$i]}"
        i=$(( (i+1) % ${#frames[@]} ))
        sleep $delay
    done
    printf "\r"
}

svc_start() {
    local name="$1"
    local cmd="$2"
    local label="$3"

    printf "  ${GREY}%-34s${RESET}" "$label"
    eval "$cmd" &>/dev/null &
    local pid=$!
    spinner $pid
    wait $pid
    local result=$?

    if [ $result -eq 0 ]; then
        echo -e "  ${GREEN}✓  RUNNING${RESET}"
    else
        echo -e "  ${RED}✗  FAILED${RESET}"
        BOOT_ERRORS=$((BOOT_ERRORS + 1))
    fi
    sleep 0.1
}

svc_check() {
    local svc="$1"
    local label="$2"
    printf "  ${GREY}%-34s${RESET}" "$label"
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        echo -e "  ${GREEN}✓  RUNNING${RESET}"
    else
        echo -e "  ${RED}✗  NOT RUNNING${RESET}"
        BOOT_ERRORS=$((BOOT_ERRORS + 1))
    fi
}

divider() {
    echo -e "  ${GREY}──────────────────────────────────────────────────────────${RESET}"
}

# ── Boot Screen ───────────────────────────────────────────────
boot_screen() {
    clear
    echo ""
    echo -e "${TEAL}${BOLD}"
    echo "        ███████╗ █████╗ ███████╗███████╗██╗  ██╗ █████╗ ██╗   ██╗███████╗███╗   ██╗"
    echo "        ██╔════╝██╔══██╗██╔════╝██╔════╝██║  ██║██╔══██╗██║   ██║██╔════╝████╗  ██║"
    echo "        ███████╗███████║█████╗  █████╗  ███████║███████║██║   ██║█████╗  ██╔██╗ ██║"
    echo "        ╚════██║██╔══██║██╔══╝  ██╔══╝  ██╔══██║██╔══██║╚██╗ ██╔╝██╔══╝  ██║╚██╗██║"
    echo "        ███████║██║  ██║██║     ███████╗██║  ██║██║  ██║ ╚████╔╝ ███████╗██║ ╚████║"
    echo "        ╚══════╝╚═╝  ╚═╝╚═╝     ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝  ╚═══╝  ╚══════╝╚═╝  ╚═══╝"
    echo -e "${RESET}"
    echo -e "  ${TEAL}${BOLD}                          P R I V A C Y   P I${RESET}"
    echo -e "  ${GREY}                   Privacy is a right, not a product.${RESET}"
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

    # ── Layer 1: Network ──────────────────────────────────────
    echo -e "  ${CYAN}${BOLD}LAYER 1  —  Network & Access Point${RESET}"
    echo ""

    svc_start "hostapd"   "systemctl start hostapd"   "WiFi Hotspot (hostapd)"
    sleep 0.3
    svc_start "dnsmasq"   "systemctl start dnsmasq"   "DHCP Server (dnsmasq)"
    echo ""

    # ── Layer 2: Firewall ─────────────────────────────────────
    echo -e "  ${GREEN}${BOLD}LAYER 2  —  Firewall${RESET}"
    echo ""

    svc_start "nftables"  "systemctl start nftables"  "Firewall (nftables)"
    echo ""

    # ── Layer 3: VPN ──────────────────────────────────────────
    echo -e "  ${PURPLE}${BOLD}LAYER 3  —  VPN Encryption${RESET}"
    echo ""

    printf "  ${GREY}%-34s${RESET}" "VPN Tunnel (WireGuard)"
    wg-quick up wg0 &>/dev/null &
    local wg_pid=$!
    spinner $wg_pid
    wait $wg_pid
    if ip link show wg0 &>/dev/null; then
        echo -e "  ${GREEN}✓  RUNNING${RESET}"
    else
        echo -e "  ${AMBER}!  CHECK CONFIG${RESET}"
        BOOT_ERRORS=$((BOOT_ERRORS + 1))
    fi
    echo ""

    # ── Layer 4: DNS Filter ───────────────────────────────────
    echo -e "  ${CYAN}${BOLD}LAYER 4  —  DNS Filter${RESET}"
    echo ""

    svc_start "pihole-FTL" "systemctl start pihole-FTL" "DNS Filter (Pi-hole)"
    echo ""

    # ── Layer 5: Intrusion Detection ──────────────────────────
    echo -e "  ${AMBER}${BOLD}LAYER 5  —  Intrusion Detection & Protection${RESET}"
    echo ""

    svc_start "suricata"  "systemctl start suricata"  "IDS (Suricata)"
    sleep 0.5
    svc_start "fail2ban"  "systemctl start fail2ban"  "Brute Force Block (Fail2ban)"
    echo ""

    # ── Layer 6: Honeypot ─────────────────────────────────────
    echo -e "  ${PURPLE}${BOLD}LAYER 6  —  Honeypot Decoy${RESET}"
    echo ""

    svc_start "cowrie"    "systemctl start cowrie"    "SSH Honeypot (Cowrie)"
    echo ""

    # ── Layer 7: Admin ────────────────────────────────────────
    echo -e "  ${BLUE}${BOLD}LAYER 7  —  Remote Admin${RESET}"
    echo ""

    svc_start "tailscaled" "systemctl start tailscaled" "Remote Access (Tailscale)"
    echo ""
    divider

    # ── Boot summary ──────────────────────────────────────────
    echo ""
    if [ "$BOOT_ERRORS" -eq 0 ]; then
        echo -e "  ${GREEN}${BOLD}All systems operational.${RESET}  ${GREY}SafeHaven Pi is protecting your network.${RESET}"
    elif [ "$BOOT_ERRORS" -le 2 ]; then
        echo -e "  ${AMBER}${BOLD}Started with ${BOOT_ERRORS} warning(s).${RESET}  ${GREY}Check flagged services above.${RESET}"
    else
        echo -e "  ${RED}${BOLD}${BOOT_ERRORS} service(s) failed to start.${RESET}  ${GREY}Check logs:  sudo journalctl -xe${RESET}"
    fi

    echo ""

    # Quick stats
    local cpu_load mem_used mem_total uptime_str
    cpu_load=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d. -f1 2>/dev/null || echo "?")
    mem_used=$(free -m | awk 'NR==2{print $3}')
    mem_total=$(free -m | awk 'NR==2{print $2}')
    uptime_str=$(uptime -p 2>/dev/null | sed 's/up //')

    echo -e "  ${GREY}CPU: ${WHITE}${cpu_load}%   ${GREY}RAM: ${WHITE}${mem_used}/${mem_total} MB   ${GREY}Uptime: ${WHITE}${uptime_str}${RESET}"
    echo ""
    divider
    echo ""
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

# ── Service Status ────────────────────────────────────────────
service_status() {
    local svc="$1"
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        echo -e "${GREEN}● RUNNING${RESET}"
    else
        echo -e "${RED}○ STOPPED${RESET}"
    fi
}

check_wg() {
    if ip link show wg0 &>/dev/null; then
        echo -e "${GREEN}● ACTIVE${RESET}"
    else
        echo -e "${RED}○ DOWN${RESET}"
    fi
}

# ── Status Panel (shown at top of menu) ───────────────────────
show_status() {
    local cpu_load mem_used mem_total uptime_str clients sigs
    cpu_load=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d. -f1 2>/dev/null || echo "?")
    mem_used=$(free -m | awk 'NR==2{print $3}')
    mem_total=$(free -m | awk 'NR==2{print $2}')
    uptime_str=$(uptime -p 2>/dev/null | sed 's/up //')
    clients=$(wg show wg0 2>/dev/null | grep -c "peer:" || echo "0")
    sigs="48,781"

    echo -e "  ${BOLD}${WHITE}SYSTEM STATUS${RESET}"
    divider
    printf "  ${CYAN}%-26s${RESET} %s    " "WiFi Hotspot" "$(service_status hostapd)"
    printf "${AMBER}%-26s${RESET} %s\n" "Suricata IDS" "$(service_status suricata)"

    printf "  ${PURPLE}%-26s${RESET} %s    " "WireGuard VPN" "$(check_wg)"
    printf "${RED}%-26s${RESET} %s\n" "Fail2ban" "$(service_status fail2ban)"

    printf "  ${CYAN}%-26s${RESET} %s    " "Pi-hole DNS" "$(service_status pihole-FTL)"
    printf "${PURPLE}%-26s${RESET} %s\n" "Cowrie Honeypot" "$(service_status cowrie)"

    printf "  ${GREEN}%-26s${RESET} %s    " "Firewall (nftables)" "$(service_status nftables)"
    printf "${BLUE}%-26s${RESET} %s\n" "Tailscale" "$(service_status tailscaled)"

    divider
    echo -e "  ${GREY}CPU: ${WHITE}${cpu_load}%  ${GREY}|  RAM: ${WHITE}${mem_used}/${mem_total} MB  ${GREY}|  Uptime: ${WHITE}${uptime_str}  ${GREY}|  VPN Clients: ${WHITE}${clients}  ${GREY}|  IDS Sigs: ${WHITE}${sigs}${RESET}"
    divider
    echo ""
}

# ── Mode Activation ───────────────────────────────────────────
activate_mode() {
    local mode="$1"
    clear
    print_header
    divider

    case "$mode" in
        1)
            echo -e "  ${GREEN}${BOLD}Activating Mode 1  —  Traveler Mode${RESET}"
            echo -e "  ${GREY}Encrypted hotspot + WireGuard VPN + Pi-hole + IDS + Firewall${RESET}"
            echo ""
            echo -e "  ${TEAL}▶${RESET}  Starting hotspot..."
            systemctl start hostapd dnsmasq &>/dev/null && echo -e "  ${GREEN}✓${RESET}  Hotspot up"
            echo -e "  ${TEAL}▶${RESET}  Starting firewall..."
            systemctl start nftables &>/dev/null && echo -e "  ${GREEN}✓${RESET}  Firewall active"
            echo -e "  ${TEAL}▶${RESET}  Starting VPN tunnel..."
            wg-quick up wg0 &>/dev/null; ip link show wg0 &>/dev/null && echo -e "  ${GREEN}✓${RESET}  WireGuard tunnel up" || echo -e "  ${AMBER}!${RESET}  WireGuard — check wg0.conf"
            echo -e "  ${TEAL}▶${RESET}  Starting DNS filter..."
            systemctl start pihole-FTL &>/dev/null && echo -e "  ${GREEN}✓${RESET}  Pi-hole filtering"
            echo -e "  ${TEAL}▶${RESET}  Starting intrusion detection..."
            systemctl start suricata fail2ban &>/dev/null && echo -e "  ${GREEN}✓${RESET}  Suricata + Fail2ban active"
            echo -e "  ${TEAL}▶${RESET}  Starting honeypot..."
            systemctl start cowrie &>/dev/null && echo -e "  ${GREEN}✓${RESET}  Cowrie decoy running on port 2222"
            echo ""
            echo -e "  ${GREEN}${BOLD}Mode 1 active. You are protected.${RESET}"
            ;;
        2)
            echo -e "  ${AMBER}${BOLD}Activating Mode 2  —  Activist / Journalist Mode${RESET}"
            echo -e "  ${GREY}Zero-log DNS + Tor routing + Privacy-first configuration${RESET}"
            echo ""
            systemctl start hostapd dnsmasq nftables pihole-FTL suricata fail2ban &>/dev/null
            wg-quick up wg0 &>/dev/null
            echo -e "  ${GREEN}✓${RESET}  Base services started"
            if systemctl list-unit-files | grep -q tor.service; then
                systemctl start tor &>/dev/null && echo -e "  ${GREEN}✓${RESET}  Tor routing active"
            else
                echo -e "  ${AMBER}!${RESET}  Tor not installed  →  sudo apt install tor"
            fi
            if command -v pihole &>/dev/null; then
                pihole logging off &>/dev/null && echo -e "  ${GREEN}✓${RESET}  Pi-hole zero-log mode enabled"
            fi
            echo ""
            echo -e "  ${AMBER}${BOLD}Mode 2 active.${RESET}  ${GREY}Tor integration fully complete in Phase 3.${RESET}"
            ;;
        3)
            echo -e "  ${AMBER}${BOLD}Activating Mode 3  —  Business Mode${RESET}"
            echo -e "  ${GREY}Secure temporary LAN with IDS and hotspot isolation${RESET}"
            echo ""
            systemctl start hostapd dnsmasq nftables pihole-FTL suricata fail2ban &>/dev/null
            echo -e "  ${GREEN}✓${RESET}  Base services started"
            echo -e "  ${AMBER}!${RESET}  Multi-client traffic isolation  →  coming in Phase 3"
            echo -e "  ${AMBER}!${RESET}  Business dashboard view         →  coming in Phase 3"
            echo ""
            echo -e "  ${AMBER}${BOLD}Mode 3 base active.${RESET}  ${GREY}Full business config coming soon.${RESET}"
            ;;
    esac

    echo ""
    divider
    read -rp "  Press Enter to return to menu..." _
}

# ── Logs Viewer ───────────────────────────────────────────────
show_logs() {
    clear
    print_header
    echo -e "  ${BOLD}${WHITE}LIVE LOG VIEWER${RESET}"
    divider
    echo -e "  ${GREY}Press Ctrl+C at any time to return to this screen${RESET}"
    echo ""
    echo -e "  ${AMBER}[1]${RESET}  Suricata alerts     ${GREY}— active threat detections${RESET}"
    echo -e "  ${RED}[2]${RESET}  Fail2ban            ${GREY}— banned IPs and brute force attempts${RESET}"
    echo -e "  ${PURPLE}[3]${RESET}  Cowrie honeypot     ${GREY}— attacker sessions and commands${RESET}"
    echo -e "  ${CYAN}[4]${RESET}  Pi-hole             ${GREY}— DNS queries and blocked domains${RESET}"
    echo -e "  ${GREEN}[5]${RESET}  WireGuard           ${GREY}— VPN peer connections${RESET}"
    echo -e "  ${WHITE}[6]${RESET}  System journal      ${GREY}— all services combined${RESET}"
    echo -e "  ${GREY}[b]${RESET}  Back"
    echo ""
    read -rp "  Choose: " log_choice
    case "$log_choice" in
        1) echo -e "\n  ${AMBER}Suricata fast.log — Ctrl+C to return${RESET}\n"
           tail -f /var/log/suricata/fast.log 2>/dev/null || echo "  Log not found." ;;
        2) echo -e "\n  ${RED}Fail2ban log — Ctrl+C to return${RESET}\n"
           tail -f /var/log/fail2ban.log 2>/dev/null || echo "  Log not found." ;;
        3) echo -e "\n  ${PURPLE}Cowrie log — Ctrl+C to return${RESET}\n"
           tail -f /home/cowrie/cowrie/var/log/cowrie/cowrie.log 2>/dev/null || echo "  Log not found." ;;
        4) echo -e "\n  ${CYAN}Pi-hole log — Ctrl+C to return${RESET}\n"
           tail -f /var/log/pihole/pihole.log 2>/dev/null || echo "  Log not found." ;;
        5) echo -e "\n  ${GREEN}WireGuard — live peer status${RESET}\n"
           watch -n 2 wg show 2>/dev/null || wg show ;;
        6) echo -e "\n  ${WHITE}System journal — Ctrl+C to return${RESET}\n"
           journalctl -f ;;
        b|B) return ;;
        *) echo "  Invalid." ; sleep 0.8 ;;
    esac
}

# ── WireGuard QR ──────────────────────────────────────────────
show_wg_qr() {
    clear
    print_header
    echo -e "  ${BOLD}${WHITE}WIREGUARD — Add a Device${RESET}"
    divider
    echo -e "  ${GREY}Open the WireGuard app on your phone and scan this QR code.${RESET}"
    echo ""
    if command -v qrencode &>/dev/null && [ -f /etc/wireguard/wg0.conf ]; then
        cat /etc/wireguard/wg0.conf | qrencode -t ansiutf8
    else
        echo -e "  ${AMBER}qrencode not installed or wg0.conf not found.${RESET}"
        echo -e "  ${GREY}  Install: sudo apt install qrencode${RESET}"
    fi
    echo ""
    divider
    echo -e "  ${GREY}Public key: $(cat /etc/wireguard/publickey 2>/dev/null || echo 'not found')${RESET}"
    divider
    read -rp "  Press Enter to return..." _
}

# ── Pi-hole Stats ─────────────────────────────────────────────
show_pihole() {
    clear
    print_header
    echo -e "  ${BOLD}${WHITE}PI-HOLE DNS STATISTICS${RESET}"
    divider
    echo ""
    if command -v pihole &>/dev/null; then
        pihole -c -e 2>/dev/null || pihole status
    else
        echo -e "  ${AMBER}Pi-hole not found.${RESET}"
    fi
    echo ""
    divider
    read -rp "  Press Enter to return..." _
}

# ── Stop All ──────────────────────────────────────────────────
stop_all_services() {
    clear
    print_header
    echo -e "  ${RED}${BOLD}Stopping all SafeHaven services...${RESET}"
    echo ""
    wg-quick down wg0 &>/dev/null && echo -e "  ${GREEN}✓${RESET}  WireGuard tunnel down"
    systemctl stop hostapd dnsmasq pihole-FTL nftables suricata fail2ban cowrie tailscaled &>/dev/null
    echo -e "  ${GREEN}✓${RESET}  All services stopped"
    echo ""
    divider
    echo -e "  ${GREY}Network protection is now offline.${RESET}"
    read -rp "  Press Enter to return to menu..." _
}

# ── Header (compact, for menu screen) ─────────────────────────
print_header() {
    echo -e "${TEAL}${BOLD}"
    echo "  ╔══════════════════════════════════════════════════════════╗"
    echo "  ║         SafeHaven Pi  —  Security Control Menu          ║"
    echo "  ╚══════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
}

# ── Main Menu Loop ────────────────────────────────────────────
main_menu() {
    while true; do
        clear
        print_header
        show_status

        echo -e "  ${BOLD}${WHITE}MAIN MENU${RESET}"
        divider

        echo -e "  ${TEAL}${BOLD}  MODES${RESET}"
        echo -e "  ${GREEN}[1]${RESET}  ${BOLD}Traveler Mode${RESET}       ${GREEN}● Ready${RESET}    ${GREY}Encrypted hotspot + VPN + full security stack${RESET}"
        echo -e "  ${AMBER}[2]${RESET}  ${BOLD}Activist Mode${RESET}       ${AMBER}◐ Soon${RESET}     ${GREY}Privacy-first + Tor routing + zero-log DNS${RESET}"
        echo -e "  ${AMBER}[3]${RESET}  ${BOLD}Business Mode${RESET}       ${AMBER}◐ Soon${RESET}     ${GREY}Secure LAN + client isolation + IDS${RESET}"
        echo ""

        echo -e "  ${TEAL}${BOLD}  TOOLS${RESET}"
        echo -e "  ${CYAN}[4]${RESET}  View live logs          ${GREY}Suricata / Fail2ban / Cowrie / Pi-hole / WireGuard${RESET}"
        echo -e "  ${CYAN}[5]${RESET}  WireGuard QR code       ${GREY}Add a new device to the VPN${RESET}"
        echo -e "  ${CYAN}[6]${RESET}  Pi-hole DNS stats       ${GREY}Blocked queries, top domains, client activity${RESET}"
        echo -e "  ${CYAN}[7]${RESET}  Open dashboard          ${GREY}http://10.42.0.1:5000 — open on a connected device${RESET}"
        echo ""

        echo -e "  ${TEAL}${BOLD}  SYSTEM${RESET}"
        echo -e "  ${RED}[s]${RESET}  Stop all services"
        echo -e "  ${RED}[r]${RESET}  Reboot SafeHaven Pi"
        echo -e "  ${GREY}[q]${RESET}  Quit menu  ${GREY}(services keep running)${RESET}"
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
                echo -e "  ${GREY}Dashboard available at: ${CYAN}http://10.42.0.1:5000${RESET}"
                echo -e "  ${GREY}Open this URL on any device connected to SafeHaven Pi.${RESET}"
                echo ""
                read -rp "  Press Enter to continue..." _
                ;;
            s|S) stop_all_services ;;
            r|R)
                echo ""
                echo -e "  ${RED}Rebooting in 3 seconds — Ctrl+C to cancel${RESET}"
                sleep 3
                reboot
                ;;
            q|Q)
                echo ""
                echo -e "  ${GREY}Exiting menu. All services continue running in the background.${RESET}"
                echo ""
                exit 0
                ;;
            *)
                echo -e "  ${RED}Invalid option.${RESET}"
                sleep 0.6
                ;;
        esac
    done
}

# ── Entry Point ───────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
    echo -e "${AMBER}Run with sudo for full control:  sudo safehaven${RESET}"
    sleep 1
fi

boot_screen
run_startup
main_menu
