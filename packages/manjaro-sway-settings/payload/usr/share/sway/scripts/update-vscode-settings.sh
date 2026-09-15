#!/usr/bin/env sh

# Combined script to update VS Code settings (font and theme) atomically
# to prevent race conditions when switching themes.
# Only updates values that are currently managed (i.e. one of the known
# sway-managed values), allowing user overrides to persist.

# Handle arguments
FONT_FAMILY=${1:-"JetBrainsMono NF"}
shift

# Capture all remaining arguments as the theme name, handling potential spaces
# Strip leading/trailing quotes that might be passed by Sway variables
VSCODE_THEME=$(echo "$*" | sed 's/^"//;s/"$//')
[ -z "$VSCODE_THEME" ] && VSCODE_THEME="Default Dark+"

# Strip size if present (e.g., "JetBrainsMono NF 11" -> "JetBrainsMono NF")
FONT_NAME=$(echo "$FONT_FAMILY" | sed 's/ [0-9.]*$//')

# Known managed themes and fonts — only update if current value is one of these
MANAGED_THEMES="Noctis|Noctis Azureus|Noctis Hibernus|Noctis Lux|Noctis Obscuro|Noctis Sereno|Noctis Uva|Noctis Viola"
MANAGED_FONTS="JetBrainsMono NF|Terminess Nerd Font Mono"

for variant in "Code" "Code - OSS" "Code - Insiders" "Antigravity"; do
    base_dir="$HOME/.config/$variant"
    if [ -d "$base_dir" ]; then

        for file in "$base_dir/settings.json" "$base_dir/User/settings.json"; do

            if [ "$file" = "$base_dir/User/settings.json" ]; then
                mkdir -p "$base_dir/User"
                if [ ! -f "$file" ]; then
                    echo "{}" > "$file"
                fi
            fi

            if [ -f "$file" ]; then
                # Only update theme if current value is a managed theme
                current_theme=$(jq -r '.["workbench.colorTheme"] // empty' "$file" 2>/dev/null)
                if echo "$current_theme" | grep -qE "^($MANAGED_THEMES)$"; then
                    tmp=$(mktemp)
                    jq --arg theme "$VSCODE_THEME" '.["workbench.colorTheme"] = $theme' "$file" > "$tmp" && mv "$tmp" "$file"
                fi

                # Only update font if current value is a managed font
                current_font=$(jq -r '.["editor.fontFamily"] // empty' "$file" 2>/dev/null | sed 's/,.*//' | sed "s/'//g" | xargs)
                if echo "$current_font" | grep -qE "^($MANAGED_FONTS)$"; then
                    tmp=$(mktemp)
                    jq --arg font "$FONT_NAME" \
                       '.["editor.fontFamily"] = ($font + (if .["editor.fontFamily"] then .["editor.fontFamily"] | sub("^[^,]+"; "") else ", '\''Terminess Nerd Font Mono'\'', '\''Droid Sans Mono'\'', monospace, '\''Droid Sans Fallback'\''" end)) |
                        .["terminal.integrated.fontFamily"] = ($font + (if .["terminal.integrated.fontFamily"] then .["terminal.integrated.fontFamily"] | sub("^[^,]+"; "") else ", '\''Terminess Nerd Font Mono'\'', monospace" end))' \
                       "$file" > "$tmp" && mv "$tmp" "$file"
                fi
            fi
        done
    fi
done
