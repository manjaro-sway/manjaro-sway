#!/usr/bin/env sh

# Script to update Zed Editor settings (font and theme)
# Only updates values that are currently managed (i.e. one of the known
# sway-managed values), allowing user overrides to persist.

# Handle arguments
FONT_FAMILY=${1:-"JetBrainsMono NF"}
shift

# Capture all remaining arguments as the theme name, handling potential spaces
VSCODE_THEME=$(echo "$*" | sed 's/^"//;s/"$//')
[ -z "$VSCODE_THEME" ] && VSCODE_THEME="Noctis Azureus"

# Strip size if present (e.g., "JetBrainsMono NF 11" -> "JetBrainsMono NF")
FONT_NAME=$(echo "$FONT_FAMILY" | sed 's/ [0-9.]*$//')

# Known managed themes and fonts — only update if current value is one of these
MANAGED_THEMES="Noctis|Noctis Azureus|Noctis Hibernus|Noctis Lux|Noctis Obscuro|Noctis Sereno|Noctis Uva|Noctis Viola"
MANAGED_FONTS="JetBrainsMono NF|Terminess Nerd Font Mono"

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

    # Only update theme if current value is a managed theme
    current_theme=$(jq -r '.theme.dark // empty' "$ZED_SETTINGS" 2>/dev/null)
    if echo "$current_theme" | grep -qE "^($MANAGED_THEMES)$"; then
        tmp=$(mktemp)
        jq --arg theme "$VSCODE_THEME" '.theme.dark = $theme' "$ZED_SETTINGS" > "$tmp" && mv "$tmp" "$ZED_SETTINGS"
    fi

    # Only update font if current value is a managed font
    current_font=$(jq -r '.buffer_font_family // empty' "$ZED_SETTINGS" 2>/dev/null)
    if echo "$current_font" | grep -qE "^($MANAGED_FONTS)$"; then
        tmp=$(mktemp)
        jq --arg font "$FONT_NAME" '.buffer_font_family = $font' "$ZED_SETTINGS" > "$tmp" && mv "$tmp" "$ZED_SETTINGS"
    fi
fi
