#!/bin/sh
set -u

cache_file="$HOME/.cache/geoip"
cache_time=$(date -r "$cache_file" +%s 2>/dev/null || echo 0)
yesterday_time=$(date -d 'now - 6 hour' +%s)
start_of_day=$(date -d '00:00' +%s)
if [ ! -f "$cache_file" ] || [ "$cache_time" -lt "$yesterday_time" ] || [ "$cache_time" -lt "$start_of_day" ]; then
	tmp_file=$(mktemp "${cache_file}.tmp.XXXXXX") || exit 1
	if curl -fsSL "https://manjaro-sway.download/geoip" > "$tmp_file" && [ -s "$tmp_file" ]; then
		mv "$tmp_file" "$cache_file"
	else
		rm -f "$tmp_file"
	fi
fi
cat "$cache_file"
