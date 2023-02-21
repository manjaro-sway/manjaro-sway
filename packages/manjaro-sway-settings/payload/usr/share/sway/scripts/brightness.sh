#!/bin/sh

current_abs=$(light -Gr)
current_rel() {
    echo "($(light -G) + 0.5) / 1" | bc
} 
max=$(light -Mr)
factor=3
brightness_step=$((max * factor / 100 < 1 ? 1 : max * factor / 100))

case $1'' in
'') ;;
'down')
    # if current value <= 3% and absolute value != 1, set brightness to absolute 1
    if [ "$(current_rel)" -le "$factor" ] && [ "$current_abs" -gt 0 ] && [ "$current_abs" -ne 1 ]; then
        light -rS 1
    else
        light -rU "$brightness_step"
    fi
    ;;
'up')
    light -rA "$brightness_step"
    ;;
esac

current_rel
