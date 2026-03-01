#!/usr/bin/env sh

# Script to update Zed Editor settings (font and theme)
# Uses sed to preserve comments in JSONC files.

# Handle arguments
FONT_FAMILY=${1:-"JetBrainsMono NF"}
shift

# Capture all remaining arguments as the theme name, handling potential spaces
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

    # Update theme and font while preserving comments
    sed -i "s/\"dark\": \".*\"/\"dark\": \"$VSCODE_THEME\"/" "$ZED_SETTINGS"
    sed -i "s/\"buffer_font_family\": \".*\"/\"buffer_font_family\": \"$FONT_NAME\"/" "$ZED_SETTINGS"
fi
