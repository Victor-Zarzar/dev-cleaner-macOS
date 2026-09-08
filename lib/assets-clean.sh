#!/bin/bash

# ============================================
# System Assets & Templates Cleaning
# Targets /Library/AssetsV2 and app templates
# that accumulate silently over time
# ============================================

_assets_root() {
    echo "/Library/AssetsV2"
}

_print_dir_table() {
    local parent="$1"
    local total=0
    for entry in "$parent"/*/; do
        [ -d "$entry" ] || continue
        local size
        size=$(get_folder_size "$entry")
        size=${size:-0}
        total=$((total + size))
        printf "  • %-55s %s\n" "$(basename "$entry")" "$(format_bytes $((size * 1024)))"
    done
    echo "  ─────────────────────────────────────────────────────────────"
    printf "  %-55s %s\n" "Total" "$(format_bytes $((total * 1024)))"
}

clean_xcode_templates() {
    print_section "Cleaning Xcode File & Project Templates"

    local total_size=0

    local user_templates="$HOME/Library/Developer/Xcode/Templates"
    if [ -d "$user_templates" ]; then
        local size
        size=$(get_folder_size "$user_templates")
        size=${size:-0}
        if [ "$size" -gt 0 ]; then
            print_info "User Xcode templates: $(format_bytes $((size * 1024)))"
            _print_dir_table "$user_templates"
            echo ""
            echo -n "Remove user Xcode templates? (y/N): "
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                rm -rf "$user_templates"/* 2>/dev/null && \
                    print_success "User templates removed: $(format_bytes $((size * 1024)))"
                total_size=$((total_size + size))
            fi
        fi
    fi

    local template_cache="$HOME/Library/Caches/com.apple.dt.Xcode"
    if [ -d "$template_cache" ]; then
        local size
        size=$(get_folder_size "$template_cache")
        size=${size:-0}
        if [ "$size" -gt 0 ]; then
            rm -rf "$template_cache" 2>/dev/null && \
                print_success "Xcode template cache: $(format_bytes $((size * 1024)))"
            total_size=$((total_size + size))
        fi
    fi

    if [ "$total_size" -gt 0 ]; then
        TOTAL_CLEANED=$((TOTAL_CLEANED + total_size))
        print_success "Total Xcode templates cleaned: $(format_bytes $((total_size * 1024)))"
    else
        print_info "No Xcode templates to clean"
    fi

    log_action "Xcode templates cleaned"
}

clean_assets_v2() {
    print_section "Cleaning System AssetsV2 Cache"

    local assets_root
    assets_root=$(_assets_root)

    if [ ! -d "$assets_root" ]; then
        print_info "AssetsV2 directory not found"
        log_action "AssetsV2: not found"
        return
    fi

    local total_root_size
    total_root_size=$(get_folder_size "$assets_root")
    total_root_size=${total_root_size:-0}
    print_info "AssetsV2 total: $(format_bytes $((total_root_size * 1024)))"
    echo ""


    local safe_cache_dirs=(
        "$assets_root/com_apple_MobileAsset_OSEligibility"
        "$assets_root/com_apple_MobileAsset_SoftwareUpdateDocumentation"
    )

    local total_size=0

    for cache_dir in "${safe_cache_dirs[@]}"; do
        if [ -d "$cache_dir" ]; then
            local size
            size=$(get_folder_size "$cache_dir")
            size=${size:-0}
            if [ "$size" -gt 0 ]; then
                local name
                name=$(basename "$cache_dir")
                print_info "$name: $(format_bytes $((size * 1024)))"
                sudo rm -rf "$cache_dir" 2>/dev/null && \
                    print_success "Removed: $name"
                total_size=$((total_size + size))
            fi
        fi
    done

    local templates_dir="$assets_root/com_apple_MobileAsset_MacFamilyTemplates"
    if [ ! -d "$templates_dir" ]; then
        templates_dir=$(find "$assets_root" -maxdepth 1 -type d -name "*Template*" 2>/dev/null | head -1)
    fi

    if [ -d "$templates_dir" ]; then
        local size
        size=$(get_folder_size "$templates_dir")
        size=${size:-0}
        print_info "iWork/App Templates (re-download from iCloud on demand):"
        _print_dir_table "$templates_dir"
        echo ""
        print_warning "These templates re-download automatically when Pages/Numbers/Keynote needs them."
        echo -n "Remove iWork templates? (y/N): "
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            sudo rm -rf "$templates_dir" 2>/dev/null && \
                print_success "iWork templates removed: $(format_bytes $((size * 1024)))"
            total_size=$((total_size + size))
        fi
    fi

    print_info ""
    print_info "Scanning for large asset bundles (>100 MB):"
    local found_large=0
    for asset_dir in "$assets_root"/*/; do
        [ -d "$asset_dir" ] || continue
        local size
        size=$(get_folder_size "$asset_dir")
        size=${size:-0}
        if [ "$size" -gt 102400 ]; then
            printf "  • %-60s %s\n" "$(basename "$asset_dir")" "$(format_bytes $((size * 1024)))"
            found_large=$((found_large + 1))
        fi
    done

    if [ "$found_large" -eq 0 ]; then
        print_info "No other large asset bundles found"
    else
        print_warning "Review the above manually — removing unknown asset bundles"
        print_warning "can break OS features (Siri voices, wallpapers, fonts, etc.)"
    fi

    if [ "$total_size" -gt 0 ]; then
        print_success "Total AssetsV2 cleaned: $(format_bytes $((total_size * 1024)))"
        TOTAL_CLEANED=$((TOTAL_CLEANED + total_size))
    else
        print_info "Nothing cleaned in AssetsV2"
    fi

    log_action "AssetsV2 cleaned: $(format_bytes $((total_size * 1024)))"
}

clean_icloud_cache() {
    print_section "Cleaning iCloud Drive Cache"

    local icloud_cache="$HOME/Library/Caches/CloudKit"
    local total_size=0

    if [ -d "$icloud_cache" ]; then
        local size
        size=$(get_folder_size "$icloud_cache")
        size=${size:-0}
        if [ "$size" -gt 0 ]; then
            print_info "CloudKit cache: $(format_bytes $((size * 1024)))"
            rm -rf "$icloud_cache"/* 2>/dev/null && \
                print_success "CloudKit cache removed"
            total_size=$((total_size + size))
        fi
    fi

    local icloud_docs="$HOME/Library/Mobile Documents"
    if [ -d "$icloud_docs" ]; then
        local size
        size=$(get_folder_size "$icloud_docs")
        size=${size:-0}
        print_info "iCloud Documents local cache: $(format_bytes $((size * 1024)))"
        print_warning "Use 'Optimize Mac Storage' in System Settings > Apple ID instead of manual removal"
    fi

    if [ "$total_size" -gt 0 ]; then
        TOTAL_CLEANED=$((TOTAL_CLEANED + total_size))
    else
        print_info "iCloud cache already clean"
    fi

    log_action "iCloud cache cleaned"
}

clean_spotlight_index() {
    print_section "Rebuilding Spotlight Index"

    local data_volume="/System/Volumes/Data"

    print_info "Current indexing status:"
    mdutil -s "$data_volume" 2>&1 | sed 's/^/  /'
    echo ""

    print_warning "This removes and rebuilds the Spotlight index (~1-2 GB temporarily)."
    print_warning "Search will be unavailable for a few minutes while it rebuilds."
    echo -n "Rebuild Spotlight index? (y/N): "
    read -r response

    if [[ "$response" =~ ^[Yy]$ ]]; then
        local output
        output=$(sudo mdutil -E "$data_volume" 2>&1)
        local status=$?

        echo "$output" | sed 's/^/  /'

        if [ $status -eq 0 ] && ! echo "$output" | grep -qi "error"; then
            print_success "Spotlight index queued for rebuild on $data_volume"
        else
            print_warning "Failed — check the output above (often SIP/permissions related)"
        fi
    else
        print_info "Skipped"
    fi

    log_action "Spotlight index rebuild requested"
}

# ── entrypoint ─────────────────────────────

clean_system_assets() {
    clean_xcode_templates
    clean_assets_v2
    clean_icloud_cache
    clean_spotlight_index
}
