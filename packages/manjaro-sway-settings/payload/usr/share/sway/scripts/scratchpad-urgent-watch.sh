#!/usr/bin/env sh
# The waybar scratchpad module is "interval": "once" + signal 7, and the only
# thing sending that signal is the `scratchpad show` binding. An urgency hint
# arriving on a hidden window therefore never reaches the bar. Sway emits a
# window event with change "urgent" on both the rising and falling edge; relay
# those so the module repaints when urgency is set and when it is cleared.
swaymsg -t subscribe -m '["window"]' \
    | jq --unbuffered -r 'select(.change == "urgent") | "tick"' \
    | while read -r _; do
        waybar-signal scratchpad
    done
