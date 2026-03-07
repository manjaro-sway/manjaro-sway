#!/bin/sh

case $1'' in
'status') 
    alt=$(makoctl mode | grep -q 'do-not-disturb' && echo dnd || echo default)
    tooltip="mode: $(makoctl mode | tail -1)"
    jq -cn --arg alt "$alt" --arg tooltip "$tooltip" '{"alt":$alt,"tooltip":$tooltip}'
    ;;
'restore')
    makoctl restore
    ;;
'toggle')
    makoctl mode | grep 'do-not-disturb' && makoctl mode -r do-not-disturb || makoctl mode -a do-not-disturb
    ;;
esac
