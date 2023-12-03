#!/bin/bash
set -xu

THEME=$1

gsettings set org.gnome.desktop.interface gtk-theme $THEME

mkdir -p "$HOME"/.config/gtk-4.0

THEME_DIR="/usr/share/themes/${THEME}/gtk-4.0"

[ -d "$THEME_DIR/assets" ] && /usr/bin/cp -rf --backup "/usr/share/themes/${THEME}/gtk-4.0/assets" "$HOME"/.config/gtk-4.0/
[ -f "$THEME_DIR/gtk.css" ] && /usr/bin/cp -rf --backup "/usr/share/themes/${THEME}/gtk-4.0/gtk.css" "$HOME"/.config/gtk-4.0/

[ -f "$THEME_DIR/gtk-dark.css" ] && /usr/bin/cp -rf --backup "/usr/share/themes/${THEME}/gtk-4.0/gtk-dark.css" "$HOME"/.config/gtk-4.0/
[ ! -f "$THEME_DIR/gtk-dark.css" ] && rm -rf "$HOME"/.config/gtk-4.0/gtk-dark.css

[ -d "$THEME_DIR/icons" ] && /usr/bin/cp -rf --backup "/usr/share/themes/${THEME}/gtk-4.0/icons" "$HOME"/.config/gtk-4.0/
