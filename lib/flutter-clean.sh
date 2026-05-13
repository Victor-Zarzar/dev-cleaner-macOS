#!/bin/bash

# ============================================
# Flutter/Dart Cleaning Functions
# ============================================

clean_flutter_dart() {
    print_section "Cleaning Flutter/Dart/FVM Cache"

    local total_size=0

    local paths=(
        "$HOME/.flutter-devtools"
        "$HOME/.dartServer"
        "$HOME/.dart-tool"
        "$HOME/.pub-cache/_temp"
        "$HOME/.pub-cache/git/cache"
        "$HOME/.pub-cache/hosted/pub.dev/.cache"
    )

    for path in "${paths[@]}"; do
        if [ -e "$path" ]; then
            local size
            size=$(get_folder_size "$path")
            size=${size:-0}

            rm -rf "$path" 2>/dev/null && \
                print_success "$(basename "$path"): $(format_bytes $((size * 1024)))"

            total_size=$((total_size + size))
        fi
    done

    if [ -d "$HOME/.pub-cache" ]; then
        local pub_size
        pub_size=$(get_folder_size "$HOME/.pub-cache")
        pub_size=${pub_size:-0}

        print_info "Pub cache usage: $(format_bytes $((pub_size * 1024)))"
        print_info "Use full pub cache clean only if you want to redownload packages later."
    fi

    if command -v flutter &> /dev/null; then
        print_info "Cleaning Flutter tool cache..."

        flutter precache --clear-ios &>/dev/null
        flutter precache --clear-macos &>/dev/null
        flutter precache --clear-android &>/dev/null

        print_info "Flutter cache cleared. It will be rebuilt when needed."
    fi

    if [ -d "$HOME/Projects" ]; then
        print_info "Scanning Flutter project caches..."

        local project_cache_size=0

        while IFS= read -r dir; do
            local size
            size=$(get_folder_size "$dir")
            size=${size:-0}
            project_cache_size=$((project_cache_size + size))
        done < <(find "$HOME/Projects" -type d \( \
            -name "build" -o \
            -name ".dart_tool" -o \
            -name ".fvm" \
        \) 2>/dev/null)

        if [ "$project_cache_size" -gt 0 ]; then
            print_warning "Found Flutter project cache: $(format_bytes $((project_cache_size * 1024)))"
            echo -n "Remove Flutter project build/.dart_tool/.fvm folders? (y/N): "
            read -r response

            if [[ "$response" =~ ^[Yy]$ ]]; then
                find "$HOME/Projects" -type d \( \
                    -name "build" -o \
                    -name ".dart_tool" -o \
                    -name ".fvm" \
                \) -prune -exec rm -rf {} + 2>/dev/null

                print_success "Flutter project caches removed: $(format_bytes $((project_cache_size * 1024)))"
                total_size=$((total_size + project_cache_size))
            else
                print_info "Flutter project caches kept"
            fi
        fi

        print_info "Scanning Flutter generated files..."

        local generated_files_size=0

        while IFS= read -r file; do
            local size
            size=$(du -sk "$file" 2>/dev/null | awk '{print $1}')
            size=${size:-0}
            generated_files_size=$((generated_files_size + size))
        done < <(find "$HOME/Projects" -type f \( \
            -name ".flutter-plugins" -o \
            -name ".flutter-plugins-dependencies" -o \
            -name ".packages" \
        \) 2>/dev/null)

        if [ "$generated_files_size" -gt 0 ]; then
            find "$HOME/Projects" -type f \( \
                -name ".flutter-plugins" -o \
                -name ".flutter-plugins-dependencies" -o \
                -name ".packages" \
            \) -delete 2>/dev/null

            print_success "Flutter generated files removed: $(format_bytes $((generated_files_size * 1024)))"
            total_size=$((total_size + generated_files_size))
        fi
    fi

    if command -v fvm &> /dev/null; then
        print_info "FVM found"

        local fvm_paths=(
            "$HOME/fvm/versions"
            "$HOME/.fvm/versions"
        )

        for fvm_versions_path in "${fvm_paths[@]}"; do
            if [ -d "$fvm_versions_path" ]; then
                local fvm_total_size
                fvm_total_size=$(get_folder_size "$fvm_versions_path")
                fvm_total_size=${fvm_total_size:-0}

                if [ "$fvm_total_size" -gt 0 ]; then
                    print_info "FVM SDK versions path: $fvm_versions_path"
                    print_info "FVM SDK versions usage: $(format_bytes $((fvm_total_size * 1024)))"

                    du -sh "$fvm_versions_path"/* 2>/dev/null

                    echo -n "Keep only the newest FVM SDK version in this path? (y/N): "
                    read -r response

                    if [[ "$response" =~ ^[Yy]$ ]]; then
                        local before_size
                        before_size=$(get_folder_size "$fvm_versions_path")
                        before_size=${before_size:-0}

                        (
                            cd "$fvm_versions_path" 2>/dev/null || exit 0
                            ls -td */ 2>/dev/null | tail -n +2 | xargs rm -rf 2>/dev/null
                        )

                        local after_size
                        after_size=$(get_folder_size "$fvm_versions_path")
                        after_size=${after_size:-0}

                        local cleaned=$((before_size - after_size))

                        if [ "$cleaned" -gt 0 ]; then
                            print_success "Old FVM SDK versions removed: $(format_bytes $((cleaned * 1024)))"
                            total_size=$((total_size + cleaned))
                        else
                            print_info "No old FVM SDK versions removed"
                        fi
                    else
                        print_info "FVM SDK versions kept"
                    fi
                fi
            fi
        done
    else
        print_info "FVM not found"
    fi

    if command -v dart &> /dev/null; then
        print_info "Dart found"
        print_info "Tip: use 'dart pub cache repair' only when the pub cache is broken."
    fi

    if [ "$total_size" -gt 0 ]; then
        print_success "Total Flutter/Dart/FVM cleaned: $(format_bytes $((total_size * 1024)))"
        TOTAL_CLEANED=$((TOTAL_CLEANED + total_size))
    else
        print_info "No Flutter/Dart/FVM cache found"
    fi

    log_action "Flutter/Dart/FVM cleaned"
}
