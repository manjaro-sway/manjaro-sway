#!/usr/bin/env sh

VSCODE_THEME=${1:-"Default Dark+"}

for variant in "Code" "Code - OSS" "Code - Insiders"; do
    base_dir="$HOME/.config/$variant"
    if [ -d "$base_dir" ]; then
        # 1. Update legacy root file if it exists
        root_file="$base_dir/settings.json"
        if [ -f "$root_file" ]; then
            if command -v jq >/dev/null 2>&1; then
                tmp=$(mktemp)
                jq --arg theme "$VSCODE_THEME" '.["workbench.colorTheme"] = $theme' "$root_file" > "$tmp" && mv "$tmp" "$root_file"
            fi
        fi
        
        # 2. Update/Create modern User file
        user_dir="$base_dir/User"
        mkdir -p "$user_dir"
        user_file="$user_dir/settings.json"
        if [ ! -f "$user_file" ]; then
            echo "{}" > "$user_file"
        fi

        if command -v jq >/dev/null 2>&1; then
            tmp=$(mktemp)
            jq --arg theme "$VSCODE_THEME" '.["workbench.colorTheme"] = $theme' "$user_file" > "$tmp" && mv "$tmp" "$user_file"
        else
            # Fallback to sed if jq is not available
            if grep -q '"workbench.colorTheme"' "$user_file"; then
                sed -i "s/\"workbench.colorTheme\": \".*\"/\"workbench.colorTheme\": \"$VSCODE_THEME\"/" "$user_file"
            fi
        fi
    fi
done
