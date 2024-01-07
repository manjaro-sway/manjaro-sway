#!/usr/bin/env sh
set -x

case $1'' in
'on')
    for device in $DEVICES; do
        brightnessctl -r -d "*kbd_backlight"
    done
    ;;
'off')
    for device in $DEVICES; do
        brightnessctl -s -d "*kbd_backlight" && brightnessctl -d "*kbd_backlight" set 0
    done
    ;;
esac
