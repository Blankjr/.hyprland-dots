#!/bin/bash

PASSWORD=$(rofi -dmenu -password -p " " \
    -theme-str 'window { width: 360px; } listview { lines: 0; } entry { placeholder: "Password..."; }')

[ -z "$PASSWORD" ] && exit 0

if ! echo "$PASSWORD" | sudo -S -v 2>/dev/null; then
    notify-send -u critical " Update" "Authentication failed"
    exit 1
fi

ASKPASS=$(mktemp /tmp/.update-askpass.XXXXXX)
chmod 700 "$ASKPASS"
printf '#!/bin/bash\nprintf "%%s" %q\n' "$PASSWORD" > "$ASKPASS"
unset PASSWORD

cleanup() { rm -f "$ASKPASS"; }
trap cleanup EXIT

notify-send " Update" "System update started..."

export SUDO_ASKPASS="$ASKPASS"
yay --noconfirm --sudoloop --sudoflags "-A" > /tmp/yay-update.log 2>&1
exit_code=$?

cleanup
trap - EXIT

pkill -RTMIN+8 waybar

if [ $exit_code -eq 0 ]; then
    notify-send " Update" "System update completed successfully"
else
    notify-send -u critical " Update" "Update failed — check /tmp/yay-update.log"
fi
