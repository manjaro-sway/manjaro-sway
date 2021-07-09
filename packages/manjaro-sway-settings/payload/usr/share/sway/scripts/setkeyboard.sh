#!/bin/sh
## updates the sway keyboard setting to the currently active X11 layout

swaymsg input type:keyboard xkb_layout "$(localectl status | grep "X11 Layout" | sed -e "s/^.*X11 Layout://")"
swaymsg input type:keyboard xkb_variant "$(localectl status | grep "X11 Variant" | sed -e "s/^.*X11 Variant://")"