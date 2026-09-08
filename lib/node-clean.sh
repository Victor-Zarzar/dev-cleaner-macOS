#!/bin/bash

# ============================================
# Node.js Ecosystem Cleaning Functions
# ============================================

clean_nvm_npm() {
    print_section "Cleaning NPM/NVM Cache"

    if [ -d "$HOME/.nvm" ]; then
        print_info "NVM found"
    else
        print_info "NVM not found (npm cache will still be checked)"
    fi

    local npm_cache="$HOME/.npm"
    if [ -d "$npm_cache" ]; then
        local size
        size=$(get_folder_size "$npm_cache")
        size=${size:-0}
        if [ "$size" -gt 0 ]; then
            rm -rf "$npm_cache" 2>/dev/null && \
                print_success "npm cache: $(format_bytes $((size * 1024)))"
            TOTAL_CLEANED=$((TOTAL_CLEANED + size))
        else
            print_info "npm cache already clean"
        fi
    else
        print_info "npm cache folder not found"
    fi

    if command -v npm &>/dev/null; then
        npm cache clean --force &>/dev/null && print_success "npm cache verified/cleaned via CLI"
        npm cache verify &>/dev/null
    else
        print_info "npm CLI not found"
    fi

    log_action "NPM/NVM cleaned"
}

clean_pnpm() {
    print_section "Cleaning PNPM Cache"

    if command -v pnpm &>/dev/null; then
        local paths=(
            "$HOME/.pnpm-store"
            "$HOME/Library/pnpm/store"
            "$HOME/.local/share/pnpm/store"
        )
        local total_size=0
        for path in "${paths[@]}"; do
            if [ -d "$path" ]; then
                local size
                size=$(get_folder_size "$path")
                size=${size:-0}
                total_size=$((total_size + size))
            fi
        done

        pnpm store prune &>/dev/null && \
            print_success "pnpm store cleaned: $(format_bytes $((total_size * 1024)))"
        TOTAL_CLEANED=$((TOTAL_CLEANED + total_size))
    else
        print_info "PNPM not found"
    fi

    log_action "PNPM cleaned"
}

clean_bun() {
    print_section "Cleaning Bun Cache"

    if command -v bun &>/dev/null; then
        local bun_version=$(bun --version 2>/dev/null)
        print_info "Bun version: $bun_version"

        local total_size=0

        local bun_cache_dir="$HOME/.bun/install/cache"
        if [ -d "$bun_cache_dir" ]; then
            local size
            size=$(get_folder_size "$bun_cache_dir")
            size=${size:-0}
            if [ "$size" -gt 0 ]; then
                rm -rf "$bun_cache_dir"/* 2>/dev/null && \
                    print_success "Bun install cache: $(format_bytes $((size * 1024)))"
                total_size=$((total_size + size))
            fi
        fi

        if [ -d "$HOME/.bun/install" ]; then
            find "$HOME/.bun/install" -name ".tmp-*" -type d -exec rm -rf {} + 2>/dev/null && \
                print_success "Bun temporary files removed"
        fi

        local bun_logs="$HOME/.bun/logs"
        if [ -d "$bun_logs" ]; then
            local size
            size=$(get_folder_size "$bun_logs")
            size=${size:-0}
            if [ "$size" -gt 0 ]; then
                rm -rf "$bun_logs"/* 2>/dev/null && \
                    print_success "Bun logs: $(format_bytes $((size * 1024)))"
                total_size=$((total_size + size))
            fi
        fi

        if [ "$total_size" -gt 0 ]; then
            print_success "Total Bun cleaned: $(format_bytes $((total_size * 1024)))"
            TOTAL_CLEANED=$((TOTAL_CLEANED + total_size))
        else
            print_info "Bun cache is already clean"
        fi
    else
        print_info "Bun not found"
    fi

    log_action "Bun cache cleaned"
}

clean_yarn() {
    print_section "Cleaning Yarn Cache"

    if command -v yarn &>/dev/null; then
        local yarn_version=$(yarn --version 2>/dev/null)
        print_info "Yarn version: $yarn_version"
        local total_size=0

        local yarn1_cache="$HOME/.cache/yarn"
        if [ -d "$yarn1_cache" ]; then
            local size
            size=$(get_folder_size "$yarn1_cache")
            size=${size:-0}
            if [ "$size" -gt 0 ]; then
                yarn cache clean &>/dev/null
                print_success "Yarn classic cache: $(format_bytes $((size * 1024)))"
                total_size=$((total_size + size))
            fi
        fi

        local yarn_berry_cache="$HOME/.yarn/berry/cache"
        if [ -d "$yarn_berry_cache" ]; then
            local size
            size=$(get_folder_size "$yarn_berry_cache")
            size=${size:-0}
            if [ "$size" -gt 0 ]; then
                rm -rf "$yarn_berry_cache"/* 2>/dev/null && \
                    print_success "Yarn Berry cache: $(format_bytes $((size * 1024)))"
                total_size=$((total_size + size))
            fi
        fi

        local yarn_unplugged="$HOME/.yarn/berry/unplugged"
        if [ -d "$yarn_unplugged" ]; then
            local size
            size=$(get_folder_size "$yarn_unplugged")
            size=${size:-0}
            if [ "$size" -gt 0 ]; then
                print_warning "Yarn Berry unplugged found: $(format_bytes $((size * 1024))) — skipping (project-specific)"
            fi
        fi

        if [ "$total_size" -gt 0 ]; then
            print_success "Total Yarn cleaned: $(format_bytes $((total_size * 1024)))"
            TOTAL_CLEANED=$((TOTAL_CLEANED + total_size))
        else
            print_info "Yarn cache already clean"
        fi
    else
        print_info "Yarn not found"
    fi

    log_action "Yarn cache cleaned"
}

clean_node_modules() {
    print_section "Cleaning Orphan node_modules"

    local search_path="${1:-$HOME/Projects}"

    if [ ! -d "$search_path" ]; then
        print_info "Projects folder not found ($search_path)"
        log_action "node_modules scan skipped — folder not found"
        return
    fi

    print_info "Scanning $search_path for node_modules older than 30 days..."

    local total_size=0
    local count=0
    local dirs=()

    while IFS= read -r nm_dir; do
        local parent_dir
        parent_dir=$(dirname "$nm_dir")
        local last_modified
        last_modified=$(find "$parent_dir" -maxdepth 1 -name "package.json" -newer "$nm_dir" 2>/dev/null | wc -l)

        if [ "$last_modified" -eq 0 ]; then
            local size
            size=$(get_folder_size "$nm_dir")
            size=${size:-0}
            dirs+=("$nm_dir|$size")
            total_size=$((total_size + size))
            ((count++))
        fi
    done < <(find "$search_path" -maxdepth 5 -type d -name "node_modules" \
        -not -path "*/node_modules/*/node_modules" \
        -mtime +30 2>/dev/null)

    if [ "$count" -eq 0 ]; then
        print_info "No orphan node_modules found"
        log_action "No orphan node_modules found"
        return
    fi

    echo ""
    print_warning "Found $count node_modules folder(s) — $(format_bytes $((total_size * 1024))) total:"
    for entry in "${dirs[@]}"; do
        local dir="${entry%|*}"
        local size="${entry##*|}"
        echo "  • $(dirname "$dir") ($(format_bytes $((size * 1024))))"
    done
    echo ""
    echo -n "Remove all? (y/N): "
    read -r response

    if [[ "$response" =~ ^[Yy]$ ]]; then
        for entry in "${dirs[@]}"; do
            local dir="${entry%|*}"
            rm -rf "$dir" 2>/dev/null
        done
        print_success "Removed $count node_modules: $(format_bytes $((total_size * 1024)))"
        TOTAL_CLEANED=$((TOTAL_CLEANED + total_size))
    else
        print_info "Skipped"
    fi

    log_action "Orphan node_modules cleaned — $count dirs, $(format_bytes $((total_size * 1024)))"
}

# ── entrypoint ─────────────────────────────

clean_system_nodejs() {
    clean_nvm_npm
    clean_pnpm
    clean_bun
    clean_yarn
    clean_node_modules
}
