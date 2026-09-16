#!/bin/sh
# Approximate location and today's sun times, cached for the day.
#
# One call to the ashlaros worker, which reads the geo data Cloudflare
# already attached to the request at its edge and computes the sun times
# there. Not a commercial geo-ip service: this used to tell get.geojs.io,
# and the weather module told it again on every refresh. It is a sibling
# project's deployment rather than ours, so the IP leaves this project
# even though it does not reach a data broker - MANJARO_SWAY_GEO_URL
# points it elsewhere for anyone who would rather it did not.
#
# Consumers - sunset.sh and theme-toggle.sh - read .latitude/.longitude/
# .city/.sunrise/.sunset/.sunrise_tomorrow/.sunset_tomorrow, and the worker
# answers with exactly those keys, so this passes the body through.
set -u

geo_url="${MANJARO_SWAY_GEO_URL:-https://ashlaros.download/geo}"

cache_file="$HOME/.cache/geoip"
cache_time=$(date -r "$cache_file" +%s 2>/dev/null || echo 0)
six_hours_ago=$(date -d 'now - 6 hour' +%s)
start_of_day=$(date -d '00:00' +%s)

if [ ! -f "$cache_file" ] || [ "$cache_time" -lt "$six_hours_ago" ] || [ "$cache_time" -lt "$start_of_day" ]; then
	mkdir -p "$(dirname "$cache_file")"
	tmp_file=$(mktemp "${cache_file}.tmp.XXXXXX") || exit 1

	# The worker already returns the shape consumers read, so this only
	# checks that it is that shape before replacing a working cache: a 503
	# from an edge without geo data must not blank out yesterday's answer.
	curl -fsSL --max-time 10 "$geo_url" 2>/dev/null \
		| jq -e 'select(.latitude != null and .longitude != null)' > "$tmp_file" 2>/dev/null

	if [ -s "$tmp_file" ]; then
		mv "$tmp_file" "$cache_file"
	else
		rm -f "$tmp_file"
	fi
fi

# a stale cache still answers; an absent one leaves callers to their
# configured fallback coordinates
[ -f "$cache_file" ] && cat "$cache_file"
