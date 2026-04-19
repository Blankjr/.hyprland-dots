#!/usr/bin/env bash
# Super+A: show/hide the AI companion (Claude / T3 chat).
# - If no AI window is running, spawn Claude (default) and show special:ai.
# - If an AI window exists but was moved off special:ai, yank it back so the
#   toggle works again, and ensure the overlay is visible.
# - Otherwise, plain toggle.

AI_CLASSES='["chrome-claude.ai__-Default","chrome-t3.chat__-Default"]'
CLAUDE_CMD='helium-browser --app=https://claude.ai'

special_visible() {
    hyprctl monitors -j | jq -e 'any(.[]; .specialWorkspace.name == "special:ai")' >/dev/null
}

clients=$(hyprctl clients -j)
ai_win=$(echo "$clients" | jq -r --argjson cls "$AI_CLASSES" \
    'map(select(.class as $c | $cls | index($c))) | first // empty')

if [[ -z "$ai_win" ]]; then
    special_visible || hyprctl dispatch togglespecialworkspace ai
    hyprctl dispatch exec "$CLAUDE_CMD"
    exit 0
fi

ai_ws=$(echo "$ai_win" | jq -r '.workspace.name')
ai_addr=$(echo "$ai_win" | jq -r '.address')

if [[ "$ai_ws" != "special:ai" ]]; then
    hyprctl dispatch movetoworkspacesilent "special:ai,address:$ai_addr"
    special_visible || hyprctl dispatch togglespecialworkspace ai
    exit 0
fi

hyprctl dispatch togglespecialworkspace ai
