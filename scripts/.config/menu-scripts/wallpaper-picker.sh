#!/usr/bin/env bash
set -euo pipefail

WALLPAPER_DIR="$HOME/.dots/hypr/.config/hypr/wallpapers"

if [[ ! -d "$WALLPAPER_DIR" ]]; then
    notify-send "Wallpaper Picker" "$WALLPAPER_DIR does not exist"
    exit 1
fi

mapfile -t images < <(find "$WALLPAPER_DIR" -maxdepth 2 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | sort)

if [[ ${#images[@]} -eq 0 ]]; then
    notify-send "Wallpaper Picker" "No images found in $WALLPAPER_DIR"
    exit 1
fi

choice="$(
    for img in "${images[@]}"; do
        name="$(realpath --relative-to="$WALLPAPER_DIR" "$img")"
        printf '%s\0icon\x1f%s\n' "$name" "$img"
    done | rofi -dmenu -p 'Wallpaper' -i -show-icons \
        -theme-str 'window { width: 920px; }' \
        -theme-str 'listview { lines: 5; }' \
        -theme-str 'element { padding: 8px 18px; spacing: 18px; }' \
        -theme-str 'element-icon { size: 160px; }'
)" || exit 0
[[ -z "$choice" ]] && exit 0

selected="$WALLPAPER_DIR/$choice"

if [[ ! -f "$selected" ]]; then
    notify-send "Wallpaper Picker" "$choice was not found"
    exit 1
fi

hyprctl hyprpaper wallpaper ",$selected"
notify-send "Wallpaper" "Set to $(basename "$selected")"
