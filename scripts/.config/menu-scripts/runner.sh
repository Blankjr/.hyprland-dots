#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SELF="$(basename "$0")"

declare -A name_to_file

for script in "$SCRIPT_DIR"/*.sh; do
    [[ -x "$script" ]] || continue
    base="$(basename "$script")"
    [[ "$base" == "$SELF" ]] && continue

    display="$(echo "${base%.sh}" | tr '-' ' ' | sed 's/\b\(.\)/\u\1/g')"
    name_to_file["$display"]="$script"
done

if [[ ${#name_to_file[@]} -eq 0 ]]; then
    notify-send "Script Runner" "No scripts found in $SCRIPT_DIR"
    exit 1
fi

choice="$(printf '%s\n' "${!name_to_file[@]}" | sort | rofi -dmenu -p 'Scripts' -i)" || exit 0

[[ -n "$choice" ]] && exec "${name_to_file[$choice]}"
