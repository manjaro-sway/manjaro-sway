#!/bin/sh

if [ -x "$(command -v gtklock)" ]; then
    gtklock --daemonize --follow-focus --idle-hide --start-hidden
elif [ -x "$(command -v waylock)" ]; then
    waylock -fork-on-lock
elif pacman -Qs swaylock-effects >/dev/null; then
    swaylock --daemonize --show-failed-attempts --screenshots --clock --indicator --effect-blur 7x5 --effect-vignette 0.5:0.5 --fade-in 0.2
elif pacman -Qs swaylock >/dev/null; then
    swaylock --daemonize --show-failed-attempts
fi
