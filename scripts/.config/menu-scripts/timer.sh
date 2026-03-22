#!/usr/bin/env bash
set -euo pipefail

parse_duration() {
    local input="$1" total=0
    if [[ "$input" =~ ^([0-9]+)$ ]]; then
        total=$(( ${BASH_REMATCH[1]} * 60 ))
    else
        [[ "$input" =~ ([0-9]+)h ]] && total=$(( total + ${BASH_REMATCH[1]} * 3600 ))
        [[ "$input" =~ ([0-9]+)m ]] && total=$(( total + ${BASH_REMATCH[1]} * 60 ))
        [[ "$input" =~ ([0-9]+)s ]] && total=$(( total + ${BASH_REMATCH[1]} ))
    fi
    echo "$total"
}

choice="$(printf '1m\n5m\n10m\n15m\n30m\n1h\nCustom' | rofi -dmenu -p 'Timer' -i)" || exit 0
[[ -z "$choice" ]] && exit 0

if [[ "$choice" == "Custom" ]]; then
    choice="$(rofi -dmenu -p 'Duration (e.g. 5m, 1h30m)' -l 0 \
        -theme-str 'listview { lines: 0; }')" || exit 0
    [[ -z "$choice" ]] && exit 0
fi

seconds="$(parse_duration "$choice")"

if [[ "$seconds" -le 0 ]]; then
    notify-send "Timer" "Invalid duration: $choice"
    exit 1
fi

notify-send "Timer" "Started: $choice"

(
    sleep "$seconds"
    notify-send -u critical "Timer" "Time's up! ($choice)"
) &

disown
