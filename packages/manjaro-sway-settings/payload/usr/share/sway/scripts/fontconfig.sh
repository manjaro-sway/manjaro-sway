#!/usr/bin/env sh
set -u

export CATEGORY=${1:-"monospace"}
export FONT=${2:-"JetBrainsMono NF"}

FONTCONFIG_DIR=$HOME/.config/fontconfig/conf.d

mkdir -p $FONTCONFIG_DIR

envsubst < /usr/share/sway/templates/fontconfig.conf > $FONTCONFIG_DIR/51-${CATEGORY}.conf
