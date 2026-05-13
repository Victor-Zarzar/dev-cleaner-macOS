#!/bin/bash

# ============================================
# System Cleaning Functions (expanded)
# ============================================

clean_system_caches() {
    print_section "Cleaning System Caches"

    local cache_dir="$HOME/Library/Caches"
    if [ -d "$cache_dir" ]; then
        local size
        size=$(get_folder_size "$cache_dir")
        size=${size:-0}
        local count=0
        local total
        total=$(find "$cache_dir" -mindepth 1 -maxdepth 1 | wc -l)

        for item in "$cache_dir"/*; do
            rm -rf "$item" 2>/dev/null
            ((count++))
            show_progress $count $total
        done
        echo ""
        print_success "User caches cleaned: $(format_bytes $((size * 1024)))"
        TOTAL_CLEANED=$((TOTAL_CLEANED + size))
    fi

    local other_paths=(
        "$HOME/Library/Logs"
        "$HOME/Library/Application Support/CrashReporter"
    )
    for path in "${other_paths[@]}"; do
        if [ -d "$path" ]; then
            local size
            size=$(get_folder_size "$path")
            size=${size:-0}
            rm -rf "$path"/* 2>/dev/null
            print_success "$(basename "$path"): $(format_bytes $((size * 1024)))"
            TOTAL_CLEANED=$((TOTAL_CLEANED + size))
        fi
    done

    local diag_path="/Library/Logs/DiagnosticReports"
    if [ -d "$diag_path" ]; then
        local size
        size=$(get_folder_size "$diag_path")
        size=${size:-0}
        sudo rm -rf "$diag_path"/* 2>/dev/null && \
            print_success "System DiagnosticReports: $(format_bytes $((size * 1024)))"
        TOTAL_CLEANED=$((TOTAL_CLEANED + size))
    fi

    log_action "System caches cleaned"
}

clean_downloads_trash() {
    print_section "Cleaning Downloads and Trash"

    print_info "Emptying trash..."
    rm -rf "$HOME/.Trash"/* 2>/dev/null && print_success "Trash emptied"

    print_info "Removing old downloads (+30 days)..."
    find "$HOME/Downloads" -type f -mtime +30 -delete 2>/dev/null && \
        print_success "Old downloads removed"

    log_action "Downloads and trash cleaned"
}

clean_logs() {
    print_section "Cleaning Old Logs"

    find "$HOME/Library/Logs" -name "*.log" -mtime +7 -delete 2>/dev/null && \
        print_success "User logs removed (>7 days)"

    sudo find /var/log -name "*.log" -mtime +14 -delete 2>/dev/null && \
        print_success "System logs removed (>14 days)"

    log_action "Old logs removed"
}

clean_xcode_cache() {
    print_section "Cleaning Xcode Cache"

    local paths=(
        "$HOME/Library/Developer/Xcode/Products"
        "$HOME/Library/Developer/Xcode/iOS Device Logs"
        "$HOME/Library/Developer/Xcode/UserData/Previews"
        "$HOME/Library/Developer/Xcode/DocumentationCache"
        "$HOME/Library/Developer/CoreSimulator/Devices/*/data/Library/Caches"
        "$HOME/Library/Developer/CoreSimulator/Devices/*/data/tmp"
        "$HOME/Library/Logs/CoreSimulator"
    )

    for path in "${paths[@]}"; do
        if [ -d "$path" ]; then
            local size=$(get_folder_size "$path")
            rm -rf "$path" 2>/dev/null && \
                print_success "$(basename "$path"): $(format_bytes $((size * 1024)))"
            TOTAL_CLEANED=$((TOTAL_CLEANED + size))
        fi
    done

    log_action "Xcode cache cleaned"
}

clean_xcode_derived_data() {
    print_section "Cleaning Xcode DerivedData & Archives"

    local total_size=0

    local derived_data="$HOME/Library/Developer/Xcode/DerivedData"
    if [ -d "$derived_data" ]; then
        local size
        size=$(get_folder_size "$derived_data")
        size=${size:-0}
        if [ "$size" -gt 0 ]; then
            print_warning "DerivedData: $(format_bytes $((size * 1024))) — removing..."
            rm -rf "$derived_data"/* 2>/dev/null && \
                print_success "DerivedData removed: $(format_bytes $((size * 1024)))"
            total_size=$((total_size + size))
        fi
    fi

    local archives="$HOME/Library/Developer/Xcode/Archives"
    if [ -d "$archives" ]; then
        local size
        size=$(get_folder_size "$archives")
        size=${size:-0}
        if [ "$size" -gt 0 ]; then
            print_info "Xcode Archives: $(format_bytes $((size * 1024)))"
            echo -n "Remove ALL Xcode archives? These can't be recovered! (y/N): "
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                rm -rf "$archives"/* 2>/dev/null && \
                    print_success "Archives removed: $(format_bytes $((size * 1024)))"
                total_size=$((total_size + size))
            else
                print_info "Archives kept"
            fi
        fi
    fi

    local device_support="$HOME/Library/Developer/Xcode/iOS DeviceSupport"
    if [ -d "$device_support" ]; then
        local size
        size=$(get_folder_size "$device_support")
        size=${size:-0}
        if [ "$size" -gt 0 ]; then
            print_info "iOS DeviceSupport symbols: $(format_bytes $((size * 1024)))"
            print_warning "Keeping only 2 most recent versions..."
            ls -t "$device_support" | tail -n +3 | while read -r entry; do
                rm -rf "$device_support/$entry" 2>/dev/null
            done
            local new_size=$(get_folder_size "$device_support")
            local cleaned=$((size - new_size))
            if [ "$cleaned" -gt 0 ]; then
                print_success "Old DeviceSupport removed: $(format_bytes $((cleaned * 1024)))"
                total_size=$((total_size + cleaned))
            fi
        fi
    fi

    if [ "$total_size" -gt 0 ]; then
        print_success "Total Xcode DerivedData/Archives: $(format_bytes $((total_size * 1024)))"
        TOTAL_CLEANED=$((TOTAL_CLEANED + total_size))
    else
        print_info "Nothing to clean in Xcode DerivedData/Archives"
    fi

    log_action "Xcode DerivedData & Archives cleaned"
}

clean_app_containers() {
    print_section "Cleaning App Sandbox Containers"

    local containers_path="$HOME/Library/Containers"
    if [ ! -d "$containers_path" ]; then
        print_info "No Containers folder found"
        return
    fi

    local total_size=0
    local cleaned=0

    for container in "$containers_path"/*/; do
        local cache="$container/Data/Library/Caches"
        local logs="$container/Data/Library/Logs"

        for target in "$cache" "$logs"; do
            if [ -d "$target" ]; then
                local size
                size=$(get_folder_size "$target")
                size=${size:-0}
                if [ "$size" -gt 10240 ]; then
                    rm -rf "$target"/* 2>/dev/null
                    total_size=$((total_size + size))
                    ((cleaned++))
                fi
            fi
        done
    done

    if [ "$cleaned" -gt 0 ]; then
        print_success "App containers cleaned ($cleaned apps): $(format_bytes $((total_size * 1024)))"
        TOTAL_CLEANED=$((TOTAL_CLEANED + total_size))
    else
        print_info "App containers already clean"
    fi

    log_action "App Sandbox Containers cleaned"
}

flush_dns_cache() {
    print_section "Flushing DNS Cache"

    sudo dscacheutil -flushcache 2>/dev/null
    sudo killall -HUP mDNSResponder 2>/dev/null && \
        print_success "DNS cache flushed" || \
        print_info "DNS flush failed (check sudo permissions)"

    log_action "DNS cache flushed"
}

# ── entrypoint ─────────────────────────────

clean_system_clean() {
    clean_system_caches
    clean_downloads_trash
    clean_logs
    clean_xcode_derived_data
    clean_xcode_cache
    clean_app_containers
    flush_dns_cache
}
