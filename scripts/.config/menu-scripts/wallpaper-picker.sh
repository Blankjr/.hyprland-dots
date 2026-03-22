#!/usr/bin/env bash
set -euo pipefail

WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"

if [[ ! -d "$WALLPAPER_DIR" ]]; then
    notify-send "Wallpaper Picker" "$WALLPAPER_DIR does not exist"
    exit 1
fi

mapfile -t images < <(find "$WALLPAPER_DIR" -maxdepth 2 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | sort)

if [[ ${#images[@]} -eq 0 ]]; then
    notify-send "Wallpaper Picker" "No images found in $WALLPAPER_DIR"
    exit 1
fi

names=()
for img in "${images[@]}"; do
    names+=("$(realpath --relative-to="$WALLPAPER_DIR" "$img")")
done

choice="$(printf '%s\n' "${names[@]}" | rofi -dmenu -p 'Wallpaper' -i)" || exit 0
[[ -z "$choice" ]] && exit 0

selected="$WALLPAPER_DIR/$choice"

pgrep -x swww-daemon >/dev/null || swww-daemon &

swww img "$selected" --transition-type grow --transition-duration 1
notify-send "Wallpaper" "Set to $(basename "$selected")"
