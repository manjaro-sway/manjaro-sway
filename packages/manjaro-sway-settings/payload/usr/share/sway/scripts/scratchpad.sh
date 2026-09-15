#!/usr/bin/env sh
tooltip=$(swaymsg -r -t get_tree | jq -r 'recurse(.nodes[]) | first(select(.name=="__i3_scratch")) | .floating_nodes | .[] | "\(.app_id) | \(.name)"')
count=$(printf "%s" "$tooltip" | grep -c '^')

if [ "$count" -eq 0 ]; then
    exit 1
elif [ "$count" -eq 1 ]; then
    class="one"
elif [ "$count" -gt 1 ]; then
    class="many"
else
    class="unknown"
fi

jq -cn --arg count "$count" --arg class "$class" --arg tooltip "$tooltip" \
   '{"text": $count, "class": $class, "alt": $class, "tooltip": $tooltip}'
