#!/usr/bin/env bash
set -euo pipefail

VIDEO_DIR="${VIDEO_DIR:-$HOME/Videos}"
VIDEO_EXTENSIONS="mkv|mp4|avi|webm|m4v|flv|mov|ts"

browse() {
    local dir="$1"

    while true; do
        local entries=()

        [[ "$dir" != "$VIDEO_DIR" ]] && entries+=(".. (back)")

        while IFS= read -r -d '' entry; do
            entries+=("$(basename "$entry")")
        done < <(find "$dir" -mindepth 1 -maxdepth 1 \( -type d -o -type f -regex ".*\.\(${VIDEO_EXTENSIONS//|/\\|}\)" \) -print0 | sort -z)

        if [[ ${#entries[@]} -eq 0 ]]; then
            notify-send "Video Browser" "No videos or folders found in $(basename "$dir")"
            return
        fi

        local choice
        choice="$(printf '%s\n' "${entries[@]}" | rofi -dmenu -p "$(basename "$dir")" -i)" || return

        [[ -z "$choice" ]] && return

        if [[ "$choice" == ".. (back)" ]]; then
            dir="$(dirname "$dir")"
            continue
        fi

        local selected="$dir/$choice"

        if [[ -d "$selected" ]]; then
            dir="$selected"
        elif [[ -f "$selected" ]]; then
            exec mpv "$selected"
        fi
    done
}

if [[ ! -d "$VIDEO_DIR" ]]; then
    notify-send "Video Browser" "$VIDEO_DIR does not exist"
    exit 1
fi

browse "$VIDEO_DIR"
