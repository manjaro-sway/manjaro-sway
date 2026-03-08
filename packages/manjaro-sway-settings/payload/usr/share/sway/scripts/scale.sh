#!/bin/sh
outputs=$(swaymsg -t get_outputs)
make=$(echo "$outputs" | jq -r '.[] | select(.focused==true) | .make')
model=$(echo "$outputs" | jq -r '.[] | select(.focused==true) | .model')
name=$(echo "$outputs" | jq -r '.[] | select(.focused==true) | .name')
current_screen="$make $model ($name"

increment=0.25

current_scale() {
    swaymsg -t get_outputs | jq -r '.[] | select(.focused==true) | .scale'
}

next_scale=$(echo "$outputs" | jq -r '.[] | select(.focused==true) | .scale')

scale() {
    [ -x "$(command -v way-displays)" ] && way-displays -s SCALE "$current_screen" $next_scale && way-displays -w || swaymsg output "\"$name\"" scale "$next_scale"
    sleep 0.1
    /usr/share/sway/scripts/generate-displays-config.sh
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
'default')
    next_scale=1
    scale
    ;;
esac

