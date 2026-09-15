#!/bin/bash
set -u

CURSOR_THEME=$1

gsettings set org.gnome.desktop.interface cursor-theme "$CURSOR_THEME"
swaymsg seat "*" xcursor_theme "$CURSOR_THEME"

mkdir -p "$HOME"/.icons/default
cat <<EOF > "$HOME"/.icons/default/index.theme
[Icon Theme]
Inherits=$CURSOR_THEME
EOF

