#!/usr/bin/env sh

# Combined script to update VS Code settings (font and theme) atomically
# to prevent race conditions when switching themes.

# Handle arguments
FONT_FAMILY=${1:-"JetBrainsMono NF"}
shift

# Capture all remaining arguments as the theme name, handling potential spaces
# Strip leading/trailing quotes that might be passed by Sway variables
VSCODE_THEME=$(echo "$*" | sed 's/^"//;s/"$//')
[ -z "$VSCODE_THEME" ] && VSCODE_THEME="Default Dark+"

# Strip size if present (e.g., "JetBrainsMono NF 11" -> "JetBrainsMono NF")
FONT_NAME=$(echo "$FONT_FAMILY" | sed 's/ [0-9.]*$//')

for variant in "Code" "Code - OSS" "Code - Insiders"; do
    base_dir="$HOME/.config/$variant"
    if [ -d "$base_dir" ]; then
        
        # Define the files to update
        # 1. Legacy root file
        # 2. Modern User file
        for file in "$base_dir/settings.json" "$base_dir/User/settings.json"; do
            
            # If it's the User file, ensure directory and file exist
            if [ "$file" = "$base_dir/User/settings.json" ]; then
                mkdir -p "$base_dir/User"
                if [ ! -f "$file" ]; then
                    echo "{}" > "$file"
                fi
            fi

            if [ -f "$file" ]; then
                # Use sed for theme to preserve comments
                sed -i "s/\"workbench.colorTheme\": \".*\"/\"workbench.colorTheme\": \"$VSCODE_THEME\"/" "$file"
                
                # For fonts, we still use jq because prepending to a list safely is hard with sed.
                # If comments exist, they will be lost for this file.
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
