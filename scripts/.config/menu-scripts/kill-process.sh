#!/usr/bin/env bash
set -euo pipefail

process="$(ps -u "$USER" -o pid=,comm= --sort=-%mem \
    | awk '{printf "%-8s %s\n", $1, $2}' \
    | rofi -dmenu -p 'Kill Process' -i)" || exit 0

[[ -z "$process" ]] && exit 0

pid="$(echo "$process" | awk '{print $1}')"
name="$(echo "$process" | awk '{print $2}')"

if kill "$pid" 2>/dev/null; then
    notify-send "Kill Process" "Sent SIGTERM to $name ($pid)"
else
    confirm="$(printf 'Yes\nNo' | rofi -dmenu -p "Force kill $name ($pid)?" -i)" || exit 0
    if [[ "$confirm" == "Yes" ]]; then
        kill -9 "$pid" 2>/dev/null && \
            notify-send "Kill Process" "Sent SIGKILL to $name ($pid)" || \
            notify-send "Kill Process" "Failed to kill $name ($pid)"
    fi
fi
