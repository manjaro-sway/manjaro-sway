#!/usr/bin/env sh
# wrapper script for wob — https://github.com/francma/wob/wiki/wob-wrapper-script
# $1 - accent color   $2 - background color   $3 - new value | --refresh
#
# Theme colors are kept in a managed file that is regenerated on every theme
# switch; the user's ~/.config/wob.ini is seeded once and then never touched.
# The config handed to wob is the managed colors followed by the user file, so
# anything set in ~/.config/wob.ini overrides the theme (same model as waybar's
# colors.css/style.css split).

MARKER="# managed by manjaro-sway"

# returns 0 (success) if wob is running and is attached to this sway session; else 1
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

user_ini=~/.config/wob.ini
colors_ini=~/.config/wob.colors.ini
effective_ini=~/.cache/$(basename "$SWAYSOCK").wob.ini

to_wob_color() {
    # wob expects RRGGBB[AA]; sway themes provide #RRGGBB
    hex="${1#\#}"
    echo "${hex}FF"
}

# Theme-managed colors only — safe to overwrite on every theme switch.
refresh_colors() {
    {
        echo "$MARKER — regenerated on every theme switch, edits here are lost."
        echo "# Put overrides in ~/.config/wob.ini instead."
        echo "border_color = $(to_wob_color "$1")"
        echo "bar_color = $(to_wob_color "$1")"
        echo "background_color = $(to_wob_color "$2")"
    } >"$colors_ini"
}

# Seed the user config once, then leave it alone.
seed_user_ini() {
    # Migrate the legacy auto-generated wob.ini (no marker, baked-in colors) out
    # of the way so its hard-coded colors stop shadowing the managed theme.
    if [ -f "$user_ini" ] && ! grep -qF "$MARKER" "$user_ini" && grep -qF "bar_color" "$user_ini"; then
        mv "$user_ini" "$user_ini.bak"
    fi
    [ -f "$user_ini" ] && return
    {
        echo "$MARKER seeded this file once; it is now yours to edit freely."
        echo "# Colors come from ~/.config/wob.colors.ini (theme-managed);"
        echo "# anything set here overrides the theme."
        echo "anchor = top center"
        echo "margin = 20"
    } >"$user_ini"
}

# Managed colors first so user settings in wob.ini take precedence.
build_effective_ini() {
    cat "$colors_ini" "$user_ini" >"$effective_ini"
}

seed_user_ini
if [ ! -f "$colors_ini" ] || [ "$3" = "--refresh" ]; then
    refresh_colors "$1" "$2"
fi
build_effective_ini

# On a theme refresh, restart wob so the new colors take effect.
[ "$3" = "--refresh" ] && pkill -U $USER -x wob

# wob does not appear in $(swaymsg -t get_msg), so:
is_running_on_this_screen || {
    tail -f "$wob_pipe" | wob -c "$effective_ini" &
}

if [ "$3" = "--refresh" ]; then
    exit 0;
elif [ -n "$3" ]; then
    echo "$3" >"$wob_pipe"
else
    cat >"$wob_pipe"
fi
