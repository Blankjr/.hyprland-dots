#!/usr/bin/env bash
# Pick a random wallpaper from ~/.config/hypr/wallpapers/ and set it via hyprpaper

WALLPAPER_DIR="$HOME/.dots/hypr/.config/hypr/wallpapers"

mapfile -t walls < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.webp' \))

if [[ ${#walls[@]} -eq 0 ]]; then
    echo "No wallpapers found in $WALLPAPER_DIR" >&2
    exit 1
fi

pick="${walls[RANDOM % ${#walls[@]}]}"

# Wait for hyprpaper to be ready
for i in $(seq 1 10); do
    hyprctl hyprpaper wallpaper ",$pick" 2>/dev/null && break
    sleep 0.5
done
