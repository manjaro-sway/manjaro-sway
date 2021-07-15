#!/bin/bash

CMD="kitty --config=\$theme/kitty.conf"
[ -n "$1" ] && [ "$1" == "float" ] && CMD="$CMD --class=floating_shell"
[ -n "$1" ] && [ "$1" == "float_portrait" ] && CMD="$CMD --class=floating_shell_portrait"
[ -n "$1" ] && CMD="$CMD ${2:-$1}"

echo $CMD 
swaymsg exec "$CMD"