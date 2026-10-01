#!/bin/bash
set -u

THEME=$1

# kvantummanager opens its window when --set cannot resolve the name, and
# this runs on every start and every reload: a theme.conf naming a theme
# that is not installed meant Kvantum Manager on screen each time (#1055).
# A theme resolves where kvantummanager looks for one, by the same test -
# a <name>.kvconfig or <name>.svg in its directory. A "Dark" variant may
# also live in the directory of its light theme.
config_home=${XDG_CONFIG_HOME:-$HOME/.config}
installed() {
    local dir
    for dir in "$config_home/Kvantum/$1" "$HOME/.themes/$1/Kvantum" \
        "$HOME/.local/share/themes/$1/Kvantum" "/usr/share/Kvantum/$1" \
        "/usr/share/themes/$1/Kvantum"; do
        [ -f "$dir/$2.kvconfig" ] || [ -f "$dir/$2.svg" ] && return 0
    done
    return 1
}

if ! installed "$THEME" "$THEME" && ! { [ "${THEME%Dark}" != "$THEME" ] && installed "${THEME%Dark}" "$THEME"; }; then
    echo "kvantum theme '$THEME' is not installed; leaving the current one" >&2
    exit 0
fi

kvantummanager --set "$THEME"
