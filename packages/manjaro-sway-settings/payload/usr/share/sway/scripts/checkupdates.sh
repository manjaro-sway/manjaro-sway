#!/bin/sh

case $1'' in
'status') 
    printf '{\"text\":\"%s\",\"tooltip\":\"%s\"}' "$(pamac checkupdates -q | wc -l)" "$(pamac checkupdates -q | awk 1 ORS='\\n' | sed 's/\\n$//')"
    ;;
'check')
    [ $(pamac checkupdates -q | wc -l) -gt 0 ]
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
