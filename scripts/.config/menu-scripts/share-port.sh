#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="/tmp/share-port"
PORT_FILE="$STATE_DIR/port"
COMMENT_FILE="$STATE_DIR/comment"
ROOT_PID_FILE="$STATE_DIR/root-pid"
URL_FILE="$STATE_DIR/url"
MANUAL_ENTRY="Enter port manually..."
STOP_ENTRY="Stop active share"

mkdir -p "$STATE_DIR"

notify() {
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send "Share Port" "$1"
}

have_rofi() {
    command -v rofi >/dev/null 2>&1
}

have_tty() {
    [[ -t 0 && -t 1 ]]
}

iptables_path() {
    command -v iptables 2>/dev/null || true
}

is_valid_port() {
    [[ "${1:-}" =~ ^[0-9]+$ ]] && (( $1 >= 1 && $1 <= 65535 ))
}

get_ip() {
    local ip

    if [[ -n "${SHARE_PORT_INTERFACE:-}" ]]; then
        ip="$(ip -4 -brief addr show dev "$SHARE_PORT_INTERFACE" 2>/dev/null | awk '{print $3}' | cut -d/ -f1 | head -n1)"
        if [[ -n "${ip:-}" ]]; then
            printf '%s\n' "$ip"
            return
        fi
    fi

    ip="$(ip -4 route show default 2>/dev/null | awk '
        {
            iface = ""
            src = ""
            for (i = 1; i <= NF; i++) {
                if ($i == "dev") {
                    iface = $(i + 1)
                }
                if ($i == "src") {
                    src = $(i + 1)
                }
            }
            if (iface !~ /^(wg|tun|tap|tailscale|zt)/ && src != "") {
                print src
                exit
            }
        }
    ')"
    if [[ -n "${ip:-}" ]]; then
        printf '%s\n' "$ip"
        return
    fi

    ip="$(ip -4 -brief addr 2>/dev/null | awk '
        $1 !~ /^(lo|wg|tun|tap|tailscale|zt|docker|br-|veth)/ {
            split($3, parts, "/")
            candidate = parts[1]
            if (candidate ~ /^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)/) {
                print candidate
                exit
            }
        }
    ')"
    if [[ -n "${ip:-}" ]]; then
        printf '%s\n' "$ip"
        return
    fi

    hostname -I 2>/dev/null | awk '{print $1}'
}

listener_exists() {
    local port=$1
    ss -Hltn "( sport = :$port )" 2>/dev/null | grep -q .
}

listener_is_loopback_only() {
    local port=$1
    local lines
    lines="$(ss -Hltn "( sport = :$port )" 2>/dev/null || true)"
    [[ -n "$lines" ]] || return 1

    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        case "$(awk '{print $4}' <<<"$line")" in
            127.*:*|'[::1]:'*|::1:*)
                ;;
            *)
                return 1
                ;;
        esac
    done <<<"$lines"

    return 0
}

detect_listener_options() {
    ss -Hlnpt 2>/dev/null | awk '
        $1 ~ /^tcp/ {
            local_addr = $4
            port = local_addr
            sub(/^.*:/, "", port)

            process = "unknown"
            if (match($0, /users:\(\("([^"]+)"/, match_data)) {
                process = match_data[1]
            }

            scope = "lan"
            if (local_addr ~ /(127\.0\.0\.1|\[::1\]|::1):/) {
                scope = "loopback"
            }

            printf "%05d\t%s\t%s\t%s\n", port, port, process, scope
        }
    ' | sort -u | awk -F '\t' '
        {
            label = $2 " (" $3 ")"
            if ($4 == "loopback") {
                label = label " [localhost only]"
            }
            print label
        }
    '
}

prompt_secret() {
    local prompt=$1
    local secret

    if ! have_rofi; then
        return 1
    fi

    secret="$(printf '' | rofi -dmenu -password -p "$prompt")" || return 1
    [[ -n "$secret" ]] || return 1
    printf '%s\n' "$secret"
}

prompt_port() {
    local selection port
    local -a options=()

    while IFS= read -r line; do
        [[ -n "$line" ]] && options+=("$line")
    done < <(detect_listener_options)

    if is_active; then
        options=("$STOP_ENTRY" "${options[@]}")
    fi
    options+=("$MANUAL_ENTRY")

    if have_rofi; then
        selection="$(
            printf '%s\n' "${options[@]}" | rofi -dmenu -p 'Share Port' -i
        )" || return 1
    elif have_tty; then
        printf 'Available listeners:\n' >&2
        printf '  %s\n' "${options[@]}" >&2
        read -r -p 'Share Port: ' selection
    else
        return 1
    fi

    [[ -n "$selection" ]] || return 1

    if [[ "$selection" == "$STOP_ENTRY" ]]; then
        printf '%s\n' "$STOP_ENTRY"
        return 0
    fi

    if [[ "$selection" == "$MANUAL_ENTRY" ]]; then
        if have_rofi; then
            port="$(printf '' | rofi -dmenu -p 'TCP Port')" || return 1
        elif have_tty; then
            read -r -p 'TCP Port: ' port
        else
            return 1
        fi
        [[ -n "$port" ]] || return 1
        printf '%s\n' "$port"
        return 0
    fi

    printf '%s\n' "${selection%% *}"
}

ensure_bash() {
    if [[ -z "${BASH_VERSION:-}" ]]; then
        echo "Run this script with bash, not sh." >&2
        exit 1
    fi
}

ensure_sudo_session() {
    local password

    if sudo -n true 2>/dev/null; then
        return 0
    fi

    if have_tty; then
        sudo -v
        return 0
    fi

    password="$(prompt_secret 'sudo password')" || {
        echo "Need sudo authentication to manage the firewall rule." >&2
        return 1
    }

    printf '%s\n' "$password" | sudo -S -p '' -v >/dev/null
}

firewall_rule_exists() {
    local port=$1
    local comment=$2
    local iptables_bin
    iptables_bin="$(iptables_path)"
    [[ -n "$iptables_bin" ]] || return 1

    "$iptables_bin" -C INPUT -p tcp --dport "$port" -m comment --comment "$comment" -j ACCEPT >/dev/null 2>&1
}

open_firewall_port() {
    local port=$1
    local comment=$2
    local iptables_bin
    iptables_bin="$(iptables_path)"
    [[ -n "$iptables_bin" ]] || {
        echo "iptables not found" >&2
        return 1
    }

    firewall_rule_exists "$port" "$comment" || "$iptables_bin" -I INPUT 1 -p tcp --dport "$port" -m comment --comment "$comment" -j ACCEPT
}

close_firewall_port() {
    local port=$1
    local comment=$2
    local iptables_bin
    iptables_bin="$(iptables_path)"
    [[ -n "$iptables_bin" ]] || return 0

    while firewall_rule_exists "$port" "$comment"; do
        "$iptables_bin" -D INPUT -p tcp --dport "$port" -m comment --comment "$comment" -j ACCEPT >/dev/null 2>&1 || break
    done
}

cleanup_state() {
    rm -f "$PORT_FILE" "$COMMENT_FILE" "$ROOT_PID_FILE" "$URL_FILE"
}

is_active() {
    [[ -f "$ROOT_PID_FILE" ]] || return 1

    local pid
    pid="$(<"$ROOT_PID_FILE")"
    kill -0 "$pid" 2>/dev/null
}

cleanup_stale_state() {
    if ! is_active; then
        cleanup_state
    fi
}

root_hold() {
    local port=$1
    local comment=$2

    if [[ $EUID -ne 0 ]]; then
        echo "root-hold must run as root" >&2
        exit 1
    fi

    trap 'close_firewall_port "$port" "$comment"; cleanup_state' EXIT INT TERM

    open_firewall_port "$port" "$comment"
    printf '%s\n' "$$" > "$ROOT_PID_FILE"

    while true; do
        sleep 3600 &
        wait $!
    done
}

stop_share() {
    local port

    cleanup_stale_state

    if ! [[ -f "$ROOT_PID_FILE" ]]; then
        echo "No active share." >&2
        return 1
    fi

    port="$(<"$PORT_FILE" 2>/dev/null || true)"
    ensure_sudo_session
    sudo -n kill "$(cat "$ROOT_PID_FILE")"

    for _ in $(seq 1 20); do
        if ! is_active; then
            cleanup_state
            notify "Stopped sharing TCP port ${port:-unknown}"
            return 0
        fi
        sleep 0.1
    done

    cleanup_stale_state
}

start_share() {
    local port=$1
    local comment url root_pid

    cleanup_stale_state

    if is_active; then
        echo "share-port is already active. Stop the running share first." >&2
        return 1
    fi

    if ! is_valid_port "$port"; then
        echo "Invalid port: ${port:-<empty>}" >&2
        return 1
    fi

    if ! listener_exists "$port"; then
        echo "Nothing is listening on TCP port $port" >&2
        return 1
    fi

    if listener_is_loopback_only "$port"; then
        echo "TCP port $port is bound to localhost only. Start the dev server on 0.0.0.0 first." >&2
        return 1
    fi

    ensure_sudo_session

    comment="share-port:$port:$$"
    printf '%s\n' "$port" > "$PORT_FILE"
    printf '%s\n' "$comment" > "$COMMENT_FILE"

    sudo -n "$0" root-hold "$port" "$comment" >/dev/null 2>&1 &

    for _ in $(seq 1 20); do
        if [[ -f "$ROOT_PID_FILE" ]]; then
            root_pid="$(<"$ROOT_PID_FILE")"
            if kill -0 "$root_pid" 2>/dev/null; then
                break
            fi
        fi
        sleep 0.1
    done

    if ! is_active; then
        cleanup_state
        echo "Failed to start the firewall helper." >&2
        return 1
    fi

    url="http://$(get_ip):$port"
    printf '%s\n' "$url" > "$URL_FILE"
    notify "Opened TCP port $port at $url"
    printf 'Sharing TCP port %s at %s\n' "$port" "$url"
}

wait_forever() {
    trap 'stop_share >/dev/null 2>&1 || true; exit 0' EXIT INT TERM
    printf 'Press Ctrl+C to stop and remove the firewall rule.\n'

    while true; do
        sleep 3600 &
        wait $!
    done
}

usage() {
    cat <<'EOF'
Usage:
  share-port.sh [port]
  share-port.sh stop
  share-port.sh status
  share-port.sh menu

Examples:
  share-port.sh 4200
  share-port.sh stop

If you run it in a terminal with a port, it stays active until Ctrl+C.
If you run `menu`, it uses rofi to choose a port and starts detached.
EOF
}

main() {
    local cmd=${1:-}
    local port

    ensure_bash

    case "$cmd" in
        root-hold)
            root_hold "${2:-}" "${3:-}"
            ;;
        stop)
            stop_share
            ;;
        status)
            cleanup_stale_state
            if is_active; then
                printf 'active %s %s\n' "$(cat "$PORT_FILE")" "$(cat "$URL_FILE" 2>/dev/null || true)"
            else
                printf 'inactive\n'
            fi
            ;;
        menu)
            port="$(prompt_port)" || exit 0
            if [[ "$port" == "$STOP_ENTRY" ]]; then
                stop_share
                exit 0
            fi
            start_share "$port"
            ;;
        -h|--help)
            usage
            ;;
        "")
            if have_rofi && ! have_tty; then
                port="$(prompt_port)" || exit 0
                if [[ "$port" == "$STOP_ENTRY" ]]; then
                    stop_share
                    exit 0
                fi
                start_share "$port"
            else
                usage
                exit 1
            fi
            ;;
        *)
            start_share "$cmd"
            if have_tty; then
                wait_forever
            fi
            ;;
    esac
}

main "$@"
