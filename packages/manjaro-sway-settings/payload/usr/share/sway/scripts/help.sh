#!/usr/bin/env sh
set -x
# toggles the help wrapper state

VISIBILITY_SIGNAL=30
QUIT_SIGNAL=31
LOCKFILE="$HOME/.local/help_disabled"

if [ "$1" = "--toggle" ]; then
    if [ -f "$LOCKFILE" ]; then
        rm "$LOCKFILE"
    else
        touch "$LOCKFILE"
    fi
    # toggles the visibility
    pkill -f -${VISIBILITY_SIGNAL} nwg-wrapper

else
    # makes sure no "old" wrappers are mounted (on start and reload)
    pkill -f -${QUIT_SIGNAL} nwg-wrapper
    # mounts the wrapper to all outputs
    for output in $(swaymsg -t get_outputs --raw | jq -r '.[].name'); do
        # sets the initial visibility
        if [ -f "$LOCKFILE" ]; then
            VISIBILITY="--invisible"
        else
            VISIBILITY="--no-invisible"
        fi
        nwg-wrapper ${VISIBILITY} -o "$output" -sv ${VISIBILITY_SIGNAL} -sq ${QUIT_SIGNAL} -s help.sh -p left -a end &
    done
fi
