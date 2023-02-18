#!/usr/bin/env sh
# script that sets the locale from current locale settings
swaymsg input type:keyboard xkb_layout "$(localectl status | grep "X11 Layout" | sed -e "s/^.*X11 Layout://")"

if localectl status | grep "X11 Variant" ; then
    swaymsg input type:keyboard xkb_variant "$(localectl status | grep "X11 Variant" | sed -e "s/^.*X11 Variant://")"
fi
