#!/bin/sh
set -x
# toggles the help wrapper state

OUTPUTS=$(swaymsg -t get_outputs --raw | jq -r '.[].name')
VISIBILITY_SIGNAL=30
QUIT_SIGNAL=31

if [[ "$1" == "--toggle" ]]; then
    pkill -f -${VISIBILITY_SIGNAL} nwg-wrapper
else
    pkill -f -${QUIT_SIGNAL} nwg-wrapper
    for o in "$OUTPUTS"; do
        nwg-wrapper -o $o -sv ${VISIBILITY_SIGNAL} -sq ${QUIT_SIGNAL} -s help.sh -p left -a end &
    done
fi
