#!/usr/bin/env sh
HASH="$(echo "$@" | shasum | cut -f1 -d" " | cut -c1-7)"

mkdir -p ~/lock

flock --verbose -n ~/lock/"${HASH}".lock "$@" 
