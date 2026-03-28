#!/bin/bash
# Single-shot: called by waybar on interval

state=$(mullvad status 2>/dev/null | head -1)

if [[ "$state" == "Connected" ]]; then
    printf '{"text": "󰌾", "tooltip": "VPN: Connected", "class": "connected"}\n'
else
    printf '{"text": "󰌿", "tooltip": "VPN: Disconnected", "class": "disconnected"}\n'
fi
