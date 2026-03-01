#!/usr/bin/env sh

# Script to update Zed Editor settings (font and theme)
# Handles JSONC by using jq to update values while attempting to preserve structure.

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

    tmp=$(mktemp)
    jq --arg theme "$VSCODE_THEME" \
       --arg font "$FONT_NAME" \
       '.theme.dark = $theme | .buffer_font_family = $font' \
       "$ZED_SETTINGS" > "$tmp" && mv "$tmp" "$ZED_SETTINGS"
fi
