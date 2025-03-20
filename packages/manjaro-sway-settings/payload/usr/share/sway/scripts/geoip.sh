#!/bin/sh
set -u

cache_file="$HOME/.cache/geoip"
cache_time=$(date -r "$cache_file" +%s)
yesterday_time=$(date -d 'now - 6 hour' +%s)
start_of_day=$(date -d '00:00' +%s)
if [ ! -f "$cache_file" ] || [ $cache_time -lt $yesterday_time ] || [ $cache_time -lt $start_of_day ]; then
    curl -sL https://manjaro-sway.download/geoip >"$cache_file"
fi
cat "$cache_file"
