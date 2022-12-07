#!/bin/sh

set -e
DIR=~/Screenshots/

mkdir -p $DIR

while true; do
    inotifywait -q -e create $DIR --format '%w%f' | xargs notify-send "Screenshot saved"
done
