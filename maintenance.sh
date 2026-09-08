#!/bin/bash

# ============================================
# macOS Maintenance Script
# Main Entry Point
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

source "$LIB_DIR/colors.sh"
source "$LIB_DIR/helpers.sh"
source "$LIB_DIR/system-update.sh"
source "$LIB_DIR/ios-clean.sh"
source "$LIB_DIR/android-clean.sh"
source "$LIB_DIR/node-clean.sh"
source "$LIB_DIR/flutter-clean.sh"
source "$LIB_DIR/system-clean.sh"
source "$LIB_DIR/docker-clean.sh"
source "$LIB_DIR/storage-optimize.sh"
source "$LIB_DIR/restart-macos.sh"
source "$LIB_DIR/devtools-clean.sh"
source "$LIB_DIR/assets-clean.sh"
source "$LIB_DIR/browser-clean.sh"
source "$LIB_DIR/ide-clean.sh"
source "$LIB_DIR/apps-clean.sh"

LOG_FILE="$HOME/dev_cleaner_macOS_$(date +%Y%m%d_%H%M%S).log"
TOTAL_CLEANED=0

# ============================================
# Main Menu
# ============================================

show_menu() {
    clear
    print_header
    echo -e "  ${PURPLE}Available Options:${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC}  Run complete maintenance"
    echo -e "  ${GREEN}2)${NC}  Update system and Homebrew"
    echo -e "  ${GREEN}3)${NC}  Clean update cache"
    echo -e "  ${GREEN}4)${NC}  Clean system (caches, logs, Xcode, DNS)"
    echo -e "  ${GREEN}5)${NC}  Clean system assets (AssetsV2, iCloud, Spotlight)"
    echo -e "  ${GREEN}6)${NC}  Optimize storage"
    echo -e "  ${GREEN}7)${NC}  Clean iOS simulator"
    echo -e "  ${GREEN}8)${NC}  Clean iOS firmwares (IPSW)"
    echo -e "  ${GREEN}9)${NC}  Clean Android Studio & Emulator"
    echo -e "  ${GREEN}10)${NC} Clean Node.js (NPM, PNPM, Bun, Yarn)"
    echo -e "  ${GREEN}11)${NC} Clean Flutter / Dart / FVM"
    echo -e "  ${GREEN}12)${NC} Clean dev tools (Homebrew, CocoaPods, Ruby, Python)"
    echo -e "  ${GREEN}13)${NC} Clean Docker"
    echo -e "  ${GREEN}14)${NC} Clean browser caches"
    echo -e "  ${GREEN}15)${NC} Clean IDE caches (JetBrains, VSCode, Zed Editor)"
    echo -e "  ${GREEN}16)${NC} Clean app caches (Slack, Discord, Spotify...)"
    echo -e "  ${GREEN}17)${NC} View action log"
    echo -e "  ${GREEN}18)${NC} Restart macOS"
    echo -e "  ${GREEN}0)${NC}  Exit"
    echo ""
    echo -ne "  ${CYAN}→ Choose an option: ${NC}"
}

run_full_maintenance() {
    local initial_space=$(get_disk_usage)

    print_header
    echo -e "${YELLOW}Initial free space: $initial_space${NC}\n"

    update_system
    clean_software_update_cache
    clean_system_clean
    clean_system_assets
    clean_ios_simulator
    clean_ios_ipsw
    clean_android_studio
    clean_system_nodejs
    clean_flutter_dart
    clean_system_devtools
    optimize_storage
    clean_docker
    cleanup_browser_caches
    cleanup_ide_caches
    cleanup_app_caches
    restart_macos

    local final_space=$(get_disk_usage)

    echo ""
    print_section "Maintenance Summary"
    echo -e "${GREEN}Initial free space:${NC} $initial_space"
    echo -e "${GREEN}Final free space:${NC}   $final_space"
    echo -e "${GREEN}Total cleaned:${NC}      $(format_bytes $((TOTAL_CLEANED * 1024)))"
    echo ""
    print_success "Maintenance complete!"
    print_warning "System restart recommended"
    echo ""

    log_action "Complete maintenance executed - Total: $(format_bytes $((TOTAL_CLEANED * 1024)))"
}

# ============================================
# Main Loop
# ============================================

main() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        print_error "This script is for macOS only!"
        exit 1
    fi

    touch "$LOG_FILE"
    log_action "Starting maintenance script"

    while true; do
        show_menu
        read -r option
        case $option in
            1)  run_full_maintenance ;;
            2)  update_system ;;
            3)  clean_software_update_cache ;;
            4)  clean_system_clean ;;
            5)  clean_system_assets ;;
            6)  optimize_storage ;;
            7)  clean_ios_simulator ;;
            8)  clean_ios_ipsw ;;
            9)  clean_android_studio ;;
            10) clean_system_nodejs ;;
            11) clean_flutter_dart ;;
            12) clean_system_devtools ;;
            13) clean_docker ;;
            14) cleanup_browser_caches ;;
            15) cleanup_ide_caches ;;
            16) cleanup_app_caches ;;
            17) cat "$LOG_FILE" | less ;;
            18) restart_macos ;;
            0)
                print_success "Goodbye!"
                log_action "Script finished"
                exit 0
                ;;
            *)
                print_error "Invalid option!"
                ;;
        esac

        echo ""
        read -p "Press ENTER to continue..."
    done
}

main
