#!/usr/bin/env sh
# https://github.com/francma/wob/wiki/wob-wrapper-script
#$1 - accent color. $2 - background color. $3 - new value
# returns 0 (success) if $1 is running and is attached to this sway session; else 1
is_running_on_this_screen() {
    pkill -U $USER -x -0 "wob" || return 1
    for pid in $(pgrep "wob"); do
        WOB_SWAYSOCK="$(tr '\0' '\n' </proc/"$pid"/environ | awk -F'=' '/^SWAYSOCK/ {print $2}')"
        if [ "$WOB_SWAYSOCK" = "$SWAYSOCK" ]; then
            return 0
        fi
    done
    return 1
}

wob_pipe=~/.cache/$(basename "$SWAYSOCK").wob

[ -p "$wob_pipe" ] || mkfifo "$wob_pipe"

ini=~/.config/wob.ini

to_wob_color() {
    # wob expects RRGGBBAA; sway themes provide #RRGGBB
    local hex="${1#\#}"
    echo "${hex}FF"
}

refresh() {
    pkill -U $USER -x wob
    rm -f $ini
    {
        echo "anchor = top center"
        echo "margin = 20"
        echo "border_color = $(to_wob_color "$1")"
        echo "bar_color = $(to_wob_color "$1")"
        echo "background_color = $(to_wob_color "$2")"
    } >>$ini
}

if [ ! -f "$ini" ] || [ "$3" = "--refresh" ]; then
   refresh "$1" "$2"
fi

# wob does not appear in $(swaymsg -t get_msg), so:
is_running_on_this_screen || {
    tail -f "$wob_pipe" | wob -c $ini &
}

if [ "$3" = "--refresh" ]; then
    exit 0;
elif [ -n "$3" ]; then
    echo "$3" >"$wob_pipe"
else
    cat >"$wob_pipe"
fi
