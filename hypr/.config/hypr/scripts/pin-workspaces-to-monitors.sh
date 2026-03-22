#!/bin/sh
# Move workspaces 1–5 and 6–10 onto the outputs matched here (same logic as hyprland.conf).
# Rules alone do not relocate workspaces that already exist on the wrong monitor; run this after
# login or `hyprctl reload` if numbering drifts.
sleep 0.4
j=$(hyprctl monitors -j) || exit 0
MON_MAIN=$(printf '%s\n' "$j" | jq -r '.[] | select(.description | contains("Mi Monitor")) | .name' | head -n1)
MON_LEFT=$(printf '%s\n' "$j" | jq -r '.[] | select(.description | contains("EW3270U")) | .name' | head -n1)
[ -n "$MON_MAIN" ] && [ -n "$MON_LEFT" ] && [ "$MON_MAIN" != "$MON_LEFT" ] || exit 0

sep=
batch=
for w in 1 2 3 4 5; do
	batch="${batch}${sep}dispatch moveworkspacetomonitor ${w} ${MON_MAIN}"
	sep="; "
done
for w in 6 7 8 9 10; do
	batch="${batch}${sep}dispatch moveworkspacetomonitor ${w} ${MON_LEFT}"
	sep="; "
done
hyprctl --batch -r "$batch"
