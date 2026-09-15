#!/usr/bin/env sh
# script that sets the locale from current locale settings
status=$(localectl status)
swaymsg input type:keyboard xkb_layout "$(echo "$status" | grep "X11 Layout" | sed -e "s/^.*X11 Layout://")"

if echo "$status" | grep "X11 Variant" ; then
    swaymsg input type:keyboard xkb_variant "$(echo "$status" | grep "X11 Variant" | sed -e "s/^.*X11 Variant://")"
fi
