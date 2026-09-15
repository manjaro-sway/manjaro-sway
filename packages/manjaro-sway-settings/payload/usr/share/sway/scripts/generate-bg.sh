#!/usr/bin/env sh
set -u

export CROWN=$1
export ROOT=$2
export BACKGROUND=$3

envsubst < /usr/share/sway/templates/manjarosway-scalable.svg > "$HOME/.config/sway/generated_background.svg"
