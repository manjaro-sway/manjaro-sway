#!/bin/sh
# make default editor Neovim
export EDITOR=nvim

# Most pure GTK3 apps use wayland by default, but some,
# like Firefox, need the backend to be explicitely selected.
export MOZ_ENABLE_WAYLAND=1
export MOZ_DBUS_REMOTE=1
export GTK_CSD=0

# qt wayland
export QT_QPA_PLATFORM="wayland"
export QT_QPA_PLATFORMTHEME=qt5ct
export QT_WAYLAND_DISABLE_WINDOWDECORATION="1"

#Java XWayland blank screens fix
export _JAVA_AWT_WM_NONREPARENTING=1

# set default shell and terminal
export SHELL=/usr/bin/zsh
export TERMINAL_COMMAND=/usr/share/sway/scripts/foot.sh

# add default location for zeit.db
export ZEIT_DB=~/.config/zeit.db

# Disable hardware cursors. This might fix issues with
# disappearing cursors
# export WLR_NO_HARDWARE_CURSORS=1

set -a
source $HOME/.config/user-dirs.dirs
set +a

if [ -n "$(ls $HOME/.config/profile.d 2>/dev/null)" ]; then
    for f in $HOME/.config/profile.d/*; do
        source $f
    done
fi
