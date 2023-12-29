#!/bin/sh

case $1'' in
'status') 
    printf '{\"text\":\"%s\",\"tooltip\":\"%s\"}' "$(pamac checkupdates -q | wc -l)" "$(pamac checkupdates -q | awk 1 ORS='\\n' | sed 's/\\n$//')"
    ;;
'check')
    [ $(pamac checkupdates -q | wc -l) -gt 0 ]
    exit $?
    ;;
esac
