#!/bin/sh

case $1'' in
'status') 
    CACHE_FILE="/tmp/pamac-checkupdates-$USER"
    if [ -f "$CACHE_FILE" ] && [ $(($(date +%s) - $(stat -c %Y "$CACHE_FILE"))) -lt 30 ]; then
        UPDATES=$(cat "$CACHE_FILE")
    else
        UPDATES=$(pamac checkupdates -q -a)
        echo "$UPDATES" > "$CACHE_FILE"
    fi
    COUNT=$(echo "$UPDATES" | grep -v '^$' | wc -l)
    TOOLTIP=$(echo "$UPDATES" | awk 1 ORS='\\n' | sed 's/\\n$//')
    if [ -x "$(command -v jq)" ]; then
        jq -n --arg count "$COUNT" --arg tooltip "$TOOLTIP" '{"text": $count, "tooltip": $tooltip}'
    else
        printf '{"text":"%s","tooltip":"%s"}' "$COUNT" "$TOOLTIP"
    fi
    ;;
'check')
    CACHE_FILE="/tmp/pamac-checkupdates-$USER"
    if [ -f "$CACHE_FILE" ] && [ $(($(date +%s) - $(stat -c %Y "$CACHE_FILE"))) -lt 30 ]; then
        UPDATES=$(cat "$CACHE_FILE")
    else
        UPDATES=$(pamac checkupdates -q -a)
        echo "$UPDATES" > "$CACHE_FILE"
    fi
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
