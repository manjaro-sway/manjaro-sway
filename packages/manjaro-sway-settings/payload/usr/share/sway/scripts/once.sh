#!/usr/bin/env sh
HASH="$(echo "$@" | shasum | cut -f1 -d" " | cut -c1-7)"

mkdir -p "$HOME/.local/state"

flock --verbose -n "$HOME/.local/state/${HASH}.lock" "$@" 
