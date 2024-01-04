#!/usr/bin/env sh
set -x

# Get the backlight devices
DEVICES="$(light -L | grep kbd_backlight)"

case $1'' in
'on')
    for device in $DEVICES; do
        light -s $device -I
    done
    ;;
'off')
    for device in $DEVICES; do
        light -s $device -O && light -s $device -S 0
    done
    ;;
esac
