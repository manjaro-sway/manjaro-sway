#!/usr/bin/env sh

# Script to update Zed Editor settings (font and theme)
# Handles JSONC by using targeted sed replacements to preserve comments.

# Handle arguments
FONT_FAMILY=${1:-"JetBrainsMono NF"}
shift

# Capture all remaining arguments as the theme name, handling potential spaces
# Strip leading/trailing quotes that might be passed by Sway variables
VSCODE_THEME=$(echo "$*" | sed 's/^"//;s/"$//')
[ -z "$VSCODE_THEME" ] && VSCODE_THEME="Noctis Azureus"

# Strip size if present (e.g., "JetBrainsMono NF 11" -> "JetBrainsMono NF")
FONT_NAME=$(echo "$FONT_FAMILY" | sed 's/ [0-9.]*$//')

ZED_SETTINGS="$HOME/.config/zed/settings.json"

if [ -d "$(dirname "$ZED_SETTINGS")" ]; then
    if [ ! -f "$ZED_SETTINGS" ]; then
        mkdir -p "$(dirname "$ZED_SETTINGS")"
        cat <<EOF > "$ZED_SETTINGS"
{
  "theme": {
    "mode": "dark",
    "light": "One Light",
    "dark": "Noctis Azureus"
  },
  "buffer_font_family": "JetBrainsMono NF"
}
EOF
    fi

    # Update theme (dark mode) - using more specific match for the theme object
    if grep -q '"dark":' "$ZED_SETTINGS"; then
        sed -i "s/\"dark\": \".*\"/\"dark\": \"$VSCODE_THEME\"/" "$ZED_SETTINGS"
    elif grep -q '"theme":' "$ZED_SETTINGS"; then
        # If theme object exists but dark key is missing
        sed -i '/"theme": {/a \    "dark": "'"$VSCODE_THEME"'",' "$ZED_SETTINGS"
    else
        # If theme object is missing entirely, add it at the top of the root object
        sed -i '0,/^[[:space:]]*{/s/^[[:space:]]*{/{\n  "theme": {\n    "mode": "dark",\n    "dark": "'"$VSCODE_THEME"'"\n  },/' "$ZED_SETTINGS"
    fi

    # Update font family - use anchor to match only at the root level if possible
    if grep -q '"buffer_font_family":' "$ZED_SETTINGS"; then
        sed -i "s/\"buffer_font_family\": \".*\"/\"buffer_font_family\": \"$FONT_NAME\"/" "$ZED_SETTINGS"
    else
        # Add font family at the top of the root object, ensuring we only match the first brace at start of line
        sed -i '0,/^[[:space:]]*{/s/^[[:space:]]*{/{\n  "buffer_font_family": "'"$FONT_NAME"'",/' "$ZED_SETTINGS"
    fi
fi
