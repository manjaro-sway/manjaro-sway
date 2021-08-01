#!/bin/bash 
set -x

pid=`pgrep wf-recorder`
status=$?

gif=false

countdown() {
  notify "Recording in 3 seconds" -t 1000
  sleep 1
  notify "Recording in 2 seconds" -t 1000
  sleep 1
  notify "Recording in 1 seconds" -t 1000
  sleep 1
}

notify() {
    line=$1
    shift
    notify-send "Recording" "${line}" -i /usr/share/icons/Papirus-Dark/32x32/devices/camera-video.svg $*;
}

if [ $status != 0 ]
then
    target_path=$(xdg-user-dir VIDEOS)
    timestamp=$(date +'recording_%Y%m%d-%H%M%S')

    notify "Select a region to record" -t 1000
    area=$(swaymsg -t get_tree | jq -r '.. | select(.pid? and .visible?) | .rect | "\(.x),\(.y) \(.width)x\(.height)"' | slurp)

    countdown
    (sleep 0.5 && pkill -RTMIN+8 waybar) &

    if [ "$1" == "-a" ]; then
        file="$target_path/$timestamp.mp4"
        wf-recorder --audio -g "$area" --file="$file"
    else
        file="$target_path/$timestamp.webm"
        wf-recorder -g "$area" -c libvpx --codec-param="qmin=0" --codec-param="qmax=25" --codec-param="crf=4" --codec-param="b:v=1M" --file="$file" 
    fi

    pkill -RTMIN+8 waybar && notify "Finished recording ${file}"
else
    pkill --signal SIGINT wf-recorder
    pkill -RTMIN+8 waybar
fi