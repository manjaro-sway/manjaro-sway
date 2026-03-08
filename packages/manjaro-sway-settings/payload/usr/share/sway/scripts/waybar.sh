#!/usr/bin/env bash
# wrapper script for waybar with args, see https://github.com/swaywm/sway/issues/5724

USER_CONFIG_PATH=$HOME/.config/waybar/config.jsonc
USER_STYLE_PATH=$HOME/.config/waybar/style.css
TEMPLATES=/usr/share/sway/templates/waybar

pkill -U $USER -x waybar

# Seed user waybar dir with default colors/style if not yet generated
mkdir -p "$HOME/.config/waybar"
[ -f "$HOME/.config/waybar/colors.css" ] || cp -f "$TEMPLATES/colors.css" "$HOME/.config/waybar/colors.css"
[ -f "$USER_STYLE_PATH" ] || cp -f "$TEMPLATES/style.css" "$USER_STYLE_PATH"

if [ -f "$USER_CONFIG_PATH" ]; then
    USER_CONFIG=$USER_CONFIG_PATH
fi

if [ -f "$USER_STYLE_PATH" ]; then
    USER_STYLE=$USER_STYLE_PATH
fi

waybar -c "${USER_CONFIG:-"$TEMPLATES/config.jsonc"}" -s "${USER_STYLE:-"$TEMPLATES/style.css"}"
