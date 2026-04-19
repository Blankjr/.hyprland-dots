#!/usr/bin/env bash
# Usage: hide-ai-if-visible.sh <command> [args...]
#
# If special:ai is visible on any monitor, hide it and launch the given command
# with an explicit [workspace N] dispatch prefix so the new window can't
# inherit special:ai (plain togglespecialworkspace leaves focus stuck on the
# hidden AI window). If special:ai isn't visible, runs the command normally.

monitors=$(hyprctl monitors -j)
ai_mon=$(echo "$monitors" | jq -r 'first(.[] | select(.specialWorkspace.name == "special:ai") | .name) // empty')

if [[ -z "$ai_mon" ]]; then
    exec "$@"
fi

active_ws_name=$(hyprctl activeworkspace -j | jq -r '.name')
focused_mon=$(echo "$monitors" | jq -r 'first(.[] | select(.focused == true) | .name)')

# Target regular workspace for the new window: the underlying one on the AI
# monitor if the user was focused on the AI workspace itself, otherwise the
# currently focused regular workspace.
if [[ "$active_ws_name" == special:* ]]; then
    target_id=$(echo "$monitors" | jq -r --arg m "$ai_mon" 'first(.[] | select(.name == $m) | .activeWorkspace.id)')
else
    target_id=$(hyprctl activeworkspace -j | jq -r '.id')
fi

# togglespecialworkspace acts on the focused monitor — jump to the AI monitor
# to hit the right instance, then restore focus.
[[ "$focused_mon" != "$ai_mon" ]] && hyprctl dispatch focusmonitor "$ai_mon"
hyprctl dispatch togglespecialworkspace ai
[[ "$focused_mon" != "$ai_mon" ]] && hyprctl dispatch focusmonitor "$focused_mon"

hyprctl dispatch exec "[workspace $target_id] $*"
