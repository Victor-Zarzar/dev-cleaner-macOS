#!/bin/bash

# ============================================
# Android Studio & Gradle Cleaning Functions
# ============================================

clean_android_studio() {
    print_section "Cleaning Android Studio & Emulator"

    local total_size=0
    local items_cleaned=0

    # ─────────────────────────────────────────
    # Android Emulator / AVD cache
    # ─────────────────────────────────────────
    if [ -d "$HOME/.android/avd" ]; then
        for avd_dir in "$HOME/.android/avd"/*.avd; do
            [ -d "$avd_dir" ] || continue

            local avd_name
            avd_name=$(basename "$avd_dir")

            local avd_cache_paths=(
                "$avd_dir/cache"
                "$avd_dir/tmp"
            )

            for path in "${avd_cache_paths[@]}"; do
                if [ -d "$path" ]; then
                    local size
                    size=$(get_folder_size "$path")
                    size=${size:-0}

                    if [ "$size" -gt 0 ]; then
                        rm -rf "$path"/* 2>/dev/null && \
                            print_success "AVD $(basename "$path") ($avd_name): $(format_bytes $((size * 1024)))"

                        total_size=$((total_size + size))
                        items_cleaned=$((items_cleaned + 1))
                    fi
                fi
            done
        done

        find "$HOME/.android/avd" -name "*.lock" -delete 2>/dev/null && \
            print_success "AVD stale locks removed"

        local snapshot_size=0
        while IFS= read -r snapshot_dir; do
            local size
            size=$(get_folder_size "$snapshot_dir")
            size=${size:-0}
            snapshot_size=$((snapshot_size + size))
        done < <(find "$HOME/.android/avd" -type d -name "snapshots" 2>/dev/null)

        if [ "$snapshot_size" -gt 0 ]; then
            print_warning "AVD snapshots found: $(format_bytes $((snapshot_size * 1024)))"
            echo -n "Remove Android Emulator snapshots? Saved emulator states will be lost. (y/N): "
            read -r response

            if [[ "$response" =~ ^[Yy]$ ]]; then
                find "$HOME/.android/avd" -type d -name "snapshots" -prune -exec rm -rf {} + 2>/dev/null
                print_success "AVD snapshots removed: $(format_bytes $((snapshot_size * 1024)))"

                total_size=$((total_size + snapshot_size))
                items_cleaned=$((items_cleaned + 1))
            else
                print_info "AVD snapshots kept"
            fi
        fi
    fi

    # ─────────────────────────────────────────
    # Android / Gradle / Kotlin user caches
    # ─────────────────────────────────────────
    local cache_dirs=(
        "$HOME/.android/cache"
        "$HOME/.android/build-cache"

        "$HOME/.gradle/build-cache"
        "$HOME/.gradle/kotlin"
        "$HOME/.gradle/native"
        "$HOME/.gradle/notifications"
        "$HOME/.gradle/jdks"
        "$HOME/.gradle/configuration-cache"
    )

    for path in "${cache_dirs[@]}"; do
        if [ -d "$path" ]; then
            local size
            size=$(get_folder_size "$path")
            size=${size:-0}

            if [ "$size" -gt 0 ]; then
                rm -rf "$path"/* 2>/dev/null && \
                    print_success "$(basename "$path"): $(format_bytes $((size * 1024)))"

                total_size=$((total_size + size))
                items_cleaned=$((items_cleaned + 1))
            fi
        fi
    done

    # ─────────────────────────────────────────
    # Android Studio app caches
    # ─────────────────────────────────────────
    local studio_patterns=(
        "$HOME/Library/Caches/AndroidStudio"*
        "$HOME/Library/Caches/Google/AndroidStudio"*
        "$HOME/Library/Application Support/Google/AndroidStudio"*/caches
        "$HOME/Library/Application Support/Google/AndroidStudio"*/compile-server
        "$HOME/Library/Application Support/Google/AndroidStudio"*/tmp
    )

    for pattern in "${studio_patterns[@]}"; do
        for path in $pattern; do
            [ -d "$path" ] || continue

            local size
            size=$(get_folder_size "$path")
            size=${size:-0}

            if [ "$size" -gt 0 ]; then
                rm -rf "$path"/* 2>/dev/null && \
                    print_success "Android Studio $(basename "$path"): $(format_bytes $((size * 1024)))"

                total_size=$((total_size + size))
                items_cleaned=$((items_cleaned + 1))
            fi
        done
    done

    for system_path in "$HOME/Library/Application Support/Google/AndroidStudio"*/system; do
        [ -d "$system_path" ] || continue

        local size
        size=$(get_folder_size "$system_path")
        size=${size:-0}

        if [ "$size" -gt 0 ]; then
            print_warning "Android Studio system cache found: $(format_bytes $((size * 1024)))"
            echo -n "Remove Android Studio system cache/indexes? It will be rebuilt. (y/N): "
            read -r response

            if [[ "$response" =~ ^[Yy]$ ]]; then
                rm -rf "$system_path"/* 2>/dev/null && \
                    print_success "Android Studio system cache removed: $(format_bytes $((size * 1024)))"

                total_size=$((total_size + size))
                items_cleaned=$((items_cleaned + 1))
            else
                print_info "Android Studio system cache kept"
            fi
        fi
    done

    # ─────────────────────────────────────────
    # Android Studio logs
    # ─────────────────────────────────────────
    for log_path in "$HOME/Library/Logs/Google/AndroidStudio"*; do
        if [ -d "$log_path" ]; then
            local size
            size=$(get_folder_size "$log_path")
            size=${size:-0}

            if [ "$size" -gt 0 ]; then
                rm -rf "$log_path"/* 2>/dev/null && \
                    print_success "Android Studio logs: $(format_bytes $((size * 1024)))"

                total_size=$((total_size + size))
                items_cleaned=$((items_cleaned + 1))
            fi
        fi
    done

    # ─────────────────────────────────────────
    # Full Gradle cache
    # ─────────────────────────────────────────
    if [ -d "$HOME/.gradle/caches" ]; then
        local gradle_size
        gradle_size=$(get_folder_size "$HOME/.gradle/caches")
        gradle_size=${gradle_size:-0}

        if [ "$gradle_size" -gt 0 ]; then
            print_info "Gradle cache found: $(format_bytes $((gradle_size * 1024)))"
            print_warning "Removing entire Gradle cache. It will be rebuilt on next build..."

            rm -rf "$HOME/.gradle/caches"/* 2>/dev/null && \
                print_success "Gradle cache removed: $(format_bytes $((gradle_size * 1024)))"

            total_size=$((total_size + gradle_size))
            items_cleaned=$((items_cleaned + 1))
        fi
    fi

    # ─────────────────────────────────────────
    # Gradle wrappers: keep latest
    # ─────────────────────────────────────────
    if [ -d "$HOME/.gradle/wrapper/dists" ]; then
        local wrapper_size
        wrapper_size=$(get_folder_size "$HOME/.gradle/wrapper")
        wrapper_size=${wrapper_size:-0}

        if [ "$wrapper_size" -gt 102400 ]; then
            print_info "Gradle wrapper found: $(format_bytes $((wrapper_size * 1024)))"
            print_warning "Keeping only latest Gradle wrapper distribution..."

            (
                cd "$HOME/.gradle/wrapper/dists" 2>/dev/null || exit 0
                ls -t | tail -n +2 | xargs rm -rf 2>/dev/null
            )

            local new_wrapper_size
            new_wrapper_size=$(get_folder_size "$HOME/.gradle/wrapper")
            new_wrapper_size=${new_wrapper_size:-0}

            local cleaned_wrapper=$((wrapper_size - new_wrapper_size))

            if [ "$cleaned_wrapper" -gt 0 ]; then
                print_success "Old Gradle wrappers removed: $(format_bytes $((cleaned_wrapper * 1024)))"
                total_size=$((total_size + cleaned_wrapper))
                items_cleaned=$((items_cleaned + 1))
            fi
        fi
    fi

    if [ -d "$HOME/.gradle/daemon" ]; then
        find "$HOME/.gradle/daemon" -name "*.log" -mtime +7 -delete 2>/dev/null && \
            print_success "Old Gradle daemon logs removed"
    fi

    # ─────────────────────────────────────────
    # Android SDK temp/cache
    # ─────────────────────────────────────────
    local android_sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"

    if [ -d "$android_sdk" ]; then
        local sdk_cache_dirs=(
            "$android_sdk/.temp"
            "$android_sdk/.downloadIntermediates"
            "$android_sdk/temp"
            "$android_sdk/patcher"
        )

        for path in "${sdk_cache_dirs[@]}"; do
            if [ -d "$path" ]; then
                local size
                size=$(get_folder_size "$path")
                size=${size:-0}

                if [ "$size" -gt 0 ]; then
                    rm -rf "$path"/* 2>/dev/null && \
                        print_success "Android SDK $(basename "$path"): $(format_bytes $((size * 1024)))"

                    total_size=$((total_size + size))
                    items_cleaned=$((items_cleaned + 1))
                fi
            fi
        done

        # Only warn about heavy SDK components
        for heavy_path in "$android_sdk/system-images" "$android_sdk/ndk" "$android_sdk/cmake"; do
            if [ -d "$heavy_path" ]; then
                local size
                size=$(get_folder_size "$heavy_path")
                size=${size:-0}

                if [ "$size" -gt 0 ]; then
                    print_info "$(basename "$heavy_path") installed: $(format_bytes $((size * 1024)))"
                fi
            fi
        done

        if command -v sdkmanager &> /dev/null; then
            print_info "Tip: use 'sdkmanager --list_installed' to inspect old Android SDK packages"
            print_info "Tip: remove old packages with 'sdkmanager --uninstall <package-name>'"
        fi
    fi

    # ─────────────────────────────────────────
    # Project Android caches
    # ─────────────────────────────────────────
    if [ -d "$HOME/Projects" ]; then
        print_info "Scanning Android project caches..."

        local project_cache_size=0

        while IFS= read -r project_cache_dir; do
            local size
            size=$(get_folder_size "$project_cache_dir")
            size=${size:-0}
            project_cache_size=$((project_cache_size + size))
        done < <(find "$HOME/Projects" -type d \( \
            -name ".gradle" -o \
            -name ".cxx" \
        \) 2>/dev/null)

        if [ "$project_cache_size" -gt 0 ]; then
            print_warning "Found Android project caches: $(format_bytes $((project_cache_size * 1024)))"
            echo -n "Remove project .gradle/.cxx folders? (y/N): "
            read -r response

            if [[ "$response" =~ ^[Yy]$ ]]; then
                find "$HOME/Projects" -type d \( \
                    -name ".gradle" -o \
                    -name ".cxx" \
                \) -prune -exec rm -rf {} + 2>/dev/null

                print_success "Android project caches removed: $(format_bytes $((project_cache_size * 1024)))"

                total_size=$((total_size + project_cache_size))
                items_cleaned=$((items_cleaned + 1))
            else
                print_info "Android project caches kept"
            fi
        fi
    fi

    if [ "$items_cleaned" -eq 0 ]; then
        print_info "No Android Studio/Emulator/Gradle cache found"
    else
        print_success "Total Android + Gradle cleaned: $(format_bytes $((total_size * 1024)))"
        TOTAL_CLEANED=$((TOTAL_CLEANED + total_size))
    fi

    log_action "Android Studio, Emulator & Gradle cleaned"
}
