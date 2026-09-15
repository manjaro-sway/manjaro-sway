#!/bin/sh
current_abs=$(brightnessctl get)
current_rel() {
    echo "$(brightnessctl get) * 100 / $(brightnessctl max)" | bc 
} 
max=$(brightnessctl max)
factor=3
brightness_step=$((max * factor / 100 < 1 ? 1 : max * factor / 100))

case $1'' in
'') ;;
'down')
    # if current value <= 3% and absolute value != 1, set brightness to absolute 1
    if [ "$(current_rel)" -le "$factor" ] && [ "$current_abs" -ge 0 ]; then
        brightnessctl --quiet set 1
    else
        brightnessctl --quiet set "${brightness_step}-"
    fi
    ;;
'up')
    brightnessctl --quiet set "${brightness_step}+"
    ;;
esac

current_rel
