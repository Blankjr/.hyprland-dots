#!/usr/bin/env bash
set -euo pipefail

NOTES_FILE="${NOTES_FILE:-$HOME/notes.md}"

note="$(rofi -dmenu -p 'Note' -l 0 \
    -theme-str 'listview { lines: 0; }' \
    -theme-str 'entry { placeholder: "Type your note..."; }')" || exit 0

[[ -z "$note" ]] && exit 0

timestamp="$(date '+%Y-%m-%d %H:%M')"
printf '\n- **[%s]** %s' "$timestamp" "$note" >> "$NOTES_FILE"

notify-send "Quick Note" "Saved: $note"
