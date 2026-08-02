#!/usr/bin/env bash
# Run the measured Qwen3.6 daily configuration without allowing model swap.

set -uo pipefail

readonly DATA_DIR="${LOCAL_QWEN_DATA_DIR:-${HOME}/.local/share/local-qwen}"
readonly BUILD_DIR="${LOCAL_QWEN_BUILD_DIR:-${DATA_DIR}/llama-cpp-turboquant/build-rx6700xt-vulkan/bin}"
readonly SERVER="${LOCAL_QWEN_SERVER:-${BUILD_DIR}/llama-server}"
readonly MODEL="${LOCAL_QWEN_MODEL:-${DATA_DIR}/models/Qwen3.6-35B-A3B-Q4_K_M.gguf}"
readonly NCMOE="${QWEN_NCMOE:-28}"
readonly CONTEXT="${QWEN_CONTEXT:-32768}"
readonly CACHE_K="${QWEN_CACHE_K:-q8_0}"
readonly CACHE_V="${QWEN_CACHE_V:-turbo3}"
readonly FLASH_ATTN="${QWEN_FLASH_ATTN:-on}"
readonly THREADS="${QWEN_THREADS:-6}"
readonly PORT="${QWEN_PORT:-8080}"
readonly MIN_FREE_MIB="${QWEN_MIN_FREE_MIB:-1536}"
readonly EXPECTED_PEAK_WORKLOAD_MIB="${QWEN_EXPECTED_PEAK_WORKLOAD_MIB:-7565}"
readonly ALLOW_LOW_HEADROOM="${QWEN_ALLOW_LOW_HEADROOM:-0}"
readonly NO_SWAP_SCOPE_ACTIVE="${LOCAL_QWEN_NO_SWAP_SCOPE_ACTIVE:-0}"
readonly SCRIPT_PATH="$(readlink -f -- "${BASH_SOURCE[0]}")"
readonly STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/local-qwen-${UID}"
readonly PID_FILE="${STATE_DIR}/launcher.pid"

server_pid=""
monitor_pid=""
gpu_device=""
guard_file=""
managed_pid_written=0

usage() {
    cat <<'EOF'
Usage: run-qwen.sh [start|stop|status]

With no command or with `start`, starts the measured Qwen3.6-35B-A3B
llama-server configuration on
http://127.0.0.1:8080. The process runs in a no-swap user scope and is stopped
if total free GPU memory falls below 1536 MiB.

Useful overrides:
  QWEN_CONTEXT=65536 QWEN_NCMOE=30
                              Use the measured safe 64K variant
  QWEN_NCMOE=N               Keep N MoE layers in CPU RAM (higher uses less VRAM)
  QWEN_PORT=PORT             Change the local listen port
  QWEN_MIN_FREE_MIB=MIB      Raise the runtime VRAM safety floor
  QWEN_ALLOW_LOW_HEADROOM=1  Bypass only the startup estimate, not the runtime guard
EOF
}

error() {
    printf 'run-qwen: %s\n' "$*" >&2
}

cleanup() {
    if [[ -n "$server_pid" ]] && kill -0 "$server_pid" 2>/dev/null; then
        terminate_process "$server_pid" || true
    fi
    if [[ -n "$monitor_pid" ]] && kill -0 "$monitor_pid" 2>/dev/null; then
        kill "$monitor_pid" 2>/dev/null || true
        wait "$monitor_pid" 2>/dev/null || true
    fi
    if ((managed_pid_written)) && [[ -r "$PID_FILE" ]] && \
        [[ "$(<"$PID_FILE")" == "$$" ]]; then
        rm -f -- "$PID_FILE"
    fi
}

terminate_process() {
    local pid="$1"
    local state
    local attempt

    kill "$pid" 2>/dev/null || true
    for ((attempt = 0; attempt < 20; attempt++)); do
        [[ -r "/proc/${pid}/stat" ]] || break
        state="$(awk '{ print $3 }' "/proc/${pid}/stat" 2>/dev/null)"
        [[ "$state" == "Z" ]] && break
        sleep 0.25
    done
    if [[ -r "/proc/${pid}/stat" ]]; then
        state="$(awk '{ print $3 }' "/proc/${pid}/stat" 2>/dev/null)"
        [[ "$state" == "Z" ]] || kill -KILL "$pid" 2>/dev/null || true
    fi
    wait "$pid" 2>/dev/null
}

trap cleanup EXIT INT TERM

init_state_dir() {
    mkdir -p -- "$STATE_DIR" && chmod 700 "$STATE_DIR"
}

read_managed_pid() {
    local pid

    [[ -r "$PID_FILE" ]] || return 1
    IFS= read -r pid < "$PID_FILE"
    [[ "$pid" =~ ^[0-9]+$ ]] || return 1
    printf '%s\n' "$pid"
}

is_managed_launcher() {
    local pid="$1"
    local argument
    local -a arguments=()

    kill -0 "$pid" 2>/dev/null || return 1
    mapfile -d '' -t arguments < "/proc/${pid}/cmdline" 2>/dev/null || return 1
    for argument in "${arguments[@]}"; do
        [[ "$argument" == "$SCRIPT_PATH" ]] && return
    done
    return 1
}

stop_managed_launcher() {
    local pid
    local attempt

    init_state_dir || {
        error "could not initialize runtime state: ${STATE_DIR}"
        return 1
    }
    if ! pid="$(read_managed_pid)" || ! is_managed_launcher "$pid"; then
        if command -v curl >/dev/null 2>&1 && \
            curl --fail --silent --max-time 1 "http://127.0.0.1:${PORT}/health" >/dev/null 2>&1; then
            error "Qwen is running without a managed launcher PID; stop its terminal process"
            return 1
        fi
        printf 'Qwen server is already stopped.\n'
        return
    fi

    kill "$pid"
    for ((attempt = 0; attempt < 120; attempt++)); do
        if ! kill -0 "$pid" 2>/dev/null; then
            printf 'Qwen server stopped.\n'
            return
        fi
        sleep 0.25
    done

    error "managed Qwen launcher ${pid} did not stop within 30 seconds"
    return 1
}

show_status() {
    local pid

    if pid="$(read_managed_pid)" && is_managed_launcher "$pid"; then
        printf 'Server: running (managed, PID %s)\n' "$pid"
        printf 'API: http://127.0.0.1:%s\n' "$PORT"
    elif command -v curl >/dev/null 2>&1 && \
        curl --fail --silent --max-time 1 "http://127.0.0.1:${PORT}/health" >/dev/null 2>&1; then
        printf 'Server: running (unmanaged)\n'
        printf 'API: http://127.0.0.1:%s\n' "$PORT"
    else
        printf 'Server: stopped\n'
    fi
}

enter_no_swap_scope() {
    [[ "$NO_SWAP_SCOPE_ACTIVE" == "1" ]] && return
    command -v systemd-run >/dev/null 2>&1 || {
        error "systemd-run is required to prevent model inference from using swap"
        return 1
    }

    exec systemd-run \
        --user \
        --scope \
        --quiet \
        --expand-environment=no \
        -p MemorySwapMax=0 \
        --setenv=LOCAL_QWEN_NO_SWAP_SCOPE_ACTIVE=1 \
        "$0" "$@"
}

find_gpu_device() {
    local candidate

    for candidate in /sys/class/drm/card*/device; do
        [[ -r "${candidate}/vendor" && -r "${candidate}/device" ]] || continue
        if [[ "$(<"${candidate}/vendor")" == "0x1002" && \
            "$(<"${candidate}/device")" == "0x73df" ]]; then
            gpu_device="$candidate"
            return
        fi
    done

    error "RX 6700 XT sysfs device (1002:73df) was not found"
    return 1
}

monitor_vram() {
    local pid="$1"
    local free_mib
    local total_bytes
    local used_bytes

    total_bytes="$(<"${gpu_device}/mem_info_vram_total")"
    while kill -0 "$pid" 2>/dev/null; do
        used_bytes="$(<"${gpu_device}/mem_info_vram_used")"
        free_mib=$(((total_bytes - used_bytes) / 1048576))
        if ((free_mib < MIN_FREE_MIB)); then
            printf 'free VRAM fell below %s MiB; server stopped\n' "$MIN_FREE_MIB" > "$guard_file"
            terminate_process "$pid" || true
            return
        fi
        sleep 0.25
    done
}

main() {
    local action="${1:-start}"
    local current_free_mib
    local total_bytes
    local used_bytes
    local required_free_mib
    local server_status=0
    local -a command

    if [[ "$action" == "-h" || "$action" == "--help" || "$action" == "help" ]]; then
        usage
        return
    fi
    if (($# > 1)); then
        error "unexpected argument: $2"
        usage >&2
        return 2
    fi

    case "$action" in
        stop)
            stop_managed_launcher
            return
            ;;
        status)
            show_status
            return
            ;;
        start) ;;
        *)
            error "unknown command: ${action}"
            usage >&2
            return 2
            ;;
    esac

    enter_no_swap_scope "$@" || return 1
    [[ -x "$SERVER" ]] || {
        error "llama-server not found or not executable: ${SERVER}"
        return 1
    }
    [[ -r "$MODEL" ]] || {
        error "model not found: ${MODEL}"
        return 1
    }
    (( $(stat -c '%s' "$MODEL") == 20419565568 )) || {
        error "model size does not match the verified Q4_K_M file: ${MODEL}"
        return 1
    }
    [[ "$NCMOE" =~ ^[0-9]+$ && "$CONTEXT" =~ ^[0-9]+$ && \
        "$THREADS" =~ ^[0-9]+$ && "$PORT" =~ ^[0-9]+$ ]] || {
        error "ncmoe, context, threads, and port must be non-negative integers"
        return 2
    }
    find_gpu_device || return 1

    if ((CONTEXT >= 65536 && NCMOE < 30)) && [[ "$ALLOW_LOW_HEADROOM" != "1" ]]; then
        error "64K with ncmoe ${NCMOE} crossed the 1536 MiB guard during measurement"
        error "use QWEN_CONTEXT=65536 QWEN_NCMOE=30"
        return 1
    fi

    if command -v curl >/dev/null 2>&1 && \
        curl --fail --silent --max-time 1 "http://127.0.0.1:${PORT}/health" >/dev/null 2>&1; then
        error "another llama-server is already listening on 127.0.0.1:${PORT}"
        return 1
    fi

    init_state_dir || {
        error "could not initialize runtime state: ${STATE_DIR}"
        return 1
    }
    if [[ "$NO_SWAP_SCOPE_ACTIVE" == "1" ]]; then
        printf '%s\n' "$$" > "$PID_FILE"
        managed_pid_written=1
    fi

    total_bytes="$(<"${gpu_device}/mem_info_vram_total")"
    used_bytes="$(<"${gpu_device}/mem_info_vram_used")"
    current_free_mib=$(((total_bytes - used_bytes) / 1048576))
    required_free_mib=$((EXPECTED_PEAK_WORKLOAD_MIB + MIN_FREE_MIB))
    if ((EXPECTED_PEAK_WORKLOAD_MIB > 0 && current_free_mib < required_free_mib)) && \
        [[ "$ALLOW_LOW_HEADROOM" != "1" ]]; then
        error "only ${current_free_mib} MiB VRAM is free; this configuration needs about ${required_free_mib} MiB"
        error "close a GPU-heavy application, raise QWEN_NCMOE, or explicitly set QWEN_ALLOW_LOW_HEADROOM=1"
        return 1
    fi

    command=(
        "$SERVER"
        -m "$MODEL"
        -ngl all
        -ncmoe "$NCMOE"
        -c "$CONTEXT"
        -ctk "$CACHE_K"
        -ctv "$CACHE_V"
        -fa "$FLASH_ATTN"
        -fit off
        -sm none
        --mmap
        -np 1
        -t "$THREADS"
        -tb "$THREADS"
        --jinja
        --cache-ram 0
        --ctx-checkpoints 0
        --no-cache-idle-slots
        --host 127.0.0.1
        --port "$PORT"
    )

    guard_file="${XDG_RUNTIME_DIR:-/tmp}/run-qwen-${UID}.guard"
    : > "$guard_file"
    printf 'Starting Qwen3.6 on http://127.0.0.1:%s (ctx=%s, ncmoe=%s, K=%s, V=%s, FA=%s)\n' \
        "$PORT" "$CONTEXT" "$NCMOE" "$CACHE_K" "$CACHE_V" "$FLASH_ATTN"
    printf 'Current VRAM free: %s MiB; enforced floor: %s MiB\n' "$current_free_mib" "$MIN_FREE_MIB"

    "${command[@]}" &
    server_pid=$!
    monitor_vram "$server_pid" &
    monitor_pid=$!
    wait "$server_pid" || server_status=$?
    server_pid=""
    kill "$monitor_pid" 2>/dev/null || true
    wait "$monitor_pid" 2>/dev/null || true
    monitor_pid=""

    if [[ -s "$guard_file" ]]; then
        error "$(<"$guard_file")"
        return 1
    fi
    return "$server_status"
}

main "$@"
