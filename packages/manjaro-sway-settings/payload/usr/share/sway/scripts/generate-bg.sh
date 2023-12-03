#!/usr/bin/env sh
set -xu

DEFAULT_CROWN="#00f"
CROWN=$1

DEFAULT_ROOT="#fff"
ROOT=$2

DEFAULT_BACKGROUND="#000"
BACKGROUND=$3

# shellcheck disable=SC2002
cat /usr/share/sway/templates/manjarosway-scalable.svg | sed -e "s/${DEFAULT_CROWN}/${CROWN}/g" | sed -e "s/${DEFAULT_ROOT}/${ROOT}/g" | sed -e "s/${DEFAULT_BACKGROUND}/${BACKGROUND}/g" > "$HOME/.config/sway/generated_background.svg"
