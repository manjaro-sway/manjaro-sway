#!/bin/bash

#Startup function
function start(){
	[[ -f "$HOME/.config/wlsunset/config" ]] && source "$HOME/.config/wlsunset/config"
	temp_low=${temp_low:-"4000"}
	temp_high=${temp_high:-"6500"}
	duration=${duration:-"900"}
	sunrise=${sunrise:-"07:00"}
	sunset=${sunset:-"19:00"}
	longitude=${longitude:-65}
	latitude=${latitude:-65}
	location=${location:-"off"}

	if [ "${location}" = "on" ]; 
	then
		CONTENT=$(curl -s https://freegeoip.app/json/)
		content_longitude=$(echo $CONTENT | jq '.longitude // empty')
        longitude=${content_longitude:-"${longitude}"}
        content_latitude=$(echo $CONTENT | jq '.latitude // empty')
        latitude=${content_latitude:-"${latitude}"}
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
   	if pkill -0 wlsunset
	then
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
if pkill -0 wlsunset
then
	class="on"
else
	class="off"
fi	

printf '{"alt":"%s"}\n' "$class"
