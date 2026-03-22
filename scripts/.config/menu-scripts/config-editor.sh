#!/usr/bin/env bash
set -euo pipefail

EDITOR="${EDITOR:-nvim}"

declare -A configs=(
    ["Hyprland"]="$HOME/.config/hypr/hyprland.conf"
    ["Hyprland Keybindings"]="$HOME/.config/hypr/conf.d/keybindings.conf"
    ["Hyprland Window Rules"]="$HOME/.config/hypr/conf.d/windowrules.conf"
    ["Hyprland Appearance"]="$HOME/.config/hypr/conf.d/appearance.conf"
    ["Hyprland Monitors"]="$HOME/.config/hypr/conf.d/monitors.conf"
    ["Waybar Config"]="$HOME/.config/waybar/config.jsonc"
    ["Waybar Style"]="$HOME/.config/waybar/style.css"
    ["Rofi"]="$HOME/.config/rofi/config.rasi"
    ["Kitty"]="$HOME/.config/kitty/kitty.conf"
    ["Neovim"]="$HOME/.config/nvim/init.lua"
    ["Mako"]="$HOME/.config/mako/config"
    ["Fish"]="$HOME/.config/fish/config.fish"
    ["SSH"]="$HOME/.ssh/config"
)

choice="$(printf '%s\n' "${!configs[@]}" | sort | rofi -dmenu -p 'Edit Config' -i)" || exit 0
[[ -z "$choice" ]] && exit 0

file="${configs[$choice]}"

if [[ ! -f "$file" ]]; then
    notify-send "Config Editor" "File not found: $file"
    exit 1
fi

exec kitty -- $EDITOR "$file"
