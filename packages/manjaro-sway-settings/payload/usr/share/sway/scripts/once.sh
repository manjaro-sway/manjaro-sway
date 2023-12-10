#!/usr/bin/env sh

mkdir -p "$HOME/.local/state"
LOCKFILE="$HOME/.local/state/once.lock"

# Kills the process if it's already running
lsof -Fp "$LOCKFILE" | sed 's/^p//' | xargs -r kill

flock --verbose -n "$LOCKFILE" "$@"
