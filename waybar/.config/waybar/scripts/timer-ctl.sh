#!/usr/bin/env bash
# Rofi: start a countdown (writes waybar state) or cancel an active timer

set -euo pipefail

STATE="${XDG_RUNTIME_DIR:-/tmp}/waybar-timer"

parse_duration() {
    local input="$1" total=0
    if [[ "$input" =~ ^([0-9]+)$ ]]; then
        total=$(( ${BASH_REMATCH[1]} * 60 ))
    else
        [[ "$input" =~ ([0-9]+)h ]] && total=$(( total + ${BASH_REMATCH[1]} * 3600 ))
        [[ "$input" =~ ([0-9]+)m ]] && total=$(( total + ${BASH_REMATCH[1]} * 60 ))
        [[ "$input" =~ ([0-9]+)s ]] && total=$(( total + ${BASH_REMATCH[1]} ))
    fi
    echo "$total"
}

# Prints "MM:SS<TAB>label" when a timer is active; exit 1 otherwise.
remaining_info() {
    [[ -f "$STATE" ]] || return 1
    local end_line label_line end label now left mm ss line
    end_line=""
    label_line=""
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^end= ]] && end_line="$line"
        [[ "$line" =~ ^label= ]] && label_line="$line"
    done < "$STATE"
    end="${end_line#end=}"
    label="${label_line#label=}"
    now="$(date +%s)"
    [[ -n "$end" ]] && [[ "$end" =~ ^[0-9]+$ ]] && (( end > now )) || return 1
    left=$(( end - now ))
    mm=$(( left / 60 ))
    ss=$(( left % 60 ))
    printf -v _rem '%d:%02d' "$mm" "$ss"
    printf '%s\t%s' "$_rem" "$label"
    return 0
}

write_timer() {
    local seconds=$1
    local label=$2
    local end=$(( $(date +%s) + seconds ))
    umask 077
    printf 'end=%s\nlabel=%s\n' "$end" "$label" > "$STATE"
}

if info="$(remaining_info 2>/dev/null)"; then
    IFS=$'\t' read -r rem lbl <<< "$info"
    choice="$(printf 'Cancel' | rofi -dmenu -p "Timer ${rem} (${lbl:-…})" -i)" || exit 0
    [[ "$choice" == "Cancel" ]] && rm -f "$STATE" && notify-send "Timer" "Cancelled" && exit 0
    exit 0
fi

choice="$(printf '1m\n5m\n10m\n15m\n30m\n1h\nCustom' | rofi -dmenu -p 'Timer' -i)" || exit 0
[[ -z "$choice" ]] && exit 0

if [[ "$choice" == "Custom" ]]; then
    choice="$(rofi -dmenu -p 'Duration (e.g. 5m, 1h30m)' -l 0 \
        -theme-str 'listview { lines: 0; }')" || exit 0
    [[ -z "$choice" ]] && exit 0
fi

seconds="$(parse_duration "$choice")"

if [[ "$seconds" -le 0 ]]; then
    notify-send "Timer" "Invalid duration: $choice"
    exit 1
fi

write_timer "$seconds" "$choice"
notify-send "Timer" "Started: $choice"
