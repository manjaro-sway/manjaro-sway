#!/bin/sh
make=$(swaymsg -t get_outputs | jq -r '.[] | select(.focused==true) | .make')
model=$(swaymsg -t get_outputs | jq -r '.[] | select(.focused==true) | .model')
name=$(swaymsg -t get_outputs | jq -r '.[] | select(.focused==true) | .name')
current_screen="$make $model ($name)"

increment=0.25

current_scale() { 
    swaymsg -t get_outputs | jq -r '.[] | select(.focused==true) | .scale'
}

next_scale=$(current_scale)

scale() {
    [ -x "$(command -v way-displays)" ] && way-displays -s SCALE "$current_screen" $next_scale && way-displays -w || swaymsg output "\"$name\"" scale "$next_scale"
}

case $1'' in
'')
    current_scale
;;
'up')
    next_scale=$(echo "$(current_scale) + $increment" | bc)
    scale
    ;;
'down')
    next_scale=$(echo "$(current_scale) - $increment" | bc)
    scale
    ;;
esac

