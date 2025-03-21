#!/usr/bin/env bash
set -u

LOCKFILE="$HOME/.local/auto-theme-toggle"
DARK_SWAY_THEME="$HOME/.config/sway/definitions.d/theme.dark.conf_"
LIGHT_SWAY_THEME="$HOME/.config/sway/definitions.d/theme.light.conf_"

CURRENT_PRIMARY_THEME="dark"
CURRENT_SECONDARY_THEME="light"
NEXT_PRIMARY_THEME="dark"
NEXT_SECONDARY_THEME="light"

if [ -f "$DARK_SWAY_THEME" ]; then
    CURRENT_PRIMARY_THEME="light"
    CURRENT_SECONDARY_THEME="dark"
    NEXT_PRIMARY_THEME="light"
    NEXT_SECONDARY_THEME="dark"
fi

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

ensure_theme() {
    if [ "$CURRENT_PRIMARY_THEME" != "$1" ]; then
        PRIMARY_SWAY_THEME="$HOME/.config/sway/definitions.d/theme.conf"
        PRIMARY_FOOT_THEME="$HOME/.config/foot/foot-theme.ini"
        /usr/bin/mv --backup -v $PRIMARY_SWAY_THEME "$HOME/.config/sway/definitions.d/theme.$2.conf_"
        /usr/bin/mv --backup -v $PRIMARY_FOOT_THEME "$HOME/.config/foot/foot-theme.$2.ini_"
        /usr/bin/mv --backup -v "$HOME/.config/sway/definitions.d/theme.$1.conf_" $PRIMARY_SWAY_THEME
        /usr/bin/mv --backup -v "$HOME/.config/foot/foot-theme.$1.ini_" $PRIMARY_FOOT_THEME

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

    printf '{"alt":"%s","tooltip":"%s"}\n' "$alt" "$text"

    exit 0
    ;;
esac
