#!/bin/bash
# ============================================================
#  SafeHaven Pi — Terminal Control Menu
#  Run on boot or manually:  sudo bash safehaven_menu.sh
# ============================================================

# ── Colours ──────────────────────────────────────────────────
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

BG_NAVY='\033[48;5;17m'
BG_TEAL='\033[48;5;30m'
BG_RED='\033[48;5;88m'
BG_AMBER='\033[48;5;136m'
BG_GREEN='\033[48;5;22m'
BG_DARK='\033[48;5;234m'

TEAL='\033[38;5;86m'
CYAN='\033[38;5;117m'
GREEN='\033[38;5;82m'
AMBER='\033[38;5;214m'
RED='\033[38;5;196m'
WHITE='\033[38;5;255m'
GREY='\033[38;5;244m'
PURPLE='\033[38;5;141m'

# ── Helpers ───────────────────────────────────────────────────
clear_screen() { clear; }

print_header() {
    echo -e "${TEAL}${BOLD}"
    echo "  ╔══════════════════════════════════════════════════════════╗"
    echo "  ║           SafeHaven Pi  —  Security Control              ║"
    echo "  ║       Privacy is a right, not a product.                 ║"
    echo "  ╚══════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
}

print_divider() {
    echo -e "${GREY}  ──────────────────────────────────────────────────────────${RESET}"
}

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

# ── Status Panel ──────────────────────────────────────────────
show_status() {
    clear_screen
    print_header
    echo -e "  ${BOLD}${WHITE}SYSTEM STATUS${RESET}"
    print_divider

    printf "  %-28s %s\n" \
        "$(echo -e "${CYAN}WiFi Hotspot (hostapd)${RESET}")" \
        "$(service_status hostapd)"
    printf "  %-28s %s\n" \
        "$(echo -e "${CYAN}DHCP / DNS (dnsmasq)${RESET}")" \
        "$(service_status dnsmasq)"
    printf "  %-28s %s\n" \
        "$(echo -e "${PURPLE}VPN Tunnel (WireGuard)${RESET}")" \
        "$(check_wg)"
    printf "  %-28s %s\n" \
        "$(echo -e "${CYAN}DNS Filter (Pi-hole)${RESET}")" \
        "$(service_status pihole-FTL)"
    printf "  %-28s %s\n" \
        "$(echo -e "${AMBER}Firewall (nftables)${RESET}")" \
        "$(service_status nftables)"
    printf "  %-28s %s\n" \
        "$(echo -e "${AMBER}Intrusion Detection (Suricata)${RESET}")" \
        "$(service_status suricata)"
    printf "  %-28s %s\n" \
        "$(echo -e "${RED}Brute Force Block (Fail2ban)${RESET}")" \
        "$(service_status fail2ban)"
    printf "  %-28s %s\n" \
        "$(echo -e "${PURPLE}Honeypot (Cowrie)${RESET}")" \
        "$(service_status cowrie)"
    printf "  %-28s %s\n" \
        "$(echo -e "${CYAN}Remote Access (Tailscale)${RESET}")" \
        "$(service_status tailscaled)"

    print_divider

    # Quick stats
    local cpu_load
    cpu_load=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d. -f1 2>/dev/null || echo "?")
    local mem_used mem_total
    mem_used=$(free -m | awk 'NR==2{print $3}')
    mem_total=$(free -m | awk 'NR==2{print $2}')
    local uptime_str
    uptime_str=$(uptime -p 2>/dev/null | sed 's/up //')

    echo -e "  ${GREY}CPU: ${WHITE}${cpu_load}%${GREY}   RAM: ${WHITE}${mem_used}/${mem_total} MB${GREY}   Uptime: ${WHITE}${uptime_str}${RESET}"
    print_divider
    echo ""
}

# ── Mode Switcher ─────────────────────────────────────────────
activate_mode_1() {
    echo -e "\n  ${TEAL}${BOLD}Activating Mode 1 — Traveler Mode${RESET}"
    echo -e "  ${GREY}Encrypted hotspot + VPN + DNS filter + IDS${RESET}\n"
    sudo systemctl start hostapd dnsmasq pihole-FTL nftables suricata fail2ban cowrie
    sudo wg-quick up wg0 2>/dev/null || echo -e "  ${AMBER}WireGuard already up or config missing${RESET}"
    echo -e "\n  ${GREEN}Mode 1 services started.${RESET}"
    sleep 1
}

activate_mode_2() {
    echo -e "\n  ${TEAL}${BOLD}Activating Mode 2 — Activist / Journalist Mode${RESET}"
    echo -e "  ${GREY}Privacy-first: VPN + DNS + Tor routing${RESET}\n"
    # Start base services
    sudo systemctl start hostapd dnsmasq pihole-FTL nftables suricata fail2ban
    sudo wg-quick up wg0 2>/dev/null
    # Tor — start if installed
    if systemctl list-unit-files | grep -q tor.service; then
        sudo systemctl start tor
        echo -e "  ${GREEN}Tor started.${RESET}"
    else
        echo -e "  ${AMBER}Tor not installed. Run: sudo apt install tor${RESET}"
    fi
    # Disable Pi-hole query logging for zero-log mode
    if command -v pihole &>/dev/null; then
        sudo pihole logging off &>/dev/null
        echo -e "  ${GREEN}Pi-hole query logging disabled (zero-log mode).${RESET}"
    fi
    echo -e "\n  ${GREEN}Mode 2 services started.${RESET}"
    sleep 1
}

activate_mode_3() {
    echo -e "\n  ${TEAL}${BOLD}Activating Mode 3 — Business Mode${RESET}"
    echo -e "  ${GREY}Secure temporary LAN + IDS + hotspot isolation${RESET}\n"
    sudo systemctl start hostapd dnsmasq pihole-FTL nftables suricata fail2ban
    echo -e "  ${AMBER}Note: Multi-client traffic isolation — in development.${RESET}"
    echo -e "  ${AMBER}Note: Business dashboard view — in development.${RESET}"
    echo -e "\n  ${GREEN}Mode 3 base services started.${RESET}"
    sleep 1
}

stop_all() {
    echo -e "\n  ${RED}Stopping all SafeHaven services...${RESET}"
    sudo wg-quick down wg0 2>/dev/null
    sudo systemctl stop hostapd dnsmasq pihole-FTL nftables suricata fail2ban cowrie tailscaled 2>/dev/null
    echo -e "  ${GREEN}All services stopped.${RESET}"
    sleep 1
}

# ── Logs Viewer ───────────────────────────────────────────────
show_logs() {
    clear_screen
    print_header
    echo -e "  ${BOLD}${WHITE}LIVE LOG VIEWER${RESET}"
    print_divider
    echo -e "  ${GREY}Choose a log to tail (Ctrl+C to return to menu)${RESET}\n"
    echo -e "  ${CYAN}[1]${RESET} Suricata alerts  (active threats)"
    echo -e "  ${CYAN}[2]${RESET} Fail2ban          (banned IPs)"
    echo -e "  ${CYAN}[3]${RESET} Cowrie honeypot   (attacker sessions)"
    echo -e "  ${CYAN}[4]${RESET} Pi-hole           (DNS queries)"
    echo -e "  ${CYAN}[5]${RESET} System journal     (all services)"
    echo -e "  ${CYAN}[b]${RESET} Back to main menu"
    echo ""
    read -rp "  Choose: " log_choice
    case "$log_choice" in
        1) sudo tail -f /var/log/suricata/fast.log 2>/dev/null || echo "Log not found" ;;
        2) sudo tail -f /var/log/fail2ban.log 2>/dev/null || echo "Log not found" ;;
        3) sudo tail -f /home/cowrie/var/log/cowrie/cowrie.log 2>/dev/null || echo "Log not found" ;;
        4) sudo tail -f /var/log/pihole/pihole.log 2>/dev/null || echo "Log not found" ;;
        5) sudo journalctl -f ;;
        b|B) return ;;
        *) echo "Invalid option" ;;
    esac
}

# ── WireGuard QR ──────────────────────────────────────────────
show_wg_qr() {
    clear_screen
    print_header
    echo -e "  ${BOLD}${WHITE}WIREGUARD — Add New Device${RESET}"
    print_divider
    echo -e "  ${GREY}Scan this QR code with the WireGuard mobile app${RESET}\n"
    if command -v qrencode &>/dev/null && [ -f /etc/wireguard/wg0.conf ]; then
        sudo cat /etc/wireguard/wg0.conf | qrencode -t ansiutf8
    else
        echo -e "  ${AMBER}qrencode not installed or wg0.conf not found.${RESET}"
        echo -e "  ${GREY}Install with: sudo apt install qrencode${RESET}"
    fi
    print_divider
    read -rp "  Press Enter to return..." _
}

# ── Pi-hole Stats ─────────────────────────────────────────────
show_pihole_stats() {
    clear_screen
    print_header
    echo -e "  ${BOLD}${WHITE}PI-HOLE DNS STATS${RESET}"
    print_divider
    if command -v pihole &>/dev/null; then
        pihole -c -e 2>/dev/null || pihole status 2>/dev/null
    else
        echo -e "  ${AMBER}Pi-hole not installed or not in PATH.${RESET}"
    fi
    print_divider
    read -rp "  Press Enter to return..." _
}

# ── Main Menu ─────────────────────────────────────────────────
main_menu() {
    while true; do
        clear_screen
        print_header
        show_status

        echo -e "  ${BOLD}${WHITE}MAIN MENU${RESET}"
        print_divider
        echo -e "  ${TEAL}${BOLD}── MODES ────────────────────────────────────────────${RESET}"
        echo -e "  ${GREEN}[1]${RESET} ${BOLD}Mode 1${RESET} — Traveler        ${GREY}Encrypted hotspot + VPN + IDS${RESET}"
        echo -e "  ${AMBER}[2]${RESET} ${BOLD}Mode 2${RESET} — Activist         ${GREY}Privacy + Tor (in development)${RESET}"
        echo -e "  ${AMBER}[3]${RESET} ${BOLD}Mode 3${RESET} — Business         ${GREY}Secure LAN (in development)${RESET}"
        echo ""
        echo -e "  ${TEAL}${BOLD}── TOOLS ────────────────────────────────────────────${RESET}"
        echo -e "  ${CYAN}[4]${RESET} View live logs"
        echo -e "  ${CYAN}[5]${RESET} WireGuard QR code (add a device)"
        echo -e "  ${CYAN}[6]${RESET} Pi-hole DNS statistics"
        echo -e "  ${CYAN}[7]${RESET} Open dashboard  ${GREY}(http://10.42.0.1:5000)${RESET}"
        echo ""
        echo -e "  ${TEAL}${BOLD}── SYSTEM ───────────────────────────────────────────${RESET}"
        echo -e "  ${RED}[s]${RESET} Stop all services"
        echo -e "  ${RED}[r]${RESET} Reboot Pi"
        echo -e "  ${RED}[q]${RESET} Quit menu (services keep running)"
        print_divider
        echo ""
        read -rp "  $(echo -e "${TEAL}SafeHaven${RESET}") > " choice

        case "$choice" in
            1) activate_mode_1 ;;
            2) activate_mode_2 ;;
            3) activate_mode_3 ;;
            4) show_logs ;;
            5) show_wg_qr ;;
            6) show_pihole_stats ;;
            7)
                echo -e "\n  ${GREY}Dashboard: open ${CYAN}http://10.42.0.1:5000${GREY} on a connected device.${RESET}"
                sleep 2
                ;;
            s|S) stop_all ;;
            r|R)
                echo -e "\n  ${RED}Rebooting in 3 seconds... (Ctrl+C to cancel)${RESET}"
                sleep 3
                sudo reboot
                ;;
            q|Q)
                echo -e "\n  ${GREY}Exiting menu. Services continue running.${RESET}\n"
                exit 0
                ;;
            *)
                echo -e "\n  ${RED}Invalid option.${RESET}"
                sleep 0.8
                ;;
        esac
    done
}

# ── Entry Point ───────────────────────────────────────────────
# Check we're running as root (needed for systemctl)
if [ "$EUID" -ne 0 ]; then
    echo -e "${AMBER}Note: Run with sudo for full control. Some features may be limited.${RESET}"
    sleep 1
fi

main_menu
