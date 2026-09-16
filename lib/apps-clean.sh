#!/bin/bash

# ============================================
# App Cache Cleaning
# ============================================

safe_size() {
    local val
    val=$(get_folder_size "$1" 2>/dev/null)
    if [[ "$val" =~ ^[0-9]+$ ]]; then
        echo "$val"
    else
        echo 0
    fi
}

cleanup_app_caches() {
    print_section "App Cache Cleaning"

    local cleaned=0

    local slack_base="$HOME/Library/Application Support/Slack"
    if [ -d "$slack_base" ]; then
        local size=0
        for dir in "Cache" "Code Cache" "GPUCache" "DawnGraphiteCache" "DawnWebGPUCache" "Crashpad" "logs" "sentry"; do
            local p="$slack_base/$dir"
            if [ -d "$p" ]; then
                size=$((size + $(safe_size "$p")))
                rm -rf "$p"/* 2>/dev/null
            fi
        done
        TOTAL_CLEANED=$((TOTAL_CLEANED + size))
        cleaned=$((cleaned + 1))
        print_success "Cleaned Slack cache ($(format_bytes $((size * 1024))))"
    else
        print_warning "Slack not found. Skipping."
    fi

    local teams_path="$HOME/Library/Containers/com.microsoft.teams2/Data/Library/Caches"
    if [ -d "$HOME/Library/Containers/com.microsoft.teams2" ]; then
        local size
        size=$(safe_size "$teams_path")
        rm -rf "$teams_path"/* 2>/dev/null
        TOTAL_CLEANED=$((TOTAL_CLEANED + size))
        cleaned=$((cleaned + 1))
        print_success "Cleaned Microsoft Teams cache ($(format_bytes $((size * 1024))))"
    else
        print_warning "Microsoft Teams not found. Skipping."
    fi

    local whatsapp_path="$HOME/Library/Containers/net.whatsapp.WhatsApp/Data/Library/Caches"
    if [ -d "$HOME/Library/Containers/net.whatsapp.WhatsApp" ]; then
        local size
        size=$(safe_size "$whatsapp_path")
        rm -rf "$whatsapp_path"/* 2>/dev/null
        TOTAL_CLEANED=$((TOTAL_CLEANED + size))
        cleaned=$((cleaned + 1))
        print_success "Cleaned WhatsApp cache ($(format_bytes $((size * 1024))))"
    else
        print_warning "WhatsApp not found. Skipping."
    fi

    local telegram_path="$HOME/Library/Containers/ru.keepcoder.Telegram.TelegramShare/Data/Library/Caches"
    if [ -d "$HOME/Library/Containers/ru.keepcoder.Telegram.TelegramShare" ]; then
        local size
        size=$(safe_size "$telegram_path")
        rm -rf "$telegram_path"/* 2>/dev/null
        TOTAL_CLEANED=$((TOTAL_CLEANED + size))
        cleaned=$((cleaned + 1))
        print_success "Cleaned Telegram cache ($(format_bytes $((size * 1024))))"
    else
        print_warning "Telegram not found. Skipping."
    fi

    local discord_base="$HOME/Library/Application Support/discord"
    if [ -d "$discord_base" ]; then
        local size=0
        for dir in "Cache" "Code Cache"; do
            local p="$discord_base/$dir"
            if [ -d "$p" ]; then
                size=$((size + $(safe_size "$p")))
                rm -rf "$p"/* 2>/dev/null
            fi
        done
        TOTAL_CLEANED=$((TOTAL_CLEANED + size))
        cleaned=$((cleaned + 1))
        print_success "Cleaned Discord cache ($(format_bytes $((size * 1024))))"
    else
        print_warning "Discord not found. Skipping."
    fi

    local spotify_size=0
    local spotify_cleaned=false
    for path in \
        "$HOME/Library/Caches/com.spotify.client" \
        "$HOME/Library/Application Support/Spotify/PersistentCache"
    do
        if [ -d "$path" ]; then
            spotify_size=$((spotify_size + $(safe_size "$path")))
            rm -rf "$path"/* 2>/dev/null
            spotify_cleaned=true
        fi
    done
    if $spotify_cleaned; then
        TOTAL_CLEANED=$((TOTAL_CLEANED + spotify_size))
        cleaned=$((cleaned + 1))
        print_success "Cleaned Spotify cache ($(format_bytes $((spotify_size * 1024))))"
    else
        print_warning "Spotify not found. Skipping."
    fi

    local figma_profile="$HOME/Library/Application Support/Figma/DesktopProfile"
    if [ -d "$figma_profile" ]; then
        local size=0
        for version_dir in "$figma_profile"/*/; do
            [ -d "$version_dir" ] || continue
            for dir in "Cache" "DawnGraphiteCache" "DawnWebGPUCache" "GPUCache" "Code Cache" "Shared Dictionary/cache"; do
                local p="$version_dir/$dir"
                if [ -d "$p" ]; then
                    size=$((size + $(safe_size "$p")))
                    rm -rf "$p"/* 2>/dev/null
                fi
            done
        done
        TOTAL_CLEANED=$((TOTAL_CLEANED + size))
        cleaned=$((cleaned + 1))
        print_success "Cleaned Figma cache ($(format_bytes $((size * 1024))))"
    else
        print_warning "Figma not found. Skipping."
    fi

    local trello_path="$HOME/Library/Containers/com.atlassian.trello/Data/Library/Caches"
    if [ -d "$HOME/Library/Containers/com.atlassian.trello" ]; then
        local size
        size=$(safe_size "$trello_path")
        rm -rf "$trello_path"/* 2>/dev/null
        TOTAL_CLEANED=$((TOTAL_CLEANED + size))
        cleaned=$((cleaned + 1))
        print_success "Cleaned Trello cache ($(format_bytes $((size * 1024))))"
    else
        print_warning "Trello not found. Skipping."
    fi

    local proton_path="$HOME/Library/Containers/ch.protonvpn.mac/Data/Library/Caches"
    if [ -d "$HOME/Library/Containers/ch.protonvpn.mac" ]; then
        local size
        size=$(safe_size "$proton_path")
        rm -rf "$proton_path"/* 2>/dev/null
        TOTAL_CLEANED=$((TOTAL_CLEANED + size))
        cleaned=$((cleaned + 1))
        print_success "Cleaned ProtonVPN cache ($(format_bytes $((size * 1024))))"
    else
        print_warning "ProtonVPN not found. Skipping."
    fi

    log_action "App caches cleaned ($cleaned apps)"
}
