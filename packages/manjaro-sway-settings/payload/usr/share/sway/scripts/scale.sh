#!/bin/sh
current_screen=$(swaymsg -t get_outputs | jq -r '.[] | select(.focused==true) | .name')
increment=0.5

current_scale() { 
    swaymsg -t get_outputs | jq -r '.[] | select(.focused==true) | .scale'
}

next_scale=$(current_scale)

scale() {
    swaymsg output "\"$current_screen\"" scale "$next_scale"
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

