#!/bin/sh
man $HOME/.config/sway/help.man | col -b | grep 'Help\|Terminal\|Launcher\|Toggle\|Exit\|Kill\|Switch\|Move\|Scratchpad' | awk '{$1=$1}1' | sort