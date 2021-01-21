#!/bin/bash
function version { 
    echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'; 
}

GL_VERSION=$(glxinfo | awk '/OpenGL version/ {print $4}')

CMD=""
if [[ -x "$(command -v kitty)" && $(version $GL_VERSION) -ge $(version "3.3") ]]; then
    CMD="kitty --config=\$theme/kitty.conf"
    [ -n "$1" ] && [ "$1" == "float" ] && CMD="$CMD --class=floating_shell"
    [ -n "$1" ] && [ "$1" == "float_portrait" ] && CMD="$CMD --class=floating_shell_portrait"
    [ -n "$1" ] && CMD="$CMD ${2:-$1}"
else
    CMD="termite --config=\$theme/termite.conf"
    [ -n "$1" ] && [ "$1" == "float" ] && CMD="$CMD --name=floating_shell"
    [ -n "$1" ] && [ "$1" == "float_portrait" ] && CMD="$CMD --name=floating_shell_portrait"
    [ -n "$1" ] && CMD="$CMD --exec ${2:-$1}"
fi

echo $CMD 
swaymsg exec "$CMD"