#!/usr/bin/env sh

status() {
    systemctl --user is-active wluma >/dev/null 2>&1
}

#Accepts managing parameter
case $1'' in
'toggle')
    status && systemctl --user stop wluma || systemctl --user --now enable wluma
    ;;
'check')
    command -v wluma
    exit $?
    ;;
esac

#Returns data for Waybar
if status; then
    class="on"
    text="adative brightness"
else
    class="off"
    text="static brightness"
fi

printf '{"alt":"%s","tooltip":"%s"}\n' "$class" "$text"
