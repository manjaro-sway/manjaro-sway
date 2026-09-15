#!/bin/sh

get_updates() {
    CACHE_FILE="/tmp/pamac-checkupdates-$USER"
    if [ -f "$CACHE_FILE" ] && [ $(($(date +%s) - $(stat -c %Y "$CACHE_FILE"))) -lt 30 ]; then
        cat "$CACHE_FILE"
    else
        pamac checkupdates -q -a | tee "$CACHE_FILE"
    fi
}

case $1'' in
'status')
    UPDATES=$(get_updates)
    COUNT=$(echo "$UPDATES" | grep -v '^$' | wc -l)
    TOOLTIP=$(echo "$UPDATES" | awk 1 ORS='\\n' | sed 's/\\n$//')
    jq -cn --arg count "$COUNT" --arg tooltip "$TOOLTIP" '{"text": $count, "tooltip": $tooltip}'
    ;;
'check')
    UPDATES=$(get_updates)
    [ $(echo "$UPDATES" | grep -v '^$' | wc -l) -gt 0 ]
    exit $?
    ;;
'upgrade')
    if [ -x "$(command -v pacseek)" ]; then
        xdg-terminal-exec pacseek -u
    elif [ -x "$(command -v topgrade)" ]; then
        xdg-terminal-exec topgrade
    elif [ -x "$(command -v pamac-manager)" ]; then
        pamac-manager --updates
    else
        xdg-terminal-exec pacman -Syu
    fi
    ;;
esac
