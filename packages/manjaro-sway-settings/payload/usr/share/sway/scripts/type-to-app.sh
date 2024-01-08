#!/bin/sh
set -x

PID=$(swaymsg -t get_tree | jq '.. | select(.type?) | select(.focused==true) | .pid')

matcher=$1
shift
type=$@

swaymsg [$matcher] focus
    if [ "$?" = "0" ]
then
    wtype $type
    swaymsg "[pid=$PID] focus"
fi
