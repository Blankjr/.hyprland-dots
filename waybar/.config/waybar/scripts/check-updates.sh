#!/bin/bash

official=$(checkupdates 2>/dev/null | wc -l)
aur=$(yay -Qua 2>/dev/null | wc -l)
total=$((official + aur))

if [ "$total" -eq 0 ]; then
    echo '{"text": "󰏗 0", "tooltip": "System is up to date", "class": "up-to-date"}'
else
    tooltip="$official official, $aur AUR"
    echo "{\"text\": \"󰏗 $total\", \"tooltip\": \"$tooltip\", \"class\": \"updates-available\"}"
fi
