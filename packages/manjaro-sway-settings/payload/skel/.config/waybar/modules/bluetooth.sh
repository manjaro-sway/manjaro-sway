#!/bin/sh

state=$(bluetooth)

if [ "$state" = "bluetooth = on" ]
then
    # bt on
    tooltip="Bluetooth enabled!"
    class=""
else
    #bt off
    tooltip="Bluetooth disabled!"
    class="down"
fi

echo -e "{\"tooltip\":\""$tooltip"\", \"class\":\""$class"\"}"
exit 0


