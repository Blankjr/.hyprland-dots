#!/usr/bin/env bash

set -uo pipefail

AUTH_FILE="${CODEX_AUTH_FILE:-$HOME/.codex/auth.json}"
ENDPOINT="https://chatgpt.com/backend-api/wham/usage"

error_json() {
    jq -cn --arg message "$1" '{
        text: "CODEX ?",
        tooltip: $message,
        class: "error",
        percentage: 0
    }'
}

if [[ ! -r "$AUTH_FILE" ]]; then
    error_json "Codex authentication not found; run codex login"
    exit 0
fi

if ! token="$(jq -er '.tokens.access_token // empty' "$AUTH_FILE" 2>/dev/null)"; then
    error_json "No Codex access token found; run codex login"
    exit 0
fi

if ! response="$({
    curl --silent --show-error --fail \
        --max-time 8 \
        -H "Authorization: Bearer $token" \
        -H "Accept: application/json" \
        -H "User-Agent: codex-waybar/0.1" \
        "$ENDPOINT"
} 2>/dev/null)"; then
    error_json "Could not fetch Codex usage; authentication may need refreshing"
    exit 0
fi

now="$(date +%s)"

if ! output="$(jq -c --argjson now "$now" '
    def windows:
        [
            .rate_limit.primary_window?,
            .rate_limit.secondary_window?
        ]
        | map(select(type == "object"));

    def window_near($seconds):
        [
            windows[]
            | select(
                (.limit_window_seconds // 0) >= ($seconds * 0.95)
                and (.limit_window_seconds // 0) <= ($seconds * 1.05)
            )
        ]
        | .[0] // null;

    def left($window):
        if $window == null or $window.used_percent == null then
            null
        else
            (100 - $window.used_percent)
            | [0, ., 100]
            | sort
            | .[1]
            | round
        end;

    def reset_at($window):
        if $window == null then
            null
        elif ($window.reset_at // 0) > 0 then
            $window.reset_at
        elif ($window.reset_after_seconds // 0) > 0 then
            $now + $window.reset_after_seconds
        else
            null
        end;

    def remaining($window):
        reset_at($window)
        | if . == null then null else [0, (. - $now)] | max end;

    def reset_date($window; $format):
        reset_at($window)
        | if . == null then "unknown" else strflocaltime($format) end;

    def duration($seconds):
        if $seconds == null then
            "unknown"
        elif $seconds >= 86400 then
            "\(($seconds / 86400) | floor)d \((($seconds % 86400) / 3600) | floor)h"
        elif $seconds >= 3600 then
            "\(($seconds / 3600) | floor)h \((($seconds % 3600) / 60) | floor)m"
        else
            "\([0, (($seconds / 60) | floor)] | max)m"
        end;

    def window_label($name; $window; $value):
        if $value == null then
            null
        else
            (remaining($window)) as $reset_in
            | "\($name) \($value)%"
                + (if $reset_in == null then "" else " (\(duration($reset_in)))" end)
        end;

    def detail($name; $window; $value):
        if $value == null then
            null
        else
            "\($name): \($value)% left · resets \(reset_date($window; "%d.%m.%Y %H:%M")) (in \(duration(remaining($window))))"
        end;

    (window_near(18000)) as $five
    | (window_near(604800)) as $week
    | (left($five)) as $five_left
    | (left($week)) as $week_left
    | [window_label("5H"; $five; $five_left), window_label("7D"; $week; $week_left)]
        | map(select(. != null)) as $labels
    | [detail("5-hour"; $five; $five_left), detail("Weekly"; $week; $week_left)]
        | map(select(. != null)) as $details
    | [$five_left, $week_left]
        | map(select(. != null)) as $remaining
    | ($remaining | min // 100) as $lowest
    | {
        text: (
            if ($labels | length) == 0 then ""
            else "CODEX " + ($labels | join(" / ")) + " left"
            end
        ),
        tooltip: (
            if ($details | length) == 0 then "No active Codex usage windows"
            else $details | join("\n")
            end
        ),
        class: (
            if ($labels | length) == 0 then "unavailable"
            elif $lowest <= 10 then "critical"
            elif $lowest <= 25 then "warning"
            else "normal"
            end
        ),
        percentage: $lowest
    }
' <<< "$response" 2>/dev/null)"; then
    error_json "Unexpected response from the Codex usage endpoint"
    exit 0
fi

printf '%s\n' "$output"
