#!/usr/bin/env bash
# Continuous output for Waybar custom/timer — reads state from $XDG_RUNTIME_DIR/waybar-timer

set -euo pipefail

STATE="${XDG_RUNTIME_DIR:-/tmp}/waybar-timer"

json_escape() {
    local s=$1
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    s=${s//$'\n'/ }
    printf '%s' "$s"
}

while true; do
    if [[ -f "$STATE" ]]; then
        end_line=""
        label_line=""
        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ "$line" =~ ^end= ]] && end_line="$line"
            [[ "$line" =~ ^label= ]] && label_line="$line"
        done < "$STATE"
        end="${end_line#end=}"
        label="${label_line#label=}"
        now="$(date +%s)"

        if [[ -n "$end" ]] && [[ "$end" =~ ^[0-9]+$ ]] && (( end > now )); then
            left=$(( end - now ))
            mm=$(( left / 60 ))
            ss=$(( left % 60 ))
            printf -v ts '%d:%02d' "$mm" "$ss"
            esc="$(json_escape "$label")"
            printf '{"text": "󰔛 %s", "tooltip": "Timer: %s — click to cancel", "class": "active"}\n' "$ts" "$esc"
            sleep 1
            continue
        elif [[ -n "$end" ]] && [[ "$end" =~ ^[0-9]+$ ]] && (( end <= now )); then
            notify-send -u critical "Timer" "Time's up! (${label:-timer})"
            rm -f "$STATE"
        fi
    fi

    printf '{"text": "󰔛", "tooltip": "Click to start a timer", "class": "idle"}\n'
    sleep 2
done
