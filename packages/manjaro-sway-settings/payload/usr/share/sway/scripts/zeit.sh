#!/usr/bin/env sh
tracking=$(zeit tracking --no-colors)

case $1'' in
'status')
    text=$(echo "$tracking" | sed -z 's/\n/\\n/g' | grep -q 'tracking' && echo "tracking" || echo "stopped")
    tooltip=$tracking'\r(zeit time tracker)'
    echo "{\"text\":\"$text\",\"tooltip\":\"$tooltip\",\"class\":\"$text\",\"alt\":\"$text\"}"
    ;;
'click')
    if echo "$tracking" | grep -q 'tracking'; then
        zeit finish
    else
        swaymsg exec \$zeit_list
    fi
    ;;
'track')
    input=$(cat -)
    task=$(echo $input | pcregrep -io1 '└── (.+) \[.+')
    project=$(echo $input | pcregrep -io1 '.+\[(.+)\]')

    if [ "$task" = "" ] || [ "$project" = "" ]; then
        notify-send "You did not select a task!"
        exit 1
    fi

    zeit track -p "$project" -t "$task"
    notify-send "Tracking $task in $project"
    ;;
esac
