#!/bin/bash

#Startup function
function start() {
    [[ -f "$HOME/.config/wlsunset/config" ]] && source "$HOME/.config/wlsunset/config"
    temp_low=${temp_low:-"4000"}
    temp_high=${temp_high:-"6500"}
    duration=${duration:-"900"}
    sunrise=${sunrise:-"07:00"}
    sunset=${sunset:-"19:00"}
    location=${location:-"on"}
    fallback_longitude=${fallback_longitude:-"8.7"}
    fallback_latitude=${fallback_latitude:-"50.1"}

    if [ "${location}" = "on" ]; then
        if [[ -z ${longitude+x} ]] || [[ -z ${latitude+x} ]]; then
            GEO_CONTENT=$(curl -sL https://freegeoip.app/json/)
        fi
        longitude=${longitude:-$(echo $GEO_CONTENT | jq '.longitude // empty')}
        longitude=${longitude:-$fallback_longitude}
        latitude=${latitude:-$(echo $GEO_CONTENT | jq '.latitude // empty')}
        latitude=${latitude:-$fallback_latitude}

        echo longitude: $longitude latitude: $latitude

        wlsunset -l $latitude -L $longitude -t $temp_low -T $temp_high -d $duration &
    else
        wlsunset -t $temp_low -T $temp_high -d $duration -S $sunrise -s $sunset &
    fi
}

#Accepts managing parameter
case $1'' in
'off')
    pkill wlsunset
    ;;

'on')
    start
    ;;

'toggle')
    if pkill -0 wlsunset; then
        pkill wlsunset
    else
        start
    fi
    ;;
'check')
    command -v wlsunset
    exit $?
    ;;
esac

#Returns a string for Waybar
if pkill -0 wlsunset; then
    class="on"
else
    class="off"
fi

printf '{"alt":"%s"}\n' "$class"
