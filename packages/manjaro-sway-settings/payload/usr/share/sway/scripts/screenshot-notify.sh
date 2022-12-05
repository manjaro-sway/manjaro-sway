#!/bin/sh

set -e

while true; do
    inotifywait -q -e create ~/Screenshots/ --format '%w%f' | xargs notify-send "Screenshot saved"
done
