#!/bin/sh

case $1'' in
'status') 
    UPDATES=$(pamac checkupdates -q -a)
    COUNT=$(echo "$UPDATES" | grep -v '^$' | wc -l)
    TOOLTIP=$(echo "$UPDATES" | awk 1 ORS='\\n' | sed 's/\\n$//')
    if [ -x "$(command -v jq)" ]; then
        jq -n --arg count "$COUNT" --arg tooltip "$TOOLTIP" '{"text": $count, "tooltip": $tooltip}'
    else
        printf '{"text":"%s","tooltip":"%s"}' "$COUNT" "$TOOLTIP"
    fi
    ;;
'check')
    [ $(pamac checkupdates -q -a | grep -v '^$' | wc -l) -gt 0 ]
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
