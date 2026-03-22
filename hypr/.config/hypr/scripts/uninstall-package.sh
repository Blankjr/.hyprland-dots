#!/bin/sh
# Rofi-based wrapper to uninstall explicitly installed pacman packages.

pkg=$(pacman -Qqe | rofi -dmenu -p 'Uninstall' -i) || exit 0
[ -z "$pkg" ] && exit 0

kitty --class floating-term -e sh -c "sudo pacman -Rsn $pkg; echo; echo 'Press any key to close...'; read -r _"
