#!/usr/bin/env bash
set -u

LOCKFILE="$HOME/.local/auto-theme-toggle"
DARK_SWAY_THEME="$HOME/.config/sway/definitions.d/theme.dark.conf_"
LIGHT_SWAY_THEME="$HOME/.config/sway/definitions.d/theme.light.conf_"

CURRENT_PRIMARY_THEME="dark"
CURRENT_SECONDARY_THEME="light"

if [ -f "$DARK_SWAY_THEME" ]; then
    CURRENT_PRIMARY_THEME="light"
    CURRENT_SECONDARY_THEME="dark"
fi

NEXT_PRIMARY_THEME="$CURRENT_PRIMARY_THEME"
NEXT_SECONDARY_THEME="$CURRENT_SECONDARY_THEME"

current_unix=$(date +%s)
__geo_content=$(sh /usr/share/sway/scripts/geoip.sh)

sunrise_unix() {
    sunrise_string=$(echo "$__geo_content" | jq -r '.sunrise // empty')
    sunrise_unix=$(date -d "$sunrise_string" +%s)
    echo "$sunrise_unix"
}

sunset_unix() {
    sunset_string=$(echo "$__geo_content" | jq -r '.sunset // empty')
    sunset_unix=$(date -d "$sunset_string" +%s)
    echo "$sunset_unix"
}

tomorrow_sunrise_unix() {
    sunrise_string=$(echo "$__geo_content" | jq -r '.sunrise_tomorrow // empty')
    sunrise_unix=$(date -d "$sunrise_string" +%s)
    echo "$sunrise_unix"
}

tomorrow_sunset_unix() {
    sunset_string=$(echo "$__geo_content" | jq -r '.sunset_tomorrow // empty')
    sunset_unix=$(date -d "$sunset_string" +%s)
    echo "$sunset_unix"
}

if [ -f "$LOCKFILE" ]; then
    if [ $current_unix -ge $(sunrise_unix) ] && [ $current_unix -lt $(sunset_unix) ]; then
        NEXT_PRIMARY_THEME="light"
        NEXT_SECONDARY_THEME="dark"
    else
        NEXT_PRIMARY_THEME="dark"
        NEXT_SECONDARY_THEME="light"
    fi
fi

merge_foot_themes() {
    local primary_theme=$1
    local dark_foot="$HOME/.config/foot/foot-theme.dark.ini_"
    local light_foot="$HOME/.config/foot/foot-theme.light.ini_"
    local merged_foot="$HOME/.config/foot/foot-theme.ini"

    [ -f "$dark_foot" ] && [ -f "$light_foot" ] || return 1

    {
        grep "^include=" "$dark_foot" | head -1
        printf '\n[main]\ninitial-color-theme=%s\n' "$primary_theme"
        printf '\n'
        awk '/^\[colors(-dark|-light)?\]/{p=1; print "[colors-dark]"; next} /^\[/ && p{p=0} p{print}' "$dark_foot"
        printf '\n'
        awk '/^\[colors(-dark|-light)?\]/{p=1; print "[colors-light]"; next} /^\[/ && p{p=0} p{print}' "$light_foot"
    } > "$merged_foot"

    if [ "$primary_theme" = "dark" ]; then
        pkill -SIGUSR1 foot || true
    else
        pkill -SIGUSR2 foot || true
    fi
}

ensure_theme() {
    if [ "$CURRENT_PRIMARY_THEME" != "$1" ]; then
        PRIMARY_SWAY_THEME="$HOME/.config/sway/definitions.d/theme.conf"
        /usr/bin/mv --backup -v $PRIMARY_SWAY_THEME "$HOME/.config/sway/definitions.d/theme.$2.conf_"
        /usr/bin/mv --backup -v "$HOME/.config/sway/definitions.d/theme.$1.conf_" $PRIMARY_SWAY_THEME

        merge_foot_themes "$1"

        swaymsg reload
    fi
}

#Accepts managing parameter
case $1'' in
'toggle')
    if [ -f "$LOCKFILE" ]; then
        NEXT_PRIMARY_THEME="$CURRENT_PRIMARY_THEME"
        NEXT_SECONDARY_THEME="$CURRENT_SECONDARY_THEME"
    else
        NEXT_PRIMARY_THEME="$CURRENT_SECONDARY_THEME"
        NEXT_SECONDARY_THEME="$CURRENT_PRIMARY_THEME"
    fi

    ensure_theme $NEXT_PRIMARY_THEME $NEXT_SECONDARY_THEME
    exit 0
    ;;
'auto-toggle')
    if [ -f "$LOCKFILE" ]; then
        rm "$LOCKFILE"
    else
        touch "$LOCKFILE"
    fi

    waybar-signal theme
    exit 0
    ;;
'check')
    [ -f "$DARK_SWAY_THEME" ] || [ -f "$LIGHT_SWAY_THEME" ]
    exit $?
    ;;
'status')
    #Returns a string for Waybar
    text="switch to ${CURRENT_SECONDARY_THEME} theme\r(Right click to switch automatically)"
    alt=$CURRENT_PRIMARY_THEME
    if [ -f "$LOCKFILE" ]; then
        next_switch_unix=$(sunrise_unix)
        if [ $current_unix -ge $next_switch_unix ]; then
            next_switch_unix=$(sunset_unix)
        fi
        if [ $current_unix -ge $next_switch_unix ]; then
            next_switch_unix=$(tomorrow_sunrise_unix)
        fi
        hours=$((($next_switch_unix - $current_unix) / (60 * 60)))
        minutes=$((($next_switch_unix - $current_unix) / 60 % 60))
        text="switching to ${CURRENT_SECONDARY_THEME} theme in ${hours}h ${minutes}m\r(Right click to disable)"
        alt="auto_${CURRENT_PRIMARY_THEME}"

        ensure_theme $NEXT_PRIMARY_THEME $NEXT_SECONDARY_THEME
    fi

    jq -cn --arg alt "$alt" --arg text "$text" '{"alt":$alt,"tooltip":$text}'

    exit 0
    ;;
esac
