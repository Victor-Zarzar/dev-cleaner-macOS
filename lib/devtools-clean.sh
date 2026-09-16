#!/bin/bash

# ============================================
# Dev Tools General Cleaning Functions
# ============================================

clean_homebrew() {
    print_section "Cleaning Homebrew"

    if command -v brew &>/dev/null; then
        print_info "Running brew update..."
        brew update &>/dev/null

        print_info "Running brew upgrade..."
        brew upgrade &>/dev/null && print_success "Formulae upgraded"

        print_info "Running brew cleanup (prune all)..."
        brew cleanup --prune=all &>/dev/null && print_success "Old versions removed"

        print_info "Removing unused dependencies..."
        brew autoremove &>/dev/null && print_success "Orphan deps removed"

        # Show reclaimed space (brew reports it)
        local cache_dir
        cache_dir=$(brew --cache 2>/dev/null)
        if [ -d "$cache_dir" ]; then
            local size
            size=$(get_folder_size "$cache_dir")
            size=${size:-0}
            if [ "$size" -gt 0 ]; then
                rm -rf "$cache_dir"/* 2>/dev/null && \
                    print_success "Homebrew download cache: $(format_bytes $((size * 1024)))"
                TOTAL_CLEANED=$((TOTAL_CLEANED + size))
            fi
        fi

        print_info "Running brew doctor..."
        brew doctor &>/dev/null && print_success "Homebrew healthy" || \
            print_warning "brew doctor reported warnings (run manually to review)"
    else
        print_info "Homebrew not found"
    fi

    log_action "Homebrew cleaned"
}

clean_cocoapods() {
    print_section "Cleaning CocoaPods"

    if command -v pod &>/dev/null; then
        local total_size=0

        local pods_cache="$HOME/Library/Caches/CocoaPods"
        if [ -d "$pods_cache" ]; then
            local size
            size=$(get_folder_size "$pods_cache")
            size=${size:-0}
            if [ "$size" -gt 0 ]; then
                pod cache clean --all &>/dev/null && \
                    print_success "CocoaPods download cache: $(format_bytes $((size * 1024)))"
                total_size=$((total_size + size))
            fi
        fi

        local spec_repos="$HOME/.cocoapods/repos"
        if [ -d "$spec_repos" ]; then
            local size
            size=$(get_folder_size "$spec_repos")
            size=${size:-0}
            if [ "$size" -gt 0 ]; then
                print_info "CocoaPods spec repos: $(format_bytes $((size * 1024)))"
                echo -n "Remove spec repos? (Will be re-fetched on next 'pod install') (y/N): "
                read -r response
                if [[ "$response" =~ ^[Yy]$ ]]; then
                    rm -rf "$spec_repos"/* 2>/dev/null && \
                        print_success "Spec repos removed: $(format_bytes $((size * 1024)))"
                    total_size=$((total_size + size))
                else
                    print_info "Spec repos kept"
                fi
            fi
        fi

        if [ "$total_size" -gt 0 ]; then
            print_success "Total CocoaPods cleaned: $(format_bytes $((total_size * 1024)))"
            TOTAL_CLEANED=$((TOTAL_CLEANED + total_size))
        else
            print_info "CocoaPods cache already clean"
        fi
    else
        print_info "CocoaPods not found"
    fi

    log_action "CocoaPods cleaned"
}

clean_ruby() {
    print_section "Cleaning Ruby (rbenv / RVM / gems)"

    local total_size=0

    if command -v rbenv &>/dev/null; then
        local rbenv_root
        rbenv_root=$(rbenv root 2>/dev/null)
        if [ -d "$rbenv_root/versions" ]; then
            local versions
            versions=$(ls "$rbenv_root/versions" 2>/dev/null)
            local current
            current=$(rbenv version-name 2>/dev/null)

            print_info "Installed Ruby versions: $(echo "$versions" | tr '\n' ' ')"
            print_info "Current: $current"

            for v in $versions; do
                if [ "$v" != "$current" ]; then
                    local size
                    size=$(get_folder_size "$rbenv_root/versions/$v")
                    size=${size:-0}
                    print_warning "Old Ruby $v: $(format_bytes $((size * 1024)))"
                    echo -n "Remove Ruby $v? (y/N): "
                    read -r response
                    if [[ "$response" =~ ^[Yy]$ ]]; then
                        rbenv uninstall -f "$v" 2>/dev/null && \
                            print_success "Ruby $v removed"
                        total_size=$((total_size + size))
                    fi
                fi
            done
        fi
    fi

    if command -v rvm &>/dev/null; then
        print_info "RVM found — cleaning archives and sources..."
        rvm cleanup all &>/dev/null && print_success "RVM cleaned"
    fi

    if command -v gem &>/dev/null; then
        local gem_dir
        gem_dir=$(gem environment gemdir 2>/dev/null)
        local gem_cache="$gem_dir/cache"
        if [ -d "$gem_cache" ]; then
            local size
            size=$(get_folder_size "$gem_cache")
            size=${size:-0}
            if [ "$size" -gt 0 ]; then
                rm -rf "$gem_cache"/*.gem 2>/dev/null && \
                    print_success "Gem download cache: $(format_bytes $((size * 1024)))"
                total_size=$((total_size + size))
            fi
        fi
    fi

    if [ "$total_size" -gt 0 ]; then
        print_success "Total Ruby cleaned: $(format_bytes $((total_size * 1024)))"
        TOTAL_CLEANED=$((TOTAL_CLEANED + total_size))
    else
        print_info "Ruby environment already clean"
    fi

    log_action "Ruby (rbenv/RVM) cleaned"
}

clean_python() {
    print_section "Cleaning Python (pyenv / pip / venv)"

    local total_size=0

    local pip_cache="$HOME/.cache/pip"
    if [ -d "$pip_cache" ]; then
        local size
        size=$(get_folder_size "$pip_cache")
        size=${size:-0}
        if [ "$size" -gt 0 ]; then
            if command -v pip &>/dev/null; then
                pip cache purge &>/dev/null
            elif command -v pip3 &>/dev/null; then
                pip3 cache purge &>/dev/null
            else
                rm -rf "$pip_cache"/* 2>/dev/null
            fi
            print_success "pip download cache: $(format_bytes $((size * 1024)))"
            total_size=$((total_size + size))
        fi
    fi

    if command -v pyenv &>/dev/null; then
        local pyenv_root
        pyenv_root=$(pyenv root 2>/dev/null)
        local current
        current=$(pyenv version-name 2>/dev/null)
        local versions
        versions=$(ls "$pyenv_root/versions" 2>/dev/null)

        if [ -n "$versions" ]; then
            print_info "Installed Python versions: $(echo "$versions" | tr '\n' ' ')"
            print_info "Current: $current"
            print_info "Installed versions are kept as-is (not treated as disposable cache)."
        fi
    fi

    print_info "Scanning for __pycache__ in $HOME/Projects..."
    local pycache_size=0
    local pycache_count=0
    while IFS= read -r pycache_dir; do
        local size
        size=$(get_folder_size "$pycache_dir")
        size=${size:-0}
        pycache_size=$((pycache_size + size))
        ((pycache_count++))
    done < <(find "$HOME/Projects" -type d -name "__pycache__" 2>/dev/null)

    if [ "$pycache_count" -gt 0 ]; then
        print_info "Found $pycache_count __pycache__ dirs: $(format_bytes $((pycache_size * 1024)))"
        echo -n "Remove __pycache__ folders? (y/N): "
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            find "$HOME/Projects" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null
            print_success "__pycache__ removed: $(format_bytes $((pycache_size * 1024)))"
            total_size=$((total_size + pycache_size))
        fi
    fi

    if [ "$total_size" -gt 0 ]; then
        print_success "Total Python cleaned: $(format_bytes $((total_size * 1024)))"
        TOTAL_CLEANED=$((TOTAL_CLEANED + total_size))
    else
        print_info "Python environment already clean"
    fi

    log_action "Python (pyenv/pip) cleaned"
}

# ── entrypoint ─────────────────────────────

clean_system_devtools() {
    clean_homebrew
    clean_cocoapods
    clean_ruby
    clean_python
}
