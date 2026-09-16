#!/usr/bin/env sh
nodes=$(swaymsg -r -t get_tree | jq -c 'recurse(.nodes[]) | first(select(.name=="__i3_scratch")) | .floating_nodes | .[]
    | {app_id, name, urgent: ([recurse(.nodes[]?, .floating_nodes[]?) | .urgent] | any)}')
tooltip=$(printf "%s" "$nodes" | jq -r '"\(if .urgent then "! " else "" end)\(.app_id) | \(.name)"')
count=$(printf "%s" "$nodes" | grep -c '^')

if [ "$count" -eq 0 ]; then
    exit 1
elif [ "$count" -eq 1 ]; then
    class="one"
elif [ "$count" -gt 1 ]; then
    class="many"
else
    class="unknown"
fi

# A scratchpad window is hidden and is not on a workspace, so an urgency hint it
# raises has nowhere to surface -- no workspace button lights up for it. Report
# it as an extra class rather than an alt, so {icon} keeps resolving one/many.
urgent=$(printf "%s" "$nodes" | jq -s 'map(.urgent) | any')
if [ "$urgent" = "true" ]; then
    classes=$(jq -cn --arg class "$class" '[$class, "urgent"]')
else
    classes=$(jq -cn --arg class "$class" '[$class]')
fi

jq -cn --arg count "$count" --argjson class "$classes" --arg alt "$class" --arg tooltip "$tooltip" \
   '{"text": $count, "class": $class, "alt": $alt, "tooltip": $tooltip}'
