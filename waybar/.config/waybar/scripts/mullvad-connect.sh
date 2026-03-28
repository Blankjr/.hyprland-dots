#!/bin/bash

state=$(mullvad status 2>/dev/null | head -1)

if [[ "$state" == "Connected" ]]; then
    city=$(mullvad status --json 2>/dev/null | jq -r '.details.location.city // "Unknown"')
    notify-send "Mullvad VPN" "Connected to $city"
else
    mullvad connect
fi
