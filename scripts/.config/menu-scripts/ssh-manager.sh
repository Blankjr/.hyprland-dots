#!/usr/bin/env bash
set -euo pipefail

SSH_CONFIG="${SSH_CONFIG:-$HOME/.ssh/config}"

if [[ ! -f "$SSH_CONFIG" ]]; then
    notify-send "SSH Manager" "No SSH config found at $SSH_CONFIG"
    exit 1
fi

mapfile -t hosts < <(awk '/^Host / && $2 !~ /[*?]/ { print $2 }' "$SSH_CONFIG")

if [[ ${#hosts[@]} -eq 0 ]]; then
    notify-send "SSH Manager" "No hosts found in $SSH_CONFIG"
    exit 1
fi

choice="$(printf '%s\n' "${hosts[@]}" | rofi -dmenu -p 'SSH' -i)" || exit 0
[[ -z "$choice" ]] && exit 0

exec kitty -- ssh "$choice"
