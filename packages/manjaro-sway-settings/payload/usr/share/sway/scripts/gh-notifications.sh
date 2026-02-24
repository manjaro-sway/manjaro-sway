#!/usr/bin/env bash

# Check if gh is installed
if ! command -v gh &>/dev/null; then
    exit 0
fi

# Fetch unread notifications
# If the command fails (e.g. offline, not authenticated), exit
NOTIFS_JSON=$(gh api notifications 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$NOTIFS_JSON" ]; then
    exit 0
fi

# Output JSON for Waybar using jq
echo "$NOTIFS_JSON" | jq -c '
    if type == "array" and length > 0 then
        length as $count |
        {
            text: ($count | tostring),
            tooltip: ("Unread notifications (" + ($count | tostring) + "):\n" + (.[0:25] | map("\(.subject.title) (\(.repository.full_name))") | join("\n")) + (if $count > 25 then "\n..." else "" end)),
            class: "github"
        }
    else
        empty
    end'
