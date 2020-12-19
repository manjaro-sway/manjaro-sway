#!/bin/sh

if [ $(nmcli -f TYPE con show --active | grep vpn | wc -l) -gt 0 ]
then
    # vpn on$
    text=""
    tooltip="VPN connected!"
    class="#"
else
    #vpn off
    text=""
    tooltip="VPN not connected!"
    class="down"
fi

echo -e "{\"text\":\""$text"\", \"tooltip\":\""$tooltip"\", \"class\":\""$class"\"}"
exit 0


