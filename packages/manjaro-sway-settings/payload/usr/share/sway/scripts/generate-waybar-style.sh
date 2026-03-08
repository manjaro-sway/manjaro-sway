#!/usr/bin/env bash
# Generates ~/.config/waybar/colors.css from sway theme variables.
# Args: background-color text-color accent-color error-color warning-color
set -u

BACKGROUND_COLOR="$1"
TEXT_COLOR="$2"
ACCENT_COLOR="$3"
ERROR_COLOR="$4"
WARNING_COLOR="$5"

WAYBAR_USER_DIR="$HOME/.config/waybar"
mkdir -p "$WAYBAR_USER_DIR"

cat > "$WAYBAR_USER_DIR/colors.css" <<EOF
@define-color theme_base_color ${BACKGROUND_COLOR};
@define-color theme_text_color ${TEXT_COLOR};
@define-color theme_bg_color ${BACKGROUND_COLOR};
@define-color theme_selected_bg_color ${ACCENT_COLOR};
@define-color error_color ${ERROR_COLOR};
@define-color warning_color ${WARNING_COLOR};
@define-color background_color ${BACKGROUND_COLOR};
EOF

# Generate a user style.css that imports colors then the system style,
# so the @import "colors.css" resolves relative to this file's location.
cat > "$WAYBAR_USER_DIR/style.css" <<EOF
@import "colors.css";
@import "/usr/share/sway/templates/waybar/style.css";
EOF
