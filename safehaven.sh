#!/bin/bash
# ============================================================
#  SafeHaven Pi — Startup & Control
#  Usage:  sudo safehaven
#  Install to /usr/local/bin/safehaven via install.sh
# ============================================================

# ── Repository paths (auto-detected) ─────────────────────────
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# ── Terminal width detection ───────────────────────────────────
TERM_COLS=$(tput cols 2>/dev/null || echo 80)
# Mobile layout when terminal is narrower than 80 columns.
# 80 is the standard terminal default width — the wide block-font
# logo measures 78 columns, so 80+ has just enough room. This means:
#   - Default Pi LXTerminal (80×24)         → wide layout (matches README screenshots)
#   - Default SSH client / Windows Terminal → wide layout
#   - Termux on phone (~40-50 cols)         → mobile layout (genuinely needed)
is_mobile() { [ "$TERM_COLS" -lt 80 ]; }

# ── Helpers ───────────────────────────────────────────────────
spinner() {
    local pid=$1
    local delay=0.1
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf " ${TEAL}%s${RESET}" "${frames[$i]}"
        sleep $delay
        printf "\b\b"
        i=$(( (i+1) % ${#frames[@]} ))
    done
    printf "  \b\b"
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
    local width=$(( TERM_COLS > 6 ? TERM_COLS - 4 : 40 ))
    local line
    line=$(printf '─%.0s' $(seq 1 "$width"))
    echo -e "  ${GREY}${line}${RESET}"
}

thin_divider() {
    local width=$(( TERM_COLS > 6 ? TERM_COLS - 4 : 40 ))
    local line=""
    local i=0
    while [ $i -lt "$width" ]; do
        line="${line}· "
        i=$(( i + 2 ))
    done
    echo -e "  ${GREY}${line}${RESET}"
}

# ── Boot Screen ───────────────────────────────────────────────
boot_screen() {
    clear
    echo ""
    if is_mobile; then
        echo -e "  ${TEAL}${BOLD}╔══════════════════════════╗${RESET}"
        echo -e "  ${TEAL}${BOLD}║                          ║${RESET}"
        echo -e "  ${TEAL}${BOLD}║     S A F E H A V E N    ║${RESET}"
        echo -e "  ${TEAL}${BOLD}║       P R I V A C Y      ║${RESET}"
        echo -e "  ${TEAL}${BOLD}║           P I            ║${RESET}"
        echo -e "  ${TEAL}${BOLD}║                          ║${RESET}"
        echo -e "  ${TEAL}${BOLD}╚══════════════════════════╝${RESET}"
    else
        echo -e "${TEAL}${BOLD}"
        echo "  ███████╗ █████╗ ███████╗███████╗██╗  ██╗ █████╗ ██╗   ██╗███████╗███╗   ██╗"
        echo "  ██╔════╝██╔══██╗██╔════╝██╔════╝██║  ██║██╔══██╗██║   ██║██╔════╝████╗  ██║"
        echo "  ███████╗███████║█████╗  █████╗  ███████║███████║██║   ██║█████╗  ██╔██╗ ██║"
        echo "  ╚════██║██╔══██║██╔══╝  ██╔══╝  ██╔══██║██╔══██║╚██╗ ██╔╝██╔══╝  ██║╚██╗██║"
        echo "  ███████║██║  ██║██║     ███████╗██║  ██║██║  ██║ ╚████╔╝ ███████╗██║ ╚████║"
        echo "  ╚══════╝╚═╝  ╚═╝╚═╝     ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝  ╚═══╝  ╚══════╝╚═╝  ╚═══╝"
        echo -e "${RESET}"
        echo -e "  ${TEAL}${BOLD}                        P R I V A C Y   P I${RESET}"
    fi
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

    if is_mobile; then
        # Single column layout for narrow screens
        printf "  ${GREY}WiFi Hotspot      ${RESET}"; svc_status_inline "hostapd";    echo ""
        printf "  ${GREY}VPN Tunnel        ${RESET}"; wg_status_inline;               echo ""
        printf "  ${GREY}DNS Filter        ${RESET}"; svc_status_inline "pihole-FTL"; echo ""
        printf "  ${GREY}Firewall          ${RESET}"; svc_status_inline "nftables";   echo ""
        printf "  ${GREY}Threat Detection  ${RESET}"; svc_status_inline "suricata";   echo ""
        printf "  ${GREY}Brute Force Block ${RESET}"; svc_status_inline "fail2ban";   echo ""
        printf "  ${GREY}Honeypot Decoy    ${RESET}"; svc_status_inline "cowrie";     echo ""
        printf "  ${GREY}Remote Admin      ${RESET}"; svc_status_inline "tailscaled"; echo ""
    else
        # Row 1
        printf "  "
        printf "${GREY}WiFi Hotspot      ${RESET}"; svc_status_inline "hostapd"
        printf "     "
        printf "${GREY}VPN Tunnel        ${RESET}"; wg_status_inline
        printf "     "
        printf "${GREY}DNS Filter        ${RESET}"; svc_status_inline "pihole-FTL"
        echo ""

        # Row 2
        printf "  "
        printf "${GREY}Firewall          ${RESET}"; svc_status_inline "nftables"
        printf "     "
        printf "${GREY}Threat Detection  ${RESET}"; svc_status_inline "suricata"
        printf "     "
        printf "${GREY}Brute Force Block ${RESET}"; svc_status_inline "fail2ban"
        echo ""

        # Row 3
        printf "  "
        printf "${GREY}Honeypot Decoy    ${RESET}"; svc_status_inline "cowrie"
        printf "     "
        printf "${GREY}Remote Admin      ${RESET}"; svc_status_inline "tailscaled"
        echo ""
    fi
    echo ""

    thin_divider
    echo ""
    # ── Active Mode Banner ────────────────────────────────────
    if [ -f /tmp/safehaven-mode ]; then
        local mode_line mode_num mode_name mode_note mode_col
        mode_line=$(cat /tmp/safehaven-mode 2>/dev/null)
        mode_num=$(echo "$mode_line" | cut -d: -f1)
        mode_name=$(echo "$mode_line" | cut -d: -f2)
        mode_note=$(echo "$mode_line" | cut -d: -f3-)
        case $mode_num in
            1) mode_col="${GREEN}"  ;;
            2) mode_col="${AMBER}"  ;;
            3) mode_col="${AMBER}"  ;;
            4) mode_col="${CYAN}"   ;;
            *) mode_col="${GREY}"   ;;
        esac
        echo -e "  ${GREY}Active Mode:${RESET}  ${mode_col}${BOLD}${mode_name}${RESET}  ${GREY}— ${mode_note}${RESET}"
        echo ""
    fi
    # Last threat from Suricata
    local last_threat
    last_threat=$(tail -1 /var/log/suricata/fast.log 2>/dev/null | grep -oP '(?<=\] \*\* )[^*]+' | head -1 | xargs 2>/dev/null || echo "None detected")

    # Blocked domains count — Pi-hole v6 with cli_pw auth
    local blocked_count ph_cli_pw ph_sid
    ph_cli_pw=$(cat /etc/pihole/cli_pw 2>/dev/null)
    if [ -n "$ph_cli_pw" ]; then
        ph_sid=$(curl -s -X POST "http://localhost/api/auth" \
            -H "Content-Type: application/json" \
            -d "{\"password\":\"${ph_cli_pw}\"}" 2>/dev/null \
            | grep -o '"sid":"[^"]*"' | cut -d: -f2 | tr -d '"')
        blocked_count=$(curl -s "http://localhost/api/stats/summary" -H "X-FTL-SID: ${ph_sid}" 2>/dev/null \
            | grep -o '"blocked":[0-9]*' | head -1 | cut -d: -f2)
    fi
    blocked_count="${blocked_count:-?}"

    if is_mobile; then
        echo -e "  ${GREY}CPU ${WHITE}${cpu_load}%${GREY}  RAM ${WHITE}${mem_used}/${mem_total}MB${GREY}  VPN ${WHITE}${vpn_clients}${RESET}"
        echo -e "  ${GREY}Uptime ${WHITE}${uptime_str}${RESET}"
        echo -e "  ${GREY}Blocked: ${WHITE}${blocked_count}${GREY}  Threat: ${AMBER}${last_threat}${RESET}"
    else
        echo -e "  ${GREY}CPU ${WHITE}${cpu_load}%${GREY}   RAM ${WHITE}${mem_used}/${mem_total} MB${GREY}   Uptime ${WHITE}${uptime_str}${GREY}   VPN Clients ${WHITE}${vpn_clients}${RESET}"
        echo ""
        echo -e "  ${GREY}Domains blocked today: ${WHITE}${blocked_count}${GREY}   Last threat: ${AMBER}${last_threat}${RESET}"
    fi
    echo ""
    divider
    echo ""
}

# ── Header ────────────────────────────────────────────────────
print_header() {
    local pi_model
    pi_model=$(cat /proc/device-tree/model 2>/dev/null | tr -d '\0' || echo "Raspberry Pi")
    # Refresh terminal width each time the menu redraws
    TERM_COLS=$(tput cols 2>/dev/null || echo 80)

    clear
    echo ""
    if is_mobile; then
        echo -e "  ${TEAL}${BOLD}╔══════════════════════════╗${RESET}"
        echo -e "  ${TEAL}${BOLD}║   S A F E H A V E N      ║${RESET}"
        echo -e "  ${TEAL}${BOLD}║   Security Control Menu  ║${RESET}"
        echo -e "  ${TEAL}${BOLD}╚══════════════════════════╝${RESET}"
        echo -e "  ${GREY}v1.0-alpha  ·  UWTSD 2026${RESET}"
    else
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
    fi
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
        echo -e "  ${GREEN}[2]${RESET}  ${BOLD}Activist Mode${RESET}   ${GREEN}● Ready${RESET}"
        echo -e "       ${GREY}Maximum privacy — Tor routing, zero logs, no trace left behind.${RESET}"
        echo -e "       ${GREY}For journalists, activists, or anyone who needs total anonymity.${RESET}"
        echo ""
        echo -e "  ${GREEN}[3]${RESET}  ${BOLD}Business Mode${RESET}   ${GREEN}● Ready${RESET}"
        echo -e "       ${GREY}Set up a secure temporary network with per-user login. Includes${RESET}"
        echo -e "       ${GREY}a captive portal and admin panel for managing connected users.${RESET}"
        echo ""
        echo -e "  ${CYAN}[4]${RESET}  ${BOLD}Relaxed Mode${RESET}   ${CYAN}● Ready${RESET}"
        echo -e "       ${GREY}Full security without VPN — Pi-hole, firewall and threat detection${RESET}"
        echo -e "       ${GREY}stay active. Use when sites block VPN traffic.${RESET}"
        echo ""
        divider

        # ── Tools ─────────────────────────────────────────────
        echo -e "  ${TEAL}${BOLD}  TOOLS  ${RESET}${GREY}— dig deeper into what SafeHaven Pi is doing${RESET}"
        echo ""
        if is_mobile; then
            echo -e "  ${CYAN}[5]${RESET}  ${BOLD}Live Security Logs${RESET}"
            echo -e "       ${GREY}Real-time threats, blocked sites, VPN activity${RESET}"
            echo -e "  ${CYAN}[6]${RESET}  ${BOLD}Manage VPN Devices${RESET}"
            echo -e "       ${GREY}Add, list, or remove devices${RESET}"
            echo -e "  ${CYAN}[7]${RESET}  ${BOLD}DNS Block Stats${RESET}"
            echo -e "       ${GREY}Pi-hole blocked domains${RESET}"
            echo -e "  ${CYAN}[8]${RESET}  ${BOLD}Web Dashboard${RESET}"
            echo -e "       ${GREY}https://10.42.0.1:5000${RESET}"
            echo -e "  ${CYAN}[9]${RESET}  ${BOLD}Mobile Access (Termux)${RESET}"
            echo -e "       ${GREY}How to manage SafeHaven from your phone${RESET}"
            echo -e "  ${CYAN}[0]${RESET}  ${BOLD}Export Security Report${RESET}"
            echo -e "       ${GREY}Save last 24hrs to file${RESET}"
        else
            echo -e "  ${CYAN}[5]${RESET}  ${BOLD}Live Security Logs${RESET}   ${GREY}See real-time threats, blocked sites, VPN activity${RESET}"
            echo -e "  ${CYAN}[6]${RESET}  ${BOLD}Manage VPN Devices${RESET}   ${GREY}Add new devices, list connected ones, or remove access${RESET}"
            echo -e "  ${CYAN}[7]${RESET}  ${BOLD}DNS Block Stats${RESET}      ${GREY}See how many ads and trackers Pi-hole has blocked${RESET}"
            echo -e "  ${CYAN}[8]${RESET}  ${BOLD}Web Dashboard${RESET}        ${GREY}Open https://10.42.0.1:5000 on any connected device${RESET}"
            echo -e "  ${CYAN}[9]${RESET}  ${BOLD}Mobile Access (Termux)${RESET}  ${GREY}How to manage SafeHaven Pi from your phone${RESET}"
            echo -e "  ${CYAN}[0]${RESET}  ${BOLD}Export Security Report${RESET}  ${GREY}Save last 24hrs of threats, bans and DNS blocks to a file${RESET}"
        fi
        echo ""
        divider

        # ── System ────────────────────────────────────────────
        echo -e "  ${TEAL}${BOLD}  SYSTEM${RESET}"
        echo ""
        echo -e "  ${CYAN}[w]${RESET}  ${BOLD}Setup Wizard${RESET}         ${GREY}Configure hotspot, hostname, password and VPN keys${RESET}"
        echo -e "  ${RED}[s]${RESET}  ${BOLD}Stop All Services${RESET}    ${GREY}Safely shut down all protection layers${RESET}"
        echo -e "  ${RED}[r]${RESET}  ${BOLD}Reboot Pi${RESET}            ${GREY}Restart the device — all services resume on boot${RESET}"
        echo -e "  ${RED}[x]${RESET}  ${BOLD}Shutdown Pi${RESET}          ${GREY}Power off safely — prevents SD card corruption${RESET}"
        echo -e "  ${RED}[f]${RESET}  ${BOLD}Factory Reset${RESET}        ${GREY}Wipe all credentials and sessions — keeps HTTPS cert${RESET}"
        echo -e "  ${GREY}[q]${RESET}  ${BOLD}Quit This Menu${RESET}       ${GREY}Exit to terminal — protection keeps running${RESET}"
        echo ""
        divider
        echo ""
        read -rp "  $(echo -e "${TEAL}${BOLD}safehaven${RESET}") ❯ " choice

        case "$choice" in
            1) activate_mode 1 ;;
            2) activate_mode 2 ;;
            3) activate_mode 3 ;;
            4) activate_mode 4 ;;
            5) show_logs ;;
            6) manage_devices ;;
            7) show_pihole ;;
            8)
                echo ""
                echo -e "  ${GREY}Open this address on any device connected to SafeHaven Pi:${RESET}"
                echo ""
                echo -e "  ${CYAN}${BOLD}  → https://10.42.0.1:5000${RESET}"
                echo ""
                read -rp "  Press Enter to return to menu..." _
                ;;
            9)
                echo ""
                divider
                echo -e "  ${BLUE}${BOLD}MOBILE ACCESS — Manage SafeHaven Pi from your phone${RESET}"
                divider
                echo ""
                echo -e "  ${BOLD}1.${RESET} ${GREY}Install Termux from F-Droid on your Android phone${RESET}"
                echo -e "  ${BOLD}2.${RESET} ${GREY}Run: ${WHITE}pkg update && pkg install openssh${RESET}"
                echo -e "  ${BOLD}3.${RESET} ${GREY}Enable Tailscale on your phone${RESET}"
                echo -e "  ${BOLD}4.${RESET} ${GREY}SSH in: ${WHITE}ssh <your-username>@$(ip addr show tailscale0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)${RESET}"
                echo -e "  ${BOLD}5.${RESET} ${GREY}Run: ${WHITE}cd SafeHaven-PI && sudo bash safehaven.sh${RESET}"
                echo ""
                echo -e "  ${GREY}Full guide: github.com/MursheenDurkin/SafeHaven-PI${RESET}"
                echo ""
                read -rp "  Press Enter to return to menu..." _
                ;;
            0) export_threat_log ;;
            w|W) setup_wizard ;;
            s|S) stop_all_services ;;
            r|R)
                echo ""
                echo -e "  ${RED}Rebooting in 3 seconds — press Ctrl+C to cancel${RESET}"
                sleep 3
                reboot
                ;;
            x|X)
                echo ""
                echo -e "  ${RED}${BOLD}Shutdown SafeHaven Pi?${RESET}"
                echo -e "  ${GREY}The Pi will power off. Unplug only after the green LED stops flickering.${RESET}"
                echo ""
                read -rp "  $(echo -e "${AMBER}Type 'yes' to confirm, anything else to cancel${RESET}") ❯ " confirm
                if [[ "$confirm" == "yes" ]]; then
                    echo ""
                    echo -e "  ${RED}Powering off in 3 seconds — press Ctrl+C to cancel${RESET}"
                    sleep 3
                    shutdown -h now
                else
                    echo ""
                    echo -e "  ${GREY}Shutdown cancelled.${RESET}"
                    sleep 1
                fi
                ;;
            f|F) factory_reset ;;
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

            # ── Clean up Mode 2 if it was active ──────────────
            if systemctl is-active --quiet tor@default 2>/dev/null; then
                printf "  ${GREY}%-38s${RESET}" "Stopping Tor..."
                systemctl stop tor@default >/dev/null 2>/dev/null && printf "${GREEN}✓  Tor stopped${RESET}\n" || printf "${AMBER}!  Could not stop Tor${RESET}\n"
            fi
            if ! ip link show wg0 &>/dev/null; then
                printf "  ${GREY}%-38s${RESET}" "Restoring WireGuard..."
                wg-quick up wg0 >/dev/null 2>/dev/null && printf "${GREEN}✓  WireGuard restored${RESET}\n" || printf "${AMBER}!  Check wg0.conf${RESET}\n"
            fi
            printf "  ${GREY}%-38s${RESET}" "Restoring firewall rules..."
            systemctl restart nftables >/dev/null 2>/dev/null && printf "${GREEN}✓  Mode 1 firewall active${RESET}\n" || printf "${RED}✗  Failed${RESET}\n"
            pihole logging on >/dev/null 2>/dev/null

            printf "  ${GREY}%-38s${RESET}" "Starting WiFi hotspot..."
            systemctl start hostapd >/dev/null 2>/dev/null && printf "${GREEN}✓  Hotspot broadcasting${RESET}\n" || printf "${RED}✗  Failed — check hostapd config${RESET}\n"

            printf "  ${GREY}%-38s${RESET}" "Starting firewall..."
            # Use restart, not start — ensures /etc/nftables.conf is reloaded
            # even if nftables was already running (e.g. after switching modes).
            # Without this, the NAT masquerade rule can be missing if another
            # mode previously flushed the ruleset.
            systemctl restart nftables >/dev/null 2>/dev/null && printf "${GREEN}✓  Firewall active${RESET}\n" || printf "${RED}✗  Failed${RESET}\n"

            printf "  ${GREY}%-38s${RESET}" "Starting VPN tunnel..."
            # Short-circuit when wg0 is already up — wg-quick up returns
            # non-zero on "already exists", which previously produced a
            # false-alarm warning on every mode switch.
            if ip link show wg0 &>/dev/null; then
                printf "${GREEN}✓  WireGuard tunnel up${RESET}\n"
            elif wg-quick up wg0 >/dev/null 2>/dev/null; then
                printf "${GREEN}✓  WireGuard tunnel up${RESET}\n"
            else
                printf "${AMBER}!  Check wg0.conf — see configs/ folder${RESET}\n"
            fi

            printf "  ${GREY}%-38s${RESET}" "Starting DNS filter..."
            systemctl start pihole-FTL >/dev/null 2>/dev/null && printf "${GREEN}✓  Pi-hole blocking ads and trackers${RESET}\n" || printf "${RED}✗  Failed${RESET}\n"

            printf "  ${GREY}%-38s${RESET}" "Starting threat detection..."
            systemctl start suricata fail2ban >/dev/null 2>/dev/null && printf "${GREEN}✓  Suricata + Fail2ban watching for threats${RESET}\n" || printf "${RED}✗  Failed${RESET}\n"

            printf "  ${GREY}%-38s${RESET}" "Starting honeypot decoy..."
            systemctl start cowrie >/dev/null 2>/dev/null && printf "${GREEN}✓  Cowrie decoy active on port 2222${RESET}\n" || printf "${RED}✗  Failed${RESET}\n"

            echo ""
            divider
            echo ""
            echo "1:Traveler Mode:WireGuard + Pi-hole + Suricata + Fail2ban" > /tmp/safehaven-mode
            echo -e "  ${GREEN}${BOLD}✓  Traveler Mode is active. You are protected.${RESET}"
            echo ""
            echo -e "  ${GREY}Connect your devices to the SafeHaven Pi WiFi network.${RESET}"
            echo -e "  ${GREY}All traffic is now encrypted and filtered.${RESET}"
            ;;
        2)
            echo -e "  ${AMBER}${BOLD}ACTIVIST MODE  —  Maximum Privacy${RESET}"
            echo -e "  ${GREY}Tor routing + zero-log DNS. No trace left behind.${RESET}"
            echo ""
            divider
            echo ""
            echo -e "  Choose your privacy configuration:"
            echo ""
            echo -e "  ${AMBER}[A]${RESET}  ${BOLD}Tor Only${RESET}"
            echo -e "       ${GREY}Maximum anonymity — WireGuard off, all traffic through Tor${RESET}"
            echo ""
            echo -e "  ${AMBER}[B]${RESET}  ${BOLD}Tor over WireGuard${RESET}  ${AMBER}(Recommended)${RESET}"
            echo -e "       ${GREY}Double layer — traffic encrypted by WireGuard then anonymised by Tor${RESET}"
            echo ""
            read -rp "  $(echo -e "${AMBER}${BOLD}Choice [A/B, default B]${RESET}") ❯ " tor_choice
            tor_choice=${tor_choice:-B}
            echo ""
            divider
            echo ""

            printf "  ${GREY}%-42s${RESET}" "Starting WiFi hotspot..."
            systemctl start hostapd >/dev/null 2>/dev/null && printf "${GREEN}✓  Broadcasting${RESET}\n" || printf "${RED}✗  Failed${RESET}\n"

            printf "  ${GREY}%-42s${RESET}" "Starting DHCP server..."
            systemctl start dnsmasq >/dev/null 2>/dev/null && printf "${GREEN}✓  Active${RESET}\n" || printf "${RED}✗  Failed${RESET}\n"

            case "${tor_choice^^}" in
                A)
                    printf "  ${GREY}%-42s${RESET}" "Disabling WireGuard (Tor-only mode)..."
                    wg-quick down wg0 >/dev/null 2>/dev/null
                    printf "${AMBER}✓  WireGuard off${RESET}\n"
                    ;;
                *)
                    printf "  ${GREY}%-42s${RESET}" "Starting WireGuard tunnel..."
                    # Same short-circuit as Mode 1 — avoid false-alarm
                    # when wg0 is already up from a previous mode.
                    if ip link show wg0 &>/dev/null; then
                        printf "${GREEN}✓  Tunnel up${RESET}\n"
                    elif wg-quick up wg0 >/dev/null 2>/dev/null; then
                        printf "${GREEN}✓  Tunnel up${RESET}\n"
                    else
                        printf "${AMBER}!  Check wg0.conf${RESET}\n"
                    fi
                    ;;
            esac

            printf "  ${GREY}%-42s${RESET}" "Loading Tor firewall rules..."
            nft flush table inet safehaven 2>/dev/null
            nft -f ${REPO_DIR}/configs/nftables-mode2.conf >/dev/null 2>/dev/null && printf "${GREEN}✓  Tor routing rules active${RESET}\n" || printf "${RED}✗  Failed to load rules${RESET}\n"

            cp "${REPO_DIR}/configs/torrc" /etc/tor/torrc 2>/dev/null
            printf "  ${GREY}%-42s${RESET}" "Starting Tor..."
            systemctl start tor@default >/dev/null 2>/dev/null && printf "${GREEN}✓  Tor active${RESET}\n" || printf "${RED}✗  Failed${RESET}\n"

            printf "  ${GREY}%-42s${RESET}" "Starting DNS filter..."
            systemctl start pihole-FTL >/dev/null 2>/dev/null && printf "${GREEN}✓  Pi-hole active${RESET}\n" || printf "${RED}✗  Failed${RESET}\n"

            printf "  ${GREY}%-42s${RESET}" "Disabling DNS logging..."
            pihole logging off >/dev/null 2>/dev/null && printf "${GREEN}✓  Zero-log mode on${RESET}\n" || printf "${AMBER}!  Could not disable logging${RESET}\n"

            printf "  ${GREY}%-42s${RESET}" "Clearing existing logs..."
            truncate -s 0 /var/log/pihole/pihole.log 2>/dev/null
            truncate -s 0 /var/log/suricata/fast.log 2>/dev/null
            printf "${GREEN}✓  Logs cleared${RESET}\n"

            printf "  ${GREY}%-42s${RESET}" "Starting threat detection..."
            systemctl start suricata fail2ban >/dev/null 2>/dev/null && printf "${GREEN}✓  Suricata + Fail2ban active${RESET}\n" || printf "${RED}✗  Failed${RESET}\n"

            echo ""
            divider
            echo ""
            echo -e "  ${AMBER}${BOLD}✓  Activist Mode is active.${RESET}"
            if [[ "${tor_choice^^}" == "A" ]]; then
                echo "2:Activist Mode:Tor only — WireGuard off, zero logs" > /tmp/safehaven-mode
                echo -e "  ${GREY}Configuration: Tor only — maximum anonymity${RESET}"
            else
                echo "2:Activist Mode:Tor over WireGuard — double layer, zero logs" > /tmp/safehaven-mode
                echo -e "  ${GREY}Configuration: Tor over WireGuard — double layer protection${RESET}"
            fi
            echo ""
            echo -e "  ${GREY}All hotspot traffic is routed through Tor.${RESET}"
            echo -e "  ${GREY}DNS queries are anonymised. No logs are kept.${RESET}"
            echo ""
            echo -e "  ${AMBER}To deactivate:${RESET} ${GREY}select Traveler Mode or Stop All Services${RESET}"
            ;;
        3)
            echo -e "  ${GREEN}${BOLD}Switching on Business Mode${RESET}"
            echo -e "  ${GREY}Secure temporary network with per-user authentication and admin panel.${RESET}"
            echo ""
            divider
            echo ""

            printf "  ${GREY}%-42s${RESET}" "Starting WiFi hotspot..."
            systemctl start hostapd >/dev/null 2>/dev/null && printf "${GREEN}✓  Hotspot broadcasting${RESET}\n" || printf "${RED}✗  Failed${RESET}\n"

            printf "  ${GREY}%-42s${RESET}" "Starting DHCP server..."
            systemctl start dnsmasq >/dev/null 2>/dev/null && printf "${GREEN}✓  DHCP active${RESET}\n" || printf "${RED}✗  Failed${RESET}\n"

            printf "  ${GREY}%-42s${RESET}" "Starting firewall..."
            # restart (not start) so /etc/nftables.conf is reloaded if the
            # ruleset was modified by a previous mode activation
            systemctl restart nftables >/dev/null 2>/dev/null && printf "${GREEN}✓  Firewall active${RESET}\n" || printf "${RED}✗  Failed${RESET}\n"

            printf "  ${GREY}%-42s${RESET}" "Starting DNS filter..."
            systemctl start pihole-FTL >/dev/null 2>/dev/null && printf "${GREEN}✓  Pi-hole active${RESET}\n" || printf "${RED}✗  Failed${RESET}\n"

            printf "  ${GREY}%-42s${RESET}" "Starting threat detection..."
            systemctl start suricata fail2ban >/dev/null 2>/dev/null && printf "${GREEN}✓  Suricata + Fail2ban active${RESET}\n" || printf "${RED}✗  Failed${RESET}\n"

            printf "  ${GREY}%-42s${RESET}" "Activating captive portal..."
            printf "${GREEN}✓  Portal live at /portal${RESET}\n"

            printf "  ${GREY}%-42s${RESET}" "Gating admin dashboard..."
            printf "${GREEN}✓  Login required in Business Mode${RESET}\n"

            echo ""
            divider
            echo ""
            echo "3:Business Mode:Captive portal + per-user authentication active" > /tmp/safehaven-mode
            echo -e "  ${GREEN}${BOLD}✓  Business Mode is active.${RESET}"
            echo ""
            echo -e "  ${GREY}End-user captive portal:${RESET} ${WHITE}https://10.42.0.1:5000/portal${RESET}"
            echo -e "  ${GREY}Admin user management:  ${RESET} ${WHITE}https://10.42.0.1:5000/admin/users${RESET}"
            echo ""
            echo -e "  ${GREY}Create users via the admin panel. Connected users appear live.${RESET}"
            echo ""
            echo -e "  ${AMBER}To deactivate:${RESET} ${GREY}select Traveler Mode or Stop All Services${RESET}"
            ;;
        4)
            echo -e "  ${CYAN}${BOLD}Switching on Relaxed Mode${RESET}"
            echo -e "  ${GREY}Full security stack — no VPN. Use when sites block VPN traffic.${RESET}"
            echo ""
            divider
            echo ""
            # ── Stop Tor if Mode 2 was active ─────────────────
            if systemctl is-active --quiet tor@default 2>/dev/null; then
                printf "  ${GREY}%-38s${RESET}" "Stopping Tor..."
                systemctl stop tor@default >/dev/null 2>/dev/null && printf "${GREEN}✓  Tor stopped${RESET}
" || printf "${AMBER}!  Could not stop Tor${RESET}
"
            fi
            # ── Bring WireGuard down ───────────────────────────
            printf "  ${GREY}%-38s${RESET}" "Disabling VPN tunnel..."
            wg-quick down wg0 >/dev/null 2>/dev/null
            printf "${CYAN}✓  WireGuard off — no VPN detection${RESET}
"
            # ── Restore standard nftables rules ───────────────
            printf "  ${GREY}%-38s${RESET}" "Restoring firewall rules..."
            systemctl restart nftables >/dev/null 2>/dev/null && printf "${GREEN}✓  Firewall active${RESET}
" || printf "${RED}✗  Failed${RESET}
"
            printf "  ${GREY}%-38s${RESET}" "Starting WiFi hotspot..."
            systemctl start hostapd >/dev/null 2>/dev/null && printf "${GREEN}✓  Hotspot broadcasting${RESET}
" || printf "${RED}✗  Failed${RESET}
"
            printf "  ${GREY}%-38s${RESET}" "Starting DHCP server..."
            systemctl start dnsmasq >/dev/null 2>/dev/null && printf "${GREEN}✓  Active${RESET}
" || printf "${RED}✗  Failed${RESET}
"
            printf "  ${GREY}%-38s${RESET}" "Starting DNS filter..."
            systemctl start pihole-FTL >/dev/null 2>/dev/null && printf "${GREEN}✓  Pi-hole blocking ads and trackers${RESET}
" || printf "${RED}✗  Failed${RESET}
"
            printf "  ${GREY}%-38s${RESET}" "Starting threat detection..."
            systemctl start suricata fail2ban >/dev/null 2>/dev/null && printf "${GREEN}✓  Suricata + Fail2ban active${RESET}
" || printf "${RED}✗  Failed${RESET}
"
            printf "  ${GREY}%-38s${RESET}" "Starting honeypot decoy..."
            systemctl start cowrie >/dev/null 2>/dev/null && printf "${GREEN}✓  Cowrie active on port 2222${RESET}
" || printf "${RED}✗  Failed${RESET}
"
            echo ""
            divider
            echo ""
            echo "4:Relaxed Mode:WireGuard OFF — Pi-hole + firewall + Suricata active" > /tmp/safehaven-mode
            echo -e "  ${CYAN}${BOLD}✓  Relaxed Mode is active.${RESET}"
            echo ""
            echo -e "  ${GREY}Pi-hole, firewall, Suricata and Fail2ban are all running.${RESET}"
            echo -e "  ${GREY}WireGuard is off — sites cannot detect a VPN.${RESET}"
            echo ""
            echo -e "  ${CYAN}To switch back:${RESET} ${GREY}select Traveler Mode to re-enable VPN${RESET}"
            ;;
    esac

    echo ""
    divider
    read -rp "  Press Enter to return to the menu..." _
}

# ── Live Logs ─────────────────────────────────────────────────
show_logs() {
    trap '' INT
    while true; do
        print_header
        echo -e "  ${BOLD}${WHITE}LIVE SECURITY LOGS${RESET}"
        echo -e "  ${GREY}Watch what SafeHaven Pi is detecting in real time.${RESET}"
        echo -e "  ${GREY}Press Ctrl+C to stop watching and return to this menu.${RESET}"
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
            1) echo -e "
  ${AMBER}Watching for threats — Ctrl+C to return to log menu${RESET}
"
               ( trap - INT; tail -f /var/log/suricata/fast.log 2>/dev/null ) || true ;;
            2) echo -e "
  ${RED}Watching banned IPs — Ctrl+C to return to log menu${RESET}
"
               ( trap - INT; tail -f /var/log/fail2ban.log 2>/dev/null ) || true ;;
            3) echo -e "
  ${PURPLE}Watching honeypot — Ctrl+C to return to log menu${RESET}
"
               ( trap - INT; tail -f /home/cowrie/cowrie/var/log/cowrie/cowrie.json 2>/dev/null ) || true ;;
            4) echo -e "
  ${CYAN}Watching DNS queries — Ctrl+C to return to log menu${RESET}
"
               ( trap - INT; tail -f /var/log/pihole/pihole.log 2>/dev/null ) || true ;;
            5) echo -e "
  ${GREEN}Watching VPN connections — Ctrl+C to return to log menu${RESET}
"
               ( trap - INT; watch -n 2 wg show 2>/dev/null ) || true ;;
            6) echo -e "
  ${WHITE}Full system journal — Ctrl+C to return to log menu${RESET}
"
               ( trap - INT; journalctl -f ) || true ;;
            b|B) trap - INT; return ;;
            *) echo "  Not a valid choice." ; sleep 0.8 ;;
        esac
        echo ""
        echo -e "  ${GREY}Stopped. Returning to log menu...${RESET}"
        sleep 1
    done
    trap - INT
}

# ── WireGuard helpers (Add Device flow) ───────────────────────
# These power the per-device QR feature. The design principle:
# the server's private key never leaves the Pi, and each new
# device gets its own freshly-generated keypair. The client's
# private key only exists in shell variables long enough to be
# QR-encoded — the Pi keeps no copy.

# Read the WireGuard subnet prefix from /etc/wireguard/wg0.conf.
# e.g. for "Address = 10.8.0.1/24" returns "10.8.0".
# Returns empty string and exit code 1 on failure.
_wg_get_subnet() {
    local addr
    addr=$(sudo grep -E '^\s*Address\s*=' /etc/wireguard/wg0.conf 2>/dev/null \
        | head -1 \
        | awk -F'=' '{print $2}' \
        | tr -d ' ' \
        | cut -d'/' -f1)
    if [ -z "$addr" ]; then
        return 1
    fi
    echo "$addr" | awk -F'.' '{printf "%s.%s.%s", $1, $2, $3}'
}

# Read the WireGuard ListenPort from /etc/wireguard/wg0.conf.
# Falls back to 51820 (the WireGuard default) if not found.
_wg_get_listen_port() {
    local port
    port=$(sudo grep -E '^\s*ListenPort\s*=' /etc/wireguard/wg0.conf 2>/dev/null \
        | head -1 \
        | awk -F'=' '{print $2}' \
        | tr -d ' ')
    [ -z "$port" ] && port="51820"
    echo "$port"
}

# Return the IP address clients should use as the WireGuard
# Endpoint. This is the SafeHaven hotspot gateway (wlan1's IP),
# since clients reach the Pi over the hotspot. Falls back to
# 10.42.0.1 (the default hotspot subnet) if wlan1 isn't up.
_wg_get_endpoint_host() {
    local ip
    ip=$(ip -4 addr show wlan1 2>/dev/null \
        | grep -oP 'inet \K[\d.]+' \
        | head -1)
    [ -z "$ip" ] && ip="10.42.0.1"
    echo "$ip"
}

# Find the next unused host IP in the WireGuard subnet, starting
# from .2 (server is .1). Scans live `wg show allowed-ips` so
# IPs allocated to existing peers aren't re-used.
# Returns empty and exit code 1 if the subnet is full.
_wg_next_free_ip() {
    local subnet
    subnet=$(_wg_get_subnet) || return 1

    local used_ips
    used_ips=$(sudo wg show wg0 allowed-ips 2>/dev/null \
        | awk '{for (i=2;i<=NF;i++) print $i}' \
        | cut -d'/' -f1 \
        | grep -E "^${subnet//./\\.}\\." \
        | sort -u)

    local i candidate
    for i in $(seq 2 254); do
        candidate="${subnet}.${i}"
        if ! echo "$used_ips" | grep -qx "$candidate"; then
            echo "$candidate"
            return 0
        fi
    done
    return 1
}

# Add a peer to the running wg0 interface and persist the change
# to /etc/wireguard/wg0.conf via wg-quick save.
# Args: <pubkey> <ip>  (ip is just the host address, no CIDR)
# Returns 0 on success, 1 on failure (and rolls back the live add
# if save fails so the file and the running state stay consistent).
_wg_add_peer() {
    local pubkey="$1"
    local ip="$2"

    if ! sudo wg set wg0 peer "$pubkey" \
        allowed-ips "${ip}/32" \
        persistent-keepalive 25 2>/dev/null; then
        return 1
    fi

    if ! sudo wg-quick save wg0 >/dev/null 2>&1; then
        sudo wg set wg0 peer "$pubkey" remove 2>/dev/null
        return 1
    fi

    return 0
}

# Append a device entry to /etc/safehaven/wg-devices.json.
# Stores name, public key, IP, and timestamp — never the private
# key. Creates the file as an empty array if missing or invalid.
# Args: <name> <pubkey> <ip>
# Returns 0 on success, 1 on failure (caller treats as non-fatal).
_wg_track_device() {
    local name="$1"
    local pubkey="$2"
    local ip="$3"
    local devices_file="/etc/safehaven/wg-devices.json"

    sudo mkdir -p /etc/safehaven 2>/dev/null
    if [ ! -f "$devices_file" ]; then
        echo "[]" | sudo tee "$devices_file" >/dev/null
    fi
    sudo chmod 644 "$devices_file"

    sudo python3 - "$devices_file" "$name" "$pubkey" "$ip" <<'PYEOF' 2>/dev/null
import json, sys, datetime
path, name, pubkey, ip = sys.argv[1:5]
try:
    with open(path) as f:
        devices = json.load(f)
    if not isinstance(devices, list):
        devices = []
except (json.JSONDecodeError, FileNotFoundError):
    devices = []
devices.append({
    "name": name,
    "public_key": pubkey,
    "ip": ip,
    "added_at": datetime.datetime.now().isoformat(timespec='seconds'),
})
with open(path, 'w') as f:
    json.dump(devices, f, indent=2)
PYEOF
    return $?
}

# Remove a peer from the running wg0 interface and persist the
# change to /etc/wireguard/wg0.conf via wg-quick save.
# Symmetric counterpart to _wg_add_peer.
# Args: <pubkey>
# Returns 0 on success, 1 on failure.
_wg_remove_peer() {
    local pubkey="$1"

    if ! sudo wg set wg0 peer "$pubkey" remove 2>/dev/null; then
        return 1
    fi

    if ! sudo wg-quick save wg0 >/dev/null 2>&1; then
        return 1
    fi

    return 0
}

# Remove a device entry from /etc/safehaven/wg-devices.json by
# matching public key. Symmetric counterpart to _wg_track_device.
# Args: <pubkey>
# Returns 0 on success, 1 on failure (caller treats as non-fatal).
_wg_untrack_device() {
    local pubkey="$1"
    local devices_file="/etc/safehaven/wg-devices.json"

    if [ ! -f "$devices_file" ]; then
        return 0   # nothing to untrack
    fi

    sudo python3 - "$devices_file" "$pubkey" <<'PYEOF' 2>/dev/null
import json, sys
path, pubkey = sys.argv[1:3]
try:
    with open(path) as f:
        devices = json.load(f)
    if not isinstance(devices, list):
        devices = []
except (json.JSONDecodeError, FileNotFoundError):
    devices = []
devices = [d for d in devices if d.get('public_key') != pubkey]
with open(path, 'w') as f:
    json.dump(devices, f, indent=2)
PYEOF
    return $?
}

# Rename a device entry in /etc/safehaven/wg-devices.json by
# matching public key. Updates only the metadata file —
# WireGuard's own config has no concept of device names, so
# nothing in /etc/wireguard/wg0.conf changes.
# Args: <pubkey> <new_name>
# Returns 0 on success, 1 on failure (e.g. pubkey not found).
_wg_rename_device() {
    local pubkey="$1"
    local new_name="$2"
    local devices_file="/etc/safehaven/wg-devices.json"

    if [ ! -f "$devices_file" ]; then
        return 1
    fi

    sudo python3 - "$devices_file" "$pubkey" "$new_name" <<'PYEOF' 2>/dev/null
import json, sys
path, pubkey, new_name = sys.argv[1:4]
try:
    with open(path) as f:
        devices = json.load(f)
    if not isinstance(devices, list):
        sys.exit(1)
except Exception:
    sys.exit(1)
found = False
for d in devices:
    if d.get('public_key') == pubkey:
        d['name'] = new_name
        found = True
        break
if not found:
    sys.exit(1)
with open(path, 'w') as f:
    json.dump(devices, f, indent=2)
PYEOF
    return $?
}

# ── WireGuard QR — Add a Device ───────────────────────────────
# Generates a fresh keypair for the new device, allocates an IP,
# adds the peer to wg0, builds a client config in memory, and
# QR-encodes it for the user to scan.
#
# SECURITY: the client's private key is never written to disk.
# It exists only in shell variables during this function, and is
# unset on exit. If the user misses the scan, the only recovery
# is to remove the peer and re-run this function — exactly the
# one-time-use property we want.
show_wg_qr() {
    print_header
    echo -e "  ${BOLD}${WHITE}ADD A DEVICE TO THE VPN${RESET}"
    echo -e "  ${GREY}Generates a one-time QR with a fresh keypair for the new device.${RESET}"
    echo -e "  ${GREY}The Pi keeps no copy of the device's private key — scan it now or${RESET}"
    echo -e "  ${GREY}you'll need to remove the device and add it again.${RESET}"
    echo ""
    divider

    # ── Pre-flight checks ─────────────────────────────────────
    if ! command -v wg &>/dev/null; then
        echo ""
        echo -e "  ${RED}WireGuard tools not installed.${RESET}"
        echo -e "  ${GREY}Install with: sudo apt install wireguard-tools${RESET}"
        echo ""
        read -rp "  Press Enter to return to the menu..." _
        return 1
    fi

    if ! command -v qrencode &>/dev/null; then
        echo ""
        echo -e "  ${RED}qrencode not installed.${RESET}"
        echo -e "  ${GREY}Install with: sudo apt install qrencode${RESET}"
        echo ""
        read -rp "  Press Enter to return to the menu..." _
        return 1
    fi

    if [ ! -f /etc/wireguard/wg0.conf ]; then
        echo ""
        echo -e "  ${RED}WireGuard config not found at /etc/wireguard/wg0.conf${RESET}"
        echo -e "  ${GREY}Run the Setup Wizard (press [w]) to generate it first.${RESET}"
        echo ""
        read -rp "  Press Enter to return to the menu..." _
        return 1
    fi

    if [ ! -f /etc/wireguard/publickey ]; then
        echo ""
        echo -e "  ${RED}Server public key not found at /etc/wireguard/publickey${RESET}"
        echo -e "  ${GREY}Run the Setup Wizard (press [w]) to generate keys.${RESET}"
        echo ""
        read -rp "  Press Enter to return to the menu..." _
        return 1
    fi

    if ! sudo wg show wg0 &>/dev/null; then
        echo ""
        echo -e "  ${RED}WireGuard interface wg0 is not running.${RESET}"
        echo -e "  ${GREY}Activate a mode (1, 2, 3, or 4) to bring it up.${RESET}"
        echo ""
        read -rp "  Press Enter to return to the menu..." _
        return 1
    fi

    # ── Get device name ───────────────────────────────────────
    echo ""
    echo -e "  ${WHITE}Name this device${RESET} ${GREY}(e.g. \"Phone\", \"Lab laptop\")${RESET}"
    echo -e "  ${GREY}Letters, numbers, spaces, periods, hyphens, underscores. 1-32 chars.${RESET}"
    echo ""
    local device_name
    read -rp "  Device name: " device_name

    # Sanitise: keep only safe chars, trim whitespace, cap length
    device_name=$(echo "$device_name" | tr -cd 'A-Za-z0-9 _.\-' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [ -z "$device_name" ]; then
        echo ""
        echo -e "  ${AMBER}Cancelled — empty name.${RESET}"
        echo ""
        read -rp "  Press Enter to return to the menu..." _
        return 0
    fi
    if [ ${#device_name} -gt 32 ]; then
        device_name="${device_name:0:32}"
    fi

    echo ""

    # ── Build the device ──────────────────────────────────────

    printf "  ${GREY}%-38s${RESET}" "Generating one-time keypair..."
    local client_priv
    client_priv=$(wg genkey 2>/dev/null)
    if [ -z "$client_priv" ]; then
        printf "${RED}✗  Failed${RESET}\n"
        echo ""
        read -rp "  Press Enter to return to the menu..." _
        return 1
    fi
    local client_pub
    client_pub=$(echo "$client_priv" | wg pubkey 2>/dev/null)
    if [ -z "$client_pub" ]; then
        printf "${RED}✗  Failed${RESET}\n"
        unset client_priv
        echo ""
        read -rp "  Press Enter to return to the menu..." _
        return 1
    fi
    printf "${GREEN}✓${RESET}\n"

    printf "  ${GREY}%-38s${RESET}" "Allocating IP from VPN subnet..."
    local next_ip
    next_ip=$(_wg_next_free_ip)
    if [ -z "$next_ip" ]; then
        printf "${RED}✗  Subnet full${RESET}\n"
        echo -e "  ${GREY}Remove an existing device first.${RESET}"
        echo ""
        unset client_priv
        read -rp "  Press Enter to return to the menu..." _
        return 1
    fi
    printf "${GREEN}✓  ${WHITE}%s${RESET}\n" "$next_ip"

    printf "  ${GREY}%-38s${RESET}" "Adding peer to WireGuard..."
    if ! _wg_add_peer "$client_pub" "$next_ip"; then
        printf "${RED}✗  Failed${RESET}\n"
        echo -e "  ${GREY}Check 'sudo wg show wg0' for state.${RESET}"
        echo ""
        unset client_priv
        read -rp "  Press Enter to return to the menu..." _
        return 1
    fi
    printf "${GREEN}✓${RESET}\n"

    printf "  ${GREY}%-38s${RESET}" "Recording device metadata..."
    if _wg_track_device "$device_name" "$client_pub" "$next_ip"; then
        printf "${GREEN}✓${RESET}\n"
    else
        printf "${AMBER}!  Could not write devices file${RESET}\n"
        # Non-fatal — peer is still added to wg0
    fi

    # ── Build client config ──────────────────────────────────

    local server_pub
    server_pub=$(sudo cat /etc/wireguard/publickey 2>/dev/null | tr -d '\r\n ')
    local server_subnet
    server_subnet=$(_wg_get_subnet)
    local server_listen_port
    server_listen_port=$(_wg_get_listen_port)
    local endpoint_host
    endpoint_host=$(_wg_get_endpoint_host)

    local client_config
    client_config="[Interface]
PrivateKey = ${client_priv}
Address = ${next_ip}/24
DNS = ${server_subnet}.1

[Peer]
PublicKey = ${server_pub}
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = ${endpoint_host}:${server_listen_port}
PersistentKeepalive = 25"

    # ── Display the QR ────────────────────────────────────────

    echo ""
    sleep 1   # Brief pause so the user sees success messages
    clear
    print_header
    echo -e "  ${BOLD}${WHITE}SCAN WITH THE WIREGUARD APP${RESET}"
    echo -e "  ${CYAN}${BOLD}  → ${device_name}${RESET}"
    echo ""
    divider
    echo ""
    echo "$client_config" | qrencode -t ansiutf8
    echo ""
    divider
    echo -e "  ${GREY}Device:     ${WHITE}${device_name}${RESET}"
    echo -e "  ${GREY}IP:         ${WHITE}${next_ip}/24${RESET}"
    echo -e "  ${GREY}Public key: ${WHITE}${client_pub}${RESET}"
    echo -e "  ${GREY}Endpoint:   ${WHITE}${endpoint_host}:${server_listen_port}${RESET}"
    divider
    echo ""
    echo -e "  ${AMBER}⚠  This QR contains a one-time private key.${RESET}"
    echo -e "  ${AMBER}   The Pi keeps NO copy. If the scan fails or you close${RESET}"
    echo -e "  ${AMBER}   this screen, you'll need to remove this device and${RESET}"
    echo -e "  ${AMBER}   add it again to get a fresh QR.${RESET}"
    echo ""
    read -rp "  Press Enter once you've scanned to clear the screen..." _

    # ── Cleanup ──────────────────────────────────────────────

    unset client_priv
    unset client_config
    clear

    print_header
    echo -e "  ${BOLD}${WHITE}DEVICE ADDED${RESET}"
    echo ""
    divider
    echo -e "  ${GREEN}✓${RESET}  ${WHITE}${device_name}${RESET} added at ${WHITE}${next_ip}${RESET}"
    echo -e "  ${GREEN}✓${RESET}  Private key cleared from memory"
    echo -e "  ${GREEN}✓${RESET}  Server config saved"
    divider
    echo ""
    read -rp "  Press Enter to return to the menu..." _
}

# ── WireGuard — List Devices ──────────────────────────────────
# Reads /etc/safehaven/wg-devices.json and joins it with live
# state from `wg show wg0 dump` so the user sees both metadata
# (name, when added) and live status (handshake age, transfer).
# Also flags any peers in wg0 that aren't in our metadata file
# (they exist from before tracking was introduced, or were added
# manually with `wg set`).
list_wg_devices() {
    print_header
    echo -e "  ${BOLD}${WHITE}VPN DEVICES${RESET}"
    echo -e "  ${GREY}All peers configured on this Pi, with live status from WireGuard.${RESET}"
    echo ""
    divider

    local devices_file="/etc/safehaven/wg-devices.json"
    local has_tracked=0
    if [ -f "$devices_file" ] \
       && [ "$(sudo cat "$devices_file" 2>/dev/null)" != "[]" ] \
       && [ -n "$(sudo cat "$devices_file" 2>/dev/null)" ]; then
        has_tracked=1
    fi

    # Pass terminal layout to python (wide table vs mobile cards).
    local layout="wide"
    is_mobile && layout="mobile"

    echo ""
    sudo python3 - "$devices_file" "$has_tracked" "$layout" <<'PYEOF' 2>/dev/null
import json, sys, subprocess, datetime, os

path        = sys.argv[1]
has_tracked = sys.argv[2] == "1"
layout      = sys.argv[3] if len(sys.argv) > 3 else "wide"

# Colours (must match the bash palette so output blends in)
RESET = '\033[0m'
BOLD  = '\033[1m'
WHITE = '\033[38;5;255m'
GREY  = '\033[38;5;244m'
GREEN = '\033[38;5;82m'
AMBER = '\033[38;5;214m'
CYAN  = '\033[38;5;117m'

# ── Read tracked devices ────────────────────────────────────
devices = []
if has_tracked and os.path.exists(path):
    try:
        with open(path) as f:
            devices = json.load(f)
        if not isinstance(devices, list):
            devices = []
    except Exception:
        devices = []

# ── Read live state from `wg show wg0 dump` ─────────────────
# dump format (tab-separated):
#   line 1: priv  pub  listen_port  fwmark            (interface)
#   line N: pub  preshared  endpoint  allowed_ips
#           latest_handshake  rx  tx  keepalive       (peer)
live = {}
try:
    result = subprocess.run(
        ['sudo', 'wg', 'show', 'wg0', 'dump'],
        capture_output=True, text=True, timeout=3,
    )
    lines = result.stdout.strip().split('\n')[1:]   # skip interface line
    for line in lines:
        if not line.strip():
            continue
        f = line.split('\t')
        if len(f) >= 5:
            live[f[0]] = {
                'endpoint':    f[2] if len(f) > 2 else '',
                'allowed_ips': f[3] if len(f) > 3 else '',
                'handshake':   int(f[4]) if f[4].isdigit() else 0,
                'rx':          int(f[5]) if len(f) > 5 and f[5].isdigit() else 0,
                'tx':          int(f[6]) if len(f) > 6 and f[6].isdigit() else 0,
            }
except Exception:
    pass

def fmt_size(n):
    if n < 1024:                return f"{n} B"
    if n < 1024 * 1024:         return f"{n/1024:.1f} KiB"
    if n < 1024 * 1024 * 1024:  return f"{n/1024/1024:.1f} MiB"
    return f"{n/1024/1024/1024:.2f} GiB"

def fmt_handshake(ts):
    if ts == 0:
        return f"{GREY}never{RESET}"
    age = datetime.datetime.now().timestamp() - ts
    if age < 60:    return f"{GREEN}{int(age)}s ago{RESET}"
    if age < 3600:  return f"{GREEN}{int(age/60)}m ago{RESET}"
    if age < 86400: return f"{AMBER}{int(age/3600)}h ago{RESET}"
    return f"{GREY}{int(age/86400)}d ago{RESET}"

def fmt_endpoint(ep):
    """Endpoint as 'IP:port' or em-dash when never connected."""
    if not ep or ep == '(none)':
        return f"{GREY}—{RESET}"
    return f"{WHITE}{ep}{RESET}"

# ── Wide table layout (terminals ≥ 80 cols) ─────────────────
def print_wide():
    if not devices:
        print(f"  {GREY}No tracked devices yet.{RESET}")
        print(f"  {GREY}Use [a] in this menu to add one.{RESET}")
        return

    print(f"  {BOLD}{WHITE}#{RESET}    {BOLD}{WHITE}Name{RESET}                "
          f"{BOLD}{WHITE}IP{RESET}            "
          f"{BOLD}{WHITE}Last Handshake{RESET}    "
          f"{BOLD}{WHITE}Transfer (rx / tx){RESET}")
    print(f"  {GREY}" + "─" * 88 + RESET)
    for i, dev in enumerate(devices, 1):
        name = (dev.get('name') or '?')[:18]
        ip   = dev.get('ip', '?')
        pub  = dev.get('public_key', '')
        info = live.get(pub, {})
        hs   = fmt_handshake(info.get('handshake', 0))
        rx   = fmt_size(info.get('rx', 0))
        tx   = fmt_size(info.get('tx', 0))
        ep   = info.get('endpoint', '')
        # Manual padding so colour codes don't break alignment
        name_pad = name + " " * (18 - len(name))
        print(f"  {CYAN}{i:>2}.{RESET}  {WHITE}{name_pad}{RESET}  "
              f"{ip:<14}{hs:<25}  {rx} / {tx}")
        # Sub-line: where this device connected from (only when active)
        if ep and ep != '(none)':
            print(f"      {GREY}└ from {ep}{RESET}")

# ── Mobile vertical card layout (Termux on phone, etc.) ─────
def print_mobile():
    if not devices:
        print(f"  {GREY}No tracked devices yet.{RESET}")
        print(f"  {GREY}Use [a] in this menu to add one.{RESET}")
        return

    for i, dev in enumerate(devices, 1):
        name  = dev.get('name', '?')
        ip    = dev.get('ip', '?')
        pub   = dev.get('public_key', '')
        info  = live.get(pub, {})
        added = dev.get('added_at', '?')
        print(f"  {GREY}" + "─" * 38 + RESET)
        print(f"  {CYAN}{i}.{RESET}  {BOLD}{WHITE}{name}{RESET}")
        print(f"      {GREY}IP        {RESET}{ip}")
        print(f"      {GREY}Endpoint  {RESET}{fmt_endpoint(info.get('endpoint'))}")
        print(f"      {GREY}Handshake {RESET}{fmt_handshake(info.get('handshake', 0))}")
        print(f"      {GREY}Transfer  {RESET}{fmt_size(info.get('rx', 0))} / "
              f"{fmt_size(info.get('tx', 0))}")
        print(f"      {GREY}Added     {RESET}{added}")
    print(f"  {GREY}" + "─" * 38 + RESET)

# ── Dispatch to the right layout ────────────────────────────
if layout == "mobile":
    print_mobile()
else:
    print_wide()

# ── Flag untracked peers (works for both layouts) ───────────
tracked_keys = {d.get('public_key') for d in devices}
untracked = [pub for pub in live if pub not in tracked_keys]
if untracked:
    print()
    print(f"  {AMBER}⚠  {len(untracked)} peer(s) on wg0 are not in our metadata:{RESET}")
    for pub in untracked:
        info = live[pub]
        ip = info.get('allowed_ips', '?').split('/')[0]
        ep = info.get('endpoint', '') or ''
        if ep and ep != '(none)':
            print(f"     {GREY}{pub[:16]}…   {ip}   from {ep}{RESET}")
        else:
            print(f"     {GREY}{pub[:16]}…   {ip}{RESET}")
    print(f"     {GREY}These existed before tracking was added (or were added{RESET}")
    print(f"     {GREY}manually). They still work, but can't be managed by name.{RESET}")
PYEOF

    echo ""
    divider
    echo ""
    read -rp "  Press Enter to return to the manage menu..." _
}

# ── WireGuard — Remove a Device ───────────────────────────────
# Lists tracked devices, lets the user pick by number, asks for
# confirmation, then atomically removes the peer from wg0
# (running + on-disk) and from /etc/safehaven/wg-devices.json.
remove_wg_device() {
    print_header
    echo -e "  ${BOLD}${WHITE}REMOVE A VPN DEVICE${RESET}"
    echo -e "  ${GREY}Revokes a peer's access. The device's WireGuard config still exists${RESET}"
    echo -e "  ${GREY}on the user's phone, but it won't be able to connect anymore.${RESET}"
    echo ""
    divider

    local devices_file="/etc/safehaven/wg-devices.json"

    # ── Pre-flight: any tracked devices? ──────────────────────
    if [ ! -f "$devices_file" ] \
       || [ "$(sudo cat "$devices_file" 2>/dev/null)" = "[]" ] \
       || [ -z "$(sudo cat "$devices_file" 2>/dev/null)" ]; then
        echo ""
        echo -e "  ${GREY}No tracked devices to remove.${RESET}"
        echo -e "  ${GREY}(Untracked peers from before this menu existed can be removed${RESET}"
        echo -e "  ${GREY} manually with: ${WHITE}sudo wg set wg0 peer <pubkey> remove${RESET}${GREY})${RESET}"
        echo ""
        read -rp "  Press Enter to return to the manage menu..." _
        return
    fi

    # ── Show numbered list ────────────────────────────────────
    echo ""
    sudo python3 - "$devices_file" <<'PYEOF' 2>/dev/null
import json, sys
path = sys.argv[1]
try:
    with open(path) as f:
        devices = json.load(f)
except Exception:
    sys.exit(1)
RESET = '\033[0m'
WHITE = '\033[38;5;255m'
GREY  = '\033[38;5;244m'
CYAN  = '\033[38;5;117m'
for i, dev in enumerate(devices, 1):
    name  = dev.get('name', '?')
    ip    = dev.get('ip', '?')
    added = dev.get('added_at', '')
    print(f"  {CYAN}{i:>2}.{RESET}  {WHITE}{name:<24}{RESET}  "
          f"{GREY}{ip:<14}  added {added}{RESET}")
PYEOF

    echo ""
    divider
    echo ""
    local choice
    read -rp "  Number of device to remove (or [b] to cancel): " choice

    if [ -z "$choice" ] || [ "$choice" = "b" ] || [ "$choice" = "B" ]; then
        echo -e "  ${AMBER}Cancelled.${RESET}"
        sleep 0.5
        return 0
    fi

    if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
        echo -e "  ${RED}Not a valid number.${RESET}"
        sleep 1
        return 1
    fi

    # ── Look up the chosen device by index ────────────────────
    local lookup
    lookup=$(sudo python3 - "$devices_file" "$choice" <<'PYEOF' 2>/dev/null
import json, sys
path = sys.argv[1]
try:
    idx = int(sys.argv[2]) - 1
    with open(path) as f:
        devices = json.load(f)
    if 0 <= idx < len(devices):
        d = devices[idx]
        # Tab-separated so bash can split easily
        print(f"{d.get('public_key','')}\t{d.get('name','?')}\t{d.get('ip','?')}")
except Exception:
    pass
PYEOF
)

    if [ -z "$lookup" ]; then
        echo -e "  ${RED}Invalid device number.${RESET}"
        sleep 1
        return 1
    fi

    local pubkey name ip
    pubkey=$(echo "$lookup" | cut -f1)
    name=$(echo   "$lookup" | cut -f2)
    ip=$(echo     "$lookup" | cut -f3)

    # ── Confirm ───────────────────────────────────────────────
    echo ""
    echo -e "  ${AMBER}Remove ${WHITE}${name}${AMBER} (${ip})?${RESET}"
    echo -e "  ${GREY}This will revoke the device's access immediately.${RESET}"
    echo ""
    local confirm
    read -rp "  $(echo -e "${AMBER}Type 'yes' to confirm, anything else to cancel${RESET}") ❯ " confirm

    if [ "$confirm" != "yes" ]; then
        echo ""
        echo -e "  ${AMBER}Cancelled.${RESET}"
        sleep 0.5
        return 0
    fi

    echo ""

    # ── Remove from running wg + persist ──────────────────────
    printf "  ${GREY}%-38s${RESET}" "Removing peer from WireGuard..."
    if _wg_remove_peer "$pubkey"; then
        printf "${GREEN}✓${RESET}\n"
    else
        printf "${RED}✗  Failed${RESET}\n"
        echo -e "  ${GREY}Check 'sudo wg show wg0' for state.${RESET}"
        echo ""
        read -rp "  Press Enter to return to the manage menu..." _
        return 1
    fi

    # ── Remove from JSON ──────────────────────────────────────
    printf "  ${GREY}%-38s${RESET}" "Updating devices file..."
    if _wg_untrack_device "$pubkey"; then
        printf "${GREEN}✓${RESET}\n"
    else
        printf "${AMBER}!  Couldn't update file${RESET}\n"
        # Non-fatal — peer is already removed from wg
    fi

    echo ""
    divider
    echo -e "  ${GREEN}✓${RESET}  ${WHITE}${name}${RESET} (${ip}) removed"
    divider
    echo ""
    read -rp "  Press Enter to return to the manage menu..." _
}

# ── WireGuard — Rename a Device ───────────────────────────────
# Lists tracked devices, lets the user pick one by number, then
# prompts for a new name. Updates /etc/safehaven/wg-devices.json
# only — the WireGuard peer config is untouched (names live only
# in our metadata, never in wg0.conf).
rename_wg_device() {
    print_header
    echo -e "  ${BOLD}${WHITE}EDIT DEVICE NAME${RESET}"
    echo -e "  ${GREY}Rename a tracked device. The WireGuard config and IP don't change —${RESET}"
    echo -e "  ${GREY}only the friendly name shown in this menu.${RESET}"
    echo ""
    divider

    local devices_file="/etc/safehaven/wg-devices.json"

    # ── Pre-flight: any tracked devices? ──────────────────────
    if [ ! -f "$devices_file" ] \
       || [ "$(sudo cat "$devices_file" 2>/dev/null)" = "[]" ] \
       || [ -z "$(sudo cat "$devices_file" 2>/dev/null)" ]; then
        echo ""
        echo -e "  ${GREY}No tracked devices to rename.${RESET}"
        echo ""
        read -rp "  Press Enter to return to the manage menu..." _
        return
    fi

    # ── Show numbered list ────────────────────────────────────
    echo ""
    sudo python3 - "$devices_file" <<'PYEOF' 2>/dev/null
import json, sys
path = sys.argv[1]
try:
    with open(path) as f:
        devices = json.load(f)
except Exception:
    sys.exit(1)
RESET = '\033[0m'
WHITE = '\033[38;5;255m'
GREY  = '\033[38;5;244m'
CYAN  = '\033[38;5;117m'
for i, dev in enumerate(devices, 1):
    name  = dev.get('name', '?')
    ip    = dev.get('ip', '?')
    print(f"  {CYAN}{i:>2}.{RESET}  {WHITE}{name:<24}{RESET}  {GREY}{ip}{RESET}")
PYEOF

    echo ""
    divider
    echo ""
    local choice
    read -rp "  Number of device to rename (or [b] to cancel): " choice

    if [ -z "$choice" ] || [ "$choice" = "b" ] || [ "$choice" = "B" ]; then
        echo -e "  ${AMBER}Cancelled.${RESET}"
        sleep 0.5
        return 0
    fi

    if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
        echo -e "  ${RED}Not a valid number.${RESET}"
        sleep 1
        return 1
    fi

    # ── Look up the chosen device ─────────────────────────────
    local lookup
    lookup=$(sudo python3 - "$devices_file" "$choice" <<'PYEOF' 2>/dev/null
import json, sys
path = sys.argv[1]
try:
    idx = int(sys.argv[2]) - 1
    with open(path) as f:
        devices = json.load(f)
    if 0 <= idx < len(devices):
        d = devices[idx]
        print(f"{d.get('public_key','')}\t{d.get('name','?')}\t{d.get('ip','?')}")
except Exception:
    pass
PYEOF
)

    if [ -z "$lookup" ]; then
        echo -e "  ${RED}Invalid device number.${RESET}"
        sleep 1
        return 1
    fi

    local pubkey old_name ip
    pubkey=$(echo   "$lookup" | cut -f1)
    old_name=$(echo "$lookup" | cut -f2)
    ip=$(echo       "$lookup" | cut -f3)

    # ── Get new name ──────────────────────────────────────────
    echo ""
    echo -e "  ${WHITE}Renaming ${BOLD}${old_name}${RESET}${WHITE} (${ip})${RESET}"
    echo -e "  ${GREY}Letters, numbers, spaces, periods, hyphens, underscores. 1-32 chars.${RESET}"
    echo -e "  ${GREY}Press Enter on empty input to cancel.${RESET}"
    echo ""
    local new_name
    read -rp "  New name: " new_name

    # Sanitise (same rules as Add a Device)
    new_name=$(echo "$new_name" | tr -cd 'A-Za-z0-9 _.\-' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [ -z "$new_name" ]; then
        echo ""
        echo -e "  ${AMBER}Cancelled — empty name.${RESET}"
        sleep 0.5
        return 0
    fi
    if [ ${#new_name} -gt 32 ]; then
        new_name="${new_name:0:32}"
    fi

    if [ "$new_name" = "$old_name" ]; then
        echo -e "  ${AMBER}Name unchanged.${RESET}"
        sleep 0.5
        return 0
    fi

    echo ""
    printf "  ${GREY}%-38s${RESET}" "Updating devices file..."
    if _wg_rename_device "$pubkey" "$new_name"; then
        printf "${GREEN}✓${RESET}\n"
    else
        printf "${RED}✗  Failed${RESET}\n"
        echo ""
        read -rp "  Press Enter to return to the manage menu..." _
        return 1
    fi

    echo ""
    divider
    echo -e "  ${GREEN}✓${RESET}  ${WHITE}${old_name}${RESET} → ${WHITE}${new_name}${RESET}"
    divider
    echo ""
    read -rp "  Press Enter to return to the manage menu..." _
}

# ── Manage VPN Devices (sub-menu dispatcher) ──────────────────
# Hub for the per-device VPN flows. Pressing [6] from the main
# menu lands here; from here the user can Add, List, or Remove
# tracked devices. Loops until the user picks Back.
manage_devices() {
    while true; do
        print_header
        echo -e "  ${BOLD}${WHITE}MANAGE VPN DEVICES${RESET}"
        echo -e "  ${GREY}Add new devices, view live status, or revoke access.${RESET}"
        echo ""
        divider
        echo ""
        echo -e "  ${CYAN}[a]${RESET}  ${BOLD}Add a Device${RESET}        ${GREY}Generate a one-time QR for a new device${RESET}"
        echo -e "  ${CYAN}[l]${RESET}  ${BOLD}List Devices${RESET}        ${GREY}Show all peers + live handshake / transfer${RESET}"
        echo -e "  ${CYAN}[e]${RESET}  ${BOLD}Edit Device Name${RESET}    ${GREY}Rename a tracked device${RESET}"
        echo -e "  ${CYAN}[r]${RESET}  ${BOLD}Remove a Device${RESET}     ${GREY}Revoke a peer's access${RESET}"
        echo -e "  ${GREY}[b]${RESET}  ${BOLD}Back to Main Menu${RESET}"
        echo ""
        divider
        echo ""
        local sub_choice
        read -rp "  $(echo -e "${TEAL}${BOLD}devices${RESET}") ❯ " sub_choice
        case "$sub_choice" in
            a|A) show_wg_qr ;;
            l|L) list_wg_devices ;;
            e|E) rename_wg_device ;;
            r|R) remove_wg_device ;;
            b|B|q|Q) return ;;
            *) echo -e "  ${GREY}Not a valid choice.${RESET}" ; sleep 0.8 ;;
        esac
    done
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
        CLI_PW=$(sudo cat /etc/pihole/cli_pw 2>/dev/null)
        if [ -n "$CLI_PW" ]; then
            SID=$(curl -s -X POST http://localhost/api/auth \
                -H "Content-Type: application/json" \
                -d "{\"password\":\"${CLI_PW}\"}" \
                | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('session',{}).get('sid',''))" 2>/dev/null)
            if [ -n "$SID" ]; then
                STATS=$(curl -s -H "X-FTL-SID: ${SID}" http://localhost/api/stats/summary 2>/dev/null)
                echo "$STATS" | python3 -c "
import sys, json
d = json.load(sys.stdin)
q = d.get('queries', {})
g = d.get('gravity', {})
print('  Total queries   : ' + str(q.get('total', 0)))
print('  Blocked         : ' + str(q.get('blocked', 0)))
print('  Percent blocked : ' + str(round(q.get('percent_blocked', 0), 1)) + '%')
print('  Domains on list : ' + str(g.get('domains_being_blocked', 0)))
"
            else
                echo -e "  ${AMBER}Could not authenticate with Pi-hole API.${RESET}"
            fi
        else
            echo -e "  ${AMBER}Pi-hole CLI password not found.${RESET}"
        fi
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


# ── Factory Reset ────────────────────────────────────────────
# Wipes all credentials and session state so the Pi starts fresh.
# Preserves the HTTPS self-signed certificate (regenerating is a hassle
# and the cert doesn't contain personal info anyway).
factory_reset() {
    print_header
    echo -e "  ${RED}${BOLD}FACTORY RESET${RESET}"
    echo ""
    echo -e "  ${GREY}This will permanently delete:${RESET}"
    echo -e "    ${RED}•${RESET} Admin dashboard password  (/etc/safehaven/auth.json)"
    echo -e "    ${RED}•${RESET} Business Mode user accounts  (/etc/safehaven/business-users.json)"
    echo -e "    ${RED}•${RESET} Flask session key — all logged-in sessions will be invalidated"
    echo -e "    ${RED}•${RESET} Active-mode marker  (/tmp/safehaven-mode)"
    echo -e "    ${RED}•${RESET} First-run marker — boot sequence will replay on next launch"
    echo ""
    echo -e "  ${GREY}This will NOT delete:${RESET}"
    echo -e "    ${GREEN}•${RESET} HTTPS certificate  (/etc/safehaven/ssl/)"
    echo -e "    ${GREEN}•${RESET} Hotspot / hostname / sudo password — run Setup Wizard again for those"
    echo -e "    ${GREEN}•${RESET} WireGuard keypair — run Setup Wizard to regenerate"
    echo -e "    ${GREEN}•${RESET} Service configs, installed packages, logs"
    echo ""
    echo -e "  ${AMBER}${BOLD}This cannot be undone.${RESET}"
    echo ""
    read -rp "  $(echo -e "${AMBER}Type ${BOLD}RESET${RESET}${AMBER} in capitals to confirm, anything else to cancel${RESET}") ❯ " confirm
    if [[ "$confirm" != "RESET" ]]; then
        echo ""
        echo -e "  ${GREY}Factory reset cancelled.${RESET}"
        sleep 1
        return
    fi

    echo ""
    echo -e "  ${GREY}Performing factory reset...${RESET}"
    echo ""

    rm -f /etc/safehaven/auth.json              && echo -e "  ${GREEN}✓${RESET}  Admin credentials removed"
    rm -f /etc/safehaven/business-users.json    && echo -e "  ${GREEN}✓${RESET}  Business user accounts removed"
    rm -f /etc/safehaven/secret.key             && echo -e "  ${GREEN}✓${RESET}  Flask session key removed"
    rm -f /tmp/safehaven-mode                   && echo -e "  ${GREEN}✓${RESET}  Active-mode marker cleared"
    rm -f /var/lib/safehaven/.first-run 2>/dev/null
    echo -e "  ${GREEN}✓${RESET}  First-run marker cleared"

    # Stop the Flask dashboard if running — it would serve stale state otherwise
    pkill -f 'python3 app.py' 2>/dev/null && echo -e "  ${GREEN}✓${RESET}  Flask dashboard stopped"

    echo ""
    divider
    echo -e "  ${GREEN}${BOLD}Factory reset complete.${RESET}"
    echo ""
    echo -e "  ${GREY}Next steps:${RESET}"
    echo -e "    ${WHITE}1.${RESET}  Run the Setup Wizard to reconfigure hotspot / hostname / keys:  ${CYAN}press [w]${RESET}"
    echo -e "    ${WHITE}2.${RESET}  Set the admin dashboard password:  ${CYAN}sudo python3 app.py --set-admin-password${RESET}"
    echo -e "    ${WHITE}3.${RESET}  Restart the Flask dashboard:  ${CYAN}sudo python3 app.py${RESET}"
    echo ""
    read -rp "  Press Enter to return to the menu..." _
}


# ── Setup Wizard ──────────────────────────────────────────────
setup_wizard() {
    print_header
    echo -e "  ${TEAL}${BOLD}SETUP WIZARD${RESET}"
    echo -e "  ${GREY}This wizard will walk you through configuring SafeHaven Pi.${RESET}"
    echo -e "  ${GREY}You can run this again at any time from the System menu.${RESET}"
    echo ""
    divider
    echo ""
    echo -e "  ${GREY}You will be asked to set:${RESET}"
    echo -e "  ${WHITE}  1.${RESET}  Your hotspot name and password"
    echo -e "  ${WHITE}  2.${RESET}  Your Pi hostname"
    echo -e "  ${WHITE}  3.${RESET}  Your admin (sudo) password"
    echo -e "  ${WHITE}  4.${RESET}  WireGuard VPN keys"
    echo ""
    echo -e "  ${AMBER}None of this is stored in the GitHub repository.${RESET}"
    echo -e "  ${GREY}All values are written directly to your Pi only.${RESET}"
    echo ""
    read -rp "  Press Enter to begin, or Ctrl+C to cancel..." _
    echo ""

    # ── Step 1: Hotspot ───────────────────────────────────────
    divider
    echo ""
    echo -e "  ${TEAL}${BOLD}STEP 1 of 4  —  WiFi Hotspot${RESET}"
    echo ""
    echo -e "  ${GREY}This is the WiFi network name that other devices will see and${RESET}"
    echo -e "  ${GREY}connect to. Choose something that doesn't identify you personally.${RESET}"
    echo ""

    local current_ssid
    current_ssid=$(grep "^ssid=" /etc/hostapd/hostapd.conf 2>/dev/null | cut -d= -f2 || echo "not set")
    echo -e "  ${GREY}Current hotspot name: ${WHITE}${current_ssid}${RESET}"
    echo ""

    local ssid
    read -rp "  Enter hotspot name (e.g. FreeAirport_WiFi): " ssid
    if [ -z "$ssid" ]; then
        echo -e "  ${AMBER}Skipped — hotspot name unchanged.${RESET}"
    else
        local pass1 pass2
        echo ""
        echo -e "  ${GREY}Now set a password for your hotspot.${RESET}"
        echo -e "  ${GREY}Minimum 8 characters — make it something strong.${RESET}"
        echo ""
        while true; do
            read -rsp "  Enter hotspot password: " pass1
            echo ""
            read -rsp "  Confirm hotspot password: " pass2
            echo ""
            if [ "$pass1" != "$pass2" ]; then
                echo -e "  ${RED}Passwords do not match — try again.${RESET}"
                echo ""
            elif [ ${#pass1} -lt 8 ]; then
                echo -e "  ${RED}Password too short — minimum 8 characters.${RESET}"
                echo ""
            else
                break
            fi
        done

        # Write to hostapd.conf
        if [ -f /etc/hostapd/hostapd.conf ]; then
            sed -i "s/^ssid=.*/ssid=${ssid}/" /etc/hostapd/hostapd.conf
            sed -i "s/^wpa_passphrase=.*/wpa_passphrase=${pass1}/" /etc/hostapd/hostapd.conf
            echo -e "  ${GREEN}✓  Hotspot name set to: ${WHITE}${ssid}${RESET}"
        else
            echo -e "  ${AMBER}!  hostapd.conf not found at /etc/hostapd/hostapd.conf${RESET}"
            echo -e "  ${GREY}   Run install.sh first to set up the config files.${RESET}"
        fi
    fi

    echo ""
    read -rp "  Press Enter to continue to Step 2..." _
    echo ""

    # ── Step 2: Hostname ──────────────────────────────────────
    divider
    echo ""
    echo -e "  ${TEAL}${BOLD}STEP 2 of 4  —  Pi Hostname${RESET}"
    echo ""
    echo -e "  ${GREY}The hostname is what your Pi calls itself on the network.${RESET}"
    echo -e "  ${GREY}Changing it from the default 'raspberrypi' is good practice.${RESET}"
    echo ""

    local current_hostname
    current_hostname=$(hostname)
    echo -e "  ${GREY}Current hostname: ${WHITE}${current_hostname}${RESET}"
    echo ""

    local new_hostname
    read -rp "  Enter new hostname (e.g. safehaven-pi): " new_hostname
    if [ -z "$new_hostname" ]; then
        echo -e "  ${AMBER}Skipped — hostname unchanged.${RESET}"
    else
        hostnamectl set-hostname "$new_hostname" 2>/dev/null
        sed -i "s/127.0.1.1.*/127.0.1.1	${new_hostname}/" /etc/hosts 2>/dev/null
        echo -e "  ${GREEN}✓  Hostname set to: ${WHITE}${new_hostname}${RESET}"
        echo -e "  ${GREY}   This will take effect after a reboot.${RESET}"
    fi

    echo ""
    read -rp "  Press Enter to continue to Step 3..." _
    echo ""

    # ── Step 3: Admin Password ────────────────────────────────
    divider
    echo ""
    echo -e "  ${TEAL}${BOLD}STEP 3 of 4  —  Admin Password${RESET}"
    echo ""
    echo -e "  ${GREY}This changes the password for the current user account (${WHITE}$(whoami)${GREY}).${RESET}"
    echo -e "  ${GREY}The default Raspberry Pi password is well known — change it.${RESET}"
    echo ""

    local change_pass
    read -rp "  Change admin password? (y/n): " change_pass
    if [[ "$change_pass" =~ ^[Yy]$ ]]; then
        passwd "$(whoami)"
        echo ""
        echo -e "  ${GREEN}✓  Password updated.${RESET}"
    else
        echo -e "  ${AMBER}Skipped — password unchanged.${RESET}"
    fi

    echo ""
    read -rp "  Press Enter to continue to Step 4..." _
    echo ""

    # ── Step 4: WireGuard Keys ────────────────────────────────
    divider
    echo ""
    echo -e "  ${TEAL}${BOLD}STEP 4 of 4  —  WireGuard VPN Keys${RESET}"
    echo ""
    echo -e "  ${GREY}WireGuard needs a pair of keys to encrypt your VPN tunnel.${RESET}"
    echo -e "  ${GREY}These are generated on your Pi and never leave it.${RESET}"
    echo ""

    if [ -f /etc/wireguard/privatekey ]; then
        echo -e "  ${AMBER}WireGuard keys already exist.${RESET}"
        local regen
        read -rp "  Regenerate them? This will disconnect any connected devices. (y/n): " regen
        if [[ ! "$regen" =~ ^[Yy]$ ]]; then
            echo -e "  ${GREY}Skipped — existing keys kept.${RESET}"
            echo ""
            read -rp "  Press Enter to finish..." _
            wizard_complete
            return
        fi
    fi

    echo ""
    echo -e "  ${GREY}Generating new WireGuard keypair...${RESET}"
    wg genkey | tee /etc/wireguard/privatekey | wg pubkey > /etc/wireguard/publickey
    chmod 600 /etc/wireguard/privatekey
    echo -e "  ${GREEN}✓  Keys generated and saved to /etc/wireguard/${RESET}"
    echo ""
    echo -e "  ${GREY}Your public key (share this with devices you want to connect):${RESET}"
    echo ""
    echo -e "  ${CYAN}$(cat /etc/wireguard/publickey)${RESET}"
    echo ""
    echo -e "  ${AMBER}Important: Update your wg0.conf with the new private key.${RESET}"
    echo -e "  ${GREY}See configs/wg0.conf in the repository for the template.${RESET}"

    echo ""
    read -rp "  Press Enter to finish..." _
    wizard_complete
}

wizard_complete() {
    echo ""
    divider
    echo ""
    echo -e "  ${GREEN}${BOLD}✓  Setup complete!${RESET}"
    echo ""
    echo -e "  ${GREY}Here is a summary of what was configured:${RESET}"
    echo ""
    echo -e "  ${WHITE}Hotspot name : ${TEAL}$(grep "^ssid=" /etc/hostapd/hostapd.conf 2>/dev/null | cut -d= -f2 || echo "not configured")${RESET}"
    echo -e "  ${WHITE}Hostname     : ${TEAL}$(hostname)${RESET}"
    echo -e "  ${WHITE}WireGuard    : ${TEAL}$([ -f /etc/wireguard/publickey ] && echo "Keys ready" || echo "Not configured")${RESET}"
    echo ""
    echo -e "  ${GREY}When you're ready, run ${WHITE}sudo safehaven${GREY} to start the full system.${RESET}"
    echo ""
    divider
    read -rp "  Press Enter to return to the menu..." _
}


# ── Threat Log Export ─────────────────────────────────────────
export_threat_log() {
    print_header
    echo -e "  ${TEAL}${BOLD}THREAT LOG EXPORT${RESET}"
    echo -e "  ${GREY}Exports the last 24 hours of security activity to a text file.${RESET}"
    echo -e "  ${GREY}Useful for reviewing what SafeHaven Pi has been detecting.${RESET}"
    echo ""
    divider
    echo ""

    local timestamp
    timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
    local output_file="/home/${SUDO_USER:-pi}/Desktop/safehaven_report_${timestamp}.txt"

    echo -e "  ${GREY}Collecting data from all security services...${RESET}"
    echo ""

    {
        echo "============================================================"
        echo "  SafeHaven Pi — Security Report"
        echo "  Generated: $(date '+%A %d %B %Y at %H:%M:%S')"
        echo "  Device:    $(cat /proc/device-tree/model 2>/dev/null | tr -d '')"
        echo "  Hostname:  $(hostname)"
        echo "  Uptime:    $(uptime -p | sed 's/up //')"
        echo "============================================================"
        echo ""

        echo "── SERVICE STATUS ──────────────────────────────────────────"
        for svc in hostapd nftables pihole-FTL suricata fail2ban cowrie tailscaled; do
            if systemctl is-active --quiet "$svc" 2>/dev/null; then
                printf "  %-30s RUNNING
" "$svc"
            else
                printf "  %-30s STOPPED
" "$svc"
            fi
        done
        if ip link show wg0 &>/dev/null; then
            printf "  %-30s ACTIVE
" "wireguard (wg0)"
        else
            printf "  %-30s DOWN
" "wireguard (wg0)"
        fi
        echo ""

        echo "── SYSTEM STATS ────────────────────────────────────────────"
        echo "  CPU load : $(top -bn1 | grep "Cpu(s)" | awk '{print $2}')%"
        echo "  RAM      : $(free -m | awk 'NR==2{print $3}') / $(free -m | awk 'NR==2{print $2}') MB"
        echo "  VPN peers: $(wg show wg0 peers 2>/dev/null | grep -c . || echo 0)"
        echo ""

        echo "── SURICATA ALERTS (last 24 hours) ─────────────────────────"
        local suricata_log="/var/log/suricata/fast.log"
        if [ -f "$suricata_log" ]; then
            local count
            count=$(wc -l < "$suricata_log" 2>/dev/null || echo "0")
            echo "  Total alerts in log: $count"
            echo ""
            tail -50 "$suricata_log" 2>/dev/null || echo "  No recent alerts."
        else
            echo "  No Suricata log found — no threats detected yet."
        fi
        echo ""

        echo "── FAIL2BAN — BANNED IPs ───────────────────────────────────"
        if command -v fail2ban-client &>/dev/null; then
            fail2ban-client status 2>/dev/null || echo "  Fail2ban not running."
            echo ""
            fail2ban-client status sshd 2>/dev/null || true
        else
            echo "  Fail2ban not found."
        fi
        echo ""

        echo "── COWRIE HONEYPOT SESSIONS ────────────────────────────────"
        local cowrie_log="/home/cowrie/cowrie/var/log/cowrie/cowrie.json"
        if [ -f "$cowrie_log" ]; then
            local sessions commands src_ips
            sessions=$(grep -c '"eventid":"cowrie.session.connect"' "$cowrie_log" 2>/dev/null; true)
            commands=$(grep -c '"eventid":"cowrie.command.input"' "$cowrie_log" 2>/dev/null; true)
            sessions="${sessions:-0}"
            commands="${commands:-0}"
            src_ips=$(grep '"eventid":"cowrie.session.connect"' "$cowrie_log" 2>/dev/null | grep -o '"src_ip":"[^"]*"' | sort -u | wc -l | tr -d ' ')
            echo "  Total connection attempts : $sessions"
            echo "  Commands attempted        : $commands"
            echo "  Unique attacker IPs       : $src_ips"
            echo ""
            # Show last 5 connection attempts with IP and timestamp
            if [ "$sessions" -gt 0 ]; then
                echo "  Last connection attempts:"
                grep '"eventid":"cowrie.session.connect"' "$cowrie_log" 2>/dev/null | tail -5 | while read -r line; do
                    local ts ip
                    ts=$(echo "$line" | grep -o '"timestamp":"[^"]*"' | cut -d: -f2-3 | tr -d '"' | cut -dT -f1-2 | tr T ' ')
                    ip=$(echo "$line" | grep -o '"src_ip":"[^"]*"' | cut -d: -f2 | tr -d '"')
                    echo "    $ts  —  $ip"
                done
            else
                echo "  No connection attempts yet — honeypot is waiting."
            fi
        else
            echo "  Cowrie has not created a log yet — no attacks received."
        fi
        echo ""

        echo "── PI-HOLE DNS BLOCKS ──────────────────────────────────────"
        if command -v pihole &>/dev/null; then
            # Authenticate with Pi-hole v6 using cli_pw
            local cli_pw sid ph_stats queries blocked clients gravity_blocked
            cli_pw=$(cat /etc/pihole/cli_pw 2>/dev/null)

            if [ -n "$cli_pw" ]; then
                sid=$(curl -s -X POST "http://localhost/api/auth" \
                    -H "Content-Type: application/json" \
                    -d "{\"password\":\"${cli_pw}\"}" 2>/dev/null \
                    | grep -o '"sid":"[^"]*"' | cut -d: -f2 | tr -d '"')
            fi

            if [ -n "$sid" ]; then
                ph_stats=$(curl -s "http://localhost/api/stats/summary" -H "X-FTL-SID: ${sid}" 2>/dev/null)
                queries=$(echo "$ph_stats" | grep -o '"total":[0-9]*' | head -1 | cut -d: -f2)
                blocked=$(echo "$ph_stats" | grep -o '"blocked":[0-9]*' | head -1 | cut -d: -f2)
                clients=$(echo "$ph_stats" | grep -o '"active":[0-9]*' | head -1 | cut -d: -f2)
                gravity_blocked=$(echo "$ph_stats" | grep -o '"domains_being_blocked":[0-9]*' | cut -d: -f2)
                echo "  DNS queries today    : ${queries:-0}"
                echo "  Queries blocked      : ${blocked:-0}"
                echo "  Active clients       : ${clients:-0}"
                echo "  Blocklist size       : ${gravity_blocked:-0} domains"
            else
                echo "  Pi-hole stats unavailable — could not authenticate."
            fi
        else
            echo "  Pi-hole not found."
        fi
        echo ""

        echo "── WIREGUARD PEERS ─────────────────────────────────────────"
        wg show 2>/dev/null || echo "  WireGuard not active."
        echo ""

        echo "============================================================"
        echo "  End of report — SafeHaven Pi v1.0-alpha"
        echo "  github.com/MursheenDurkin/SafeHaven-PI"
        echo "============================================================"

    } > "$output_file" 2>/dev/null

    if [ -f "$output_file" ]; then
        echo -e "  ${GREEN}${BOLD}✓  Report saved!${RESET}"
        echo ""
        echo -e "  ${WHITE}File: ${CYAN}${output_file}${RESET}"
        echo ""
        echo -e "  ${GREY}Sections included:${RESET}"
        echo -e "  ${WHITE}·${RESET}  Service status snapshot"
        echo -e "  ${WHITE}·${RESET}  System stats (CPU, RAM, VPN peers)"
        echo -e "  ${WHITE}·${RESET}  Suricata alerts (last 50)"
        echo -e "  ${WHITE}·${RESET}  Fail2ban banned IPs"
        echo -e "  ${WHITE}·${RESET}  Cowrie honeypot sessions today"
        echo -e "  ${WHITE}·${RESET}  Pi-hole DNS block stats"
        echo -e "  ${WHITE}·${RESET}  WireGuard peer connections"
    else
        echo -e "  ${RED}Could not save report. Is the Desktop accessible?${RESET}"
        echo -e "  ${GREY}Try running: sudo safehaven${RESET}"
    fi

    echo ""
    divider
    read -rp "  Press Enter to return to the menu..." _
}

# ── Flag Handlers ─────────────────────────────────────────────
show_version() {
    local pi_model
    pi_model=$(cat /proc/device-tree/model 2>/dev/null | tr -d '\0' || echo "Raspberry Pi")
    echo ""
    echo -e "${TEAL}${BOLD}SafeHaven Pi${RESET}"
    echo -e "  Version   : ${WHITE}1.0-alpha${RESET}"
    echo -e "  Build date: ${WHITE}March 2026${RESET}"
    echo -e "  Hardware  : ${WHITE}${pi_model}${RESET}"
    echo -e "  Kernel    : ${WHITE}$(uname -r)${RESET}"
    echo -e "  Author    : ${WHITE}Durkin — UWTSD 2026${RESET}"
    echo -e "  Licence   : ${WHITE}GPL v3${RESET}"
    echo -e "  Repo      : ${CYAN}github.com/MursheenDurkin/SafeHaven-PI${RESET}"
    echo ""
}

show_help() {
    echo ""
    echo -e "${TEAL}${BOLD}SafeHaven Pi — Usage${RESET}"
    echo ""
    echo -e "  ${WHITE}sudo safehaven${RESET}             Boot sequence + full control menu"
    echo -e "  ${WHITE}sudo safehaven --status${RESET}    Quick check — are all services running?"
    echo -e "  ${WHITE}sudo safehaven --version${RESET}   Show version and build info"
    echo -e "  ${WHITE}sudo safehaven --help${RESET}      Show this help screen"
    echo ""
    echo -e "  ${GREY}Once inside the menu:${RESET}"
    echo -e "  ${WHITE}[1-3]${RESET}  Activate a protection mode"
    echo -e "  ${WHITE}[4]${RESET}    View live security logs"
    echo -e "  ${WHITE}[5]${RESET}    Add a device to the VPN via QR code"
    echo -e "  ${WHITE}[6]${RESET}    View Pi-hole DNS block statistics"
    echo -e "  ${WHITE}[7]${RESET}    Open the web dashboard"
    echo -e "  ${WHITE}[s]${RESET}    Stop all services safely"
    echo -e "  ${WHITE}[r]${RESET}    Reboot the Pi"
    echo -e "  ${WHITE}[x]${RESET}    Shutdown the Pi safely"
    echo -e "  ${WHITE}[f]${RESET}    Factory reset (wipes all credentials)"
    echo -e "  ${WHITE}[q]${RESET}    Quit menu — protection keeps running"
    echo ""
    echo -e "  ${GREY}Privacy is a right, not a product.${RESET}"
    echo ""
}

show_quick_status() {
    local pi_model
    pi_model=$(cat /proc/device-tree/model 2>/dev/null | tr -d '\0' || echo "Raspberry Pi")
    echo ""
    echo -e "${TEAL}${BOLD}SafeHaven Pi — Quick Status${RESET}   ${GREY}${pi_model}${RESET}"
    echo ""

    local services=(
        "hostapd:WiFi Hotspot"
        "nftables:Firewall"
        "pihole-FTL:DNS Filter (Pi-hole)"
        "suricata:Threat Detection (Suricata)"
        "fail2ban:Brute Force Block (Fail2ban)"
        "cowrie:Honeypot Decoy (Cowrie)"
        "tailscaled:Remote Admin (Tailscale)"
    )

    local all_ok=true
    for entry in "${services[@]}"; do
        local svc="${entry%%:*}"
        local label="${entry##*:}"
        printf "  %-36s" "$label"
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            printf "${GREEN}● RUNNING${RESET}\n"
        else
            printf "${RED}○ STOPPED${RESET}\n"
            all_ok=false
        fi
    done

    printf "  %-36s" "VPN Tunnel (WireGuard)"
    if ip link show wg0 &>/dev/null; then
        printf "${GREEN}● ACTIVE${RESET}\n"
    else
        printf "${RED}○ DOWN${RESET}\n"
        all_ok=false
    fi

    echo ""
    if [ "$all_ok" = true ]; then
        echo -e "  ${GREEN}${BOLD}All systems operational. You are protected.${RESET}"
    else
        echo -e "  ${AMBER}${BOLD}One or more services are not running.${RESET}"
        echo -e "  ${GREY}Run ${WHITE}sudo safehaven${GREY} to start everything up.${RESET}"
    fi
    echo ""
}

# ── Entry Point ───────────────────────────────────────────────
case "$1" in
    --version|-v)
        show_version
        exit 0
        ;;
    --help|-h)
        show_help
        exit 0
        ;;
    --status|-s)
        show_quick_status
        exit 0
        ;;
    --factory-reset)
        if [ "$EUID" -ne 0 ]; then
            echo ""
            echo -e "  ${RED}Factory reset requires sudo.${RESET}"
            echo -e "  ${WHITE}  sudo safehaven --factory-reset${RESET}"
            echo ""
            exit 1
        fi
        factory_reset
        exit 0
        ;;
esac

if [ "$EUID" -ne 0 ]; then
    echo ""
    echo -e "  ${AMBER}${BOLD}Please run with sudo to get full control:${RESET}"
    echo -e "  ${WHITE}  sudo safehaven${RESET}"
    echo ""
    sleep 1
fi

boot_screen
if [ ! -f /tmp/safehaven-booted ]; then
    run_startup
    touch /tmp/safehaven-booted
fi
main_menu
