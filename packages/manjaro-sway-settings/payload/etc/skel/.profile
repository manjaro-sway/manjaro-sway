#!/bin/sh
export XDG_CONFIG_HOME=$HOME/.config

# make default editor Helix
export EDITOR=helix

# Most pure GTK3 apps use wayland by default, but some,
# such as Firefox, require the backend to be explicitly selected.
export MOZ_ENABLE_WAYLAND=1
export MOZ_DBUS_REMOTE=1
export GTK_CSD=0

# qt wayland
export QT_QPA_PLATFORM="wayland"
# Route Qt file dialogs through xdg-desktop-portal so they are served by
# xdg-desktop-portal-lxqt (see FileChooser= in sway-portals.conf). Unlike the
# `lxqt` platform theme this also works for Qt5 apps -- lxqt-qtplugin ships a
# Qt6 plugin only. The portal theme wraps Qt's *generic* theme and so does no
# styling of its own, hence QT_STYLE_OVERRIDE below.
export QT_QPA_PLATFORMTHEME=xdgdesktopportal
# Read by Qt5 and Qt6 alike, and independent of the platform theme. Kvantum
# picks its theme up from ~/.config/Kvantum/kvantum.kvconfig, which is what
# `kvantummanager --set` writes, so theme switching keeps working.
export QT_STYLE_OVERRIDE=kvantum
export QT_WAYLAND_DISABLE_WINDOWDECORATION="1"

# use xdg-desktop-portal for file dialogs in GTK apps
export GTK_USE_PORTAL=1

#Java XWayland blank screens fix
export _JAVA_AWT_WM_NONREPARENTING=1

# set default shell and terminal
export SHELL=/usr/bin/zsh
export TERMINAL_COMMAND=xdg-terminal-exec

# add default location for zeit.db
export ZEIT_DB="$HOME/.config/zeit.db"

# set ozone platform to wayland
export ELECTRON_OZONE_PLATFORM_HINT=wayland

# Disable hardware cursors. This might fix issues with
# disappearing cursors
if systemd-detect-virt -q; then
    # if the system is running inside a virtual machine, disable hardware cursors
    export WLR_NO_HARDWARE_CURSORS=1
fi

# Disable warnings by OpenCV
export OPENCV_LOG_LEVEL=ERROR

set -a
. "$HOME/.config/user-dirs.dirs"
set +a

if [ -n "$(ls "$HOME"/.config/profile.d 2>/dev/null)" ]; then
    for f in "$HOME"/.config/profile.d/*; do
        # shellcheck source=/dev/null
        . "$f"
    done
fi
