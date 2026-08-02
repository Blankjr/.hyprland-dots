#!/usr/bin/env bash
# Reproducible, guarded Qwen3.6/TurboQuant Vulkan benchmark matrix.

set -uo pipefail

readonly DATA_DIR="${LOCAL_QWEN_DATA_DIR:-${HOME}/.local/share/local-qwen}"
readonly BUILD_DIR="${LOCAL_QWEN_BUILD_DIR:-${DATA_DIR}/llama-cpp-turboquant/build-rx6700xt-vulkan/bin}"
readonly SERVER="${LOCAL_QWEN_SERVER:-${BUILD_DIR}/llama-server}"
readonly MODEL="${LOCAL_QWEN_MODEL:-${DATA_DIR}/models/Qwen3.6-35B-A3B-Q4_K_M.gguf}"
readonly STATE_ROOT="${XDG_STATE_HOME:-${HOME}/.local/state}/local-qwen/benchmarks"
readonly PORT="${QWEN_BENCHMARK_PORT:-18080}"
readonly THREADS="${QWEN_THREADS:-6}"
readonly MIN_FREE_MIB="${QWEN_MIN_FREE_MIB:-1536}"
readonly START_TIMEOUT_SECONDS="${QWEN_START_TIMEOUT_SECONDS:-600}"
readonly REQUEST_TIMEOUT_SECONDS="${QWEN_REQUEST_TIMEOUT_SECONDS:-900}"
readonly DESKTOP_NOTE="${QWEN_DESKTOP_NOTE:-not_directly_observed}"
readonly MIN_MODEL_BYTES="${QWEN_MIN_MODEL_BYTES:-15000000000}"
readonly NO_SWAP_SCOPE_ACTIVE="${LOCAL_QWEN_NO_SWAP_SCOPE_ACTIVE:-0}"

active_server_pid=""
active_sampler_pid=""
gpu_device=""
run_dir=""
results_file=""

usage() {
    cat <<'EOF'
Usage: benchmark-qwen.sh [matrix|A|B|C|D|E|F|G|H|I|J|list]...

Commands:
  matrix  Run A/B/C, conditionally D, then TurboQuant/context/FA comparisons
  A-D     32K q8_0/q8_0, FA on, ncmoe 30/28/26/24
  E       Best safe ncmoe, 32K q8_0/turbo3, FA on
  I       One ncmoe step below E, 32K q8_0/turbo3, FA on
  F       Best q8 baseline ncmoe, 64K q8_0/turbo3, FA on
  J       Best 32K TurboQuant ncmoe, 64K q8_0/turbo3, FA on
  G-H     Best safe ncmoe, 32K q8_0/f16, FA off/on comparison
  list    Print the matrix without running it

The matrix derives comparison ncmoe values automatically. For isolated cases,
set QWEN_BEST_NCMOE and, where applicable, QWEN_FA_NCMOE or QWEN_TURBO_NCMOE.
Results and raw logs are written below ~/.local/state/local-qwen/benchmarks/.
The monitor terminates a run if free VRAM drops below QWEN_MIN_FREE_MIB
(default 1536 MiB) or the model's no-swap cgroup reports any swapped memory.
System-wide swap changes are recorded separately because unrelated desktop
processes may use zram while the model cgroup remains at exactly zero.
EOF
}

error() {
    printf 'benchmark-qwen: %s\n' "$*" >&2
}

enter_no_swap_scope() {
    local -a original_arguments=("$@")

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
        "$0" "${original_arguments[@]}"
}

cleanup() {
    if [[ -n "$active_server_pid" ]] && kill -0 "$active_server_pid" 2>/dev/null; then
        terminate_process "$active_server_pid" || true
    fi
    if [[ -n "$active_sampler_pid" ]] && kill -0 "$active_sampler_pid" 2>/dev/null; then
        kill "$active_sampler_pid" 2>/dev/null || true
        wait "$active_sampler_pid" 2>/dev/null || true
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

find_gpu_device() {
    local candidate

    for candidate in /sys/class/drm/card*/device; do
        [[ -r "${candidate}/vendor" && -r "${candidate}/device" ]] || continue
        if [[ "$(<"${candidate}/vendor")" == "0x1002" && "$(<"${candidate}/device")" == "0x73df" ]]; then
            gpu_device="$candidate"
            return
        fi
    done

    error "RX 6700 XT sysfs device (1002:73df) was not found"
    return 1
}

read_meminfo_kib() {
    local key="$1"
    awk -v key="${key}:" '$1 == key { print $2; exit }' /proc/meminfo
}

read_process_rss_mib() {
    local pid="$1"
    awk '$1 == "VmRSS:" { print int($2 / 1024); found = 1; exit } END { if (!found) print 0 }' "/proc/${pid}/status" 2>/dev/null
}

sample_resources() {
    local pid="$1"
    local samples="$2"
    local guard_file="$3"
    local total_vram_bytes
    local used_vram_bytes
    local free_vram_mib
    local used_vram_mib
    local mem_total_kib
    local mem_available_kib
    local system_ram_used_mib
    local swap_total_kib
    local swap_free_kib
    local swap_used_mib
    local rss_mib
    local model_swap_mib
    local cgroup_path
    local cgroup_swap_file

    total_vram_bytes="$(<"${gpu_device}/mem_info_vram_total")"
    cgroup_path="$(awk -F: '$1 == "0" { print $3; exit }' "/proc/${pid}/cgroup")"
    cgroup_swap_file="/sys/fs/cgroup${cgroup_path}/memory.swap.current"

    while kill -0 "$pid" 2>/dev/null; do
        used_vram_bytes="$(<"${gpu_device}/mem_info_vram_used")"
        used_vram_mib=$((used_vram_bytes / 1048576))
        free_vram_mib=$(((total_vram_bytes - used_vram_bytes) / 1048576))
        mem_total_kib="$(read_meminfo_kib MemTotal)"
        mem_available_kib="$(read_meminfo_kib MemAvailable)"
        system_ram_used_mib=$(((mem_total_kib - mem_available_kib) / 1024))
        swap_total_kib="$(read_meminfo_kib SwapTotal)"
        swap_free_kib="$(read_meminfo_kib SwapFree)"
        swap_used_mib=$(((swap_total_kib - swap_free_kib) / 1024))
        rss_mib="$(read_process_rss_mib "$pid")"
        model_swap_mib=0
        if [[ -r "$cgroup_swap_file" ]]; then
            model_swap_mib=$(( $(<"$cgroup_swap_file") / 1048576 ))
        fi

        printf '%(%s)T\t%d\t%d\t%d\t%d\t%d\t%d\n' -1 \
            "$used_vram_mib" "$free_vram_mib" "$system_ram_used_mib" \
            "$swap_used_mib" "$rss_mib" "$model_swap_mib" >> "$samples"

        if ((free_vram_mib < MIN_FREE_MIB)); then
            printf 'free VRAM fell below %s MiB\n' "$MIN_FREE_MIB" > "$guard_file"
            kill "$pid" 2>/dev/null || true
            return
        fi
        if ((model_swap_mib > 0)); then
            printf 'model cgroup used %s MiB of swap\n' "$model_swap_mib" > "$guard_file"
            kill "$pid" 2>/dev/null || true
            return
        fi

        sleep 0.25
    done
}

wait_for_server() {
    local pid="$1"
    local guard_file="$2"
    local attempts=$((START_TIMEOUT_SECONDS * 2))
    local attempt

    for ((attempt = 0; attempt < attempts; attempt++)); do
        [[ ! -e "$guard_file" ]] || return 1
        kill -0 "$pid" 2>/dev/null || return 1
        if curl --fail --silent --max-time 1 "http://127.0.0.1:${PORT}/health" >/dev/null 2>&1; then
            return
        fi
        sleep 0.5
    done

    return 1
}

wait_for_vram_release() {
    local baseline_vram_mib="$1"
    local used_vram_mib
    local attempt

    for ((attempt = 0; attempt < 120; attempt++)); do
        used_vram_mib=$(( $(<"${gpu_device}/mem_info_vram_used") / 1048576 ))
        if ((used_vram_mib <= baseline_vram_mib + 256)); then
            return
        fi
        sleep 0.25
    done

    error "VRAM did not return near the ${baseline_vram_mib} MiB baseline within 30 seconds"
    return 1
}

append_result() {
    local values=("$@")
    local value
    local first=1

    for value in "${values[@]}"; do
        value="${value//$'\t'/ }"
        value="${value//$'\n'/ }"
        if ((first)); then
            first=0
        else
            printf '\t' >> "$results_file"
        fi
        printf '%s' "$value" >> "$results_file"
    done
    printf '\n' >> "$results_file"
}

run_case() {
    local label="$1"
    local context="$2"
    local ncmoe="$3"
    local cache_k="$4"
    local cache_v="$5"
    local flash_attn="$6"
    local log_file="${run_dir}/${label}.log"
    local response_file="${run_dir}/${label}.response.json"
    local command_file="${run_dir}/${label}.command"
    local samples_file="${run_dir}/${label}.samples.tsv"
    local guard_file="${run_dir}/${label}.guard"
    local baseline_vram_mib
    local baseline_swap_mib
    local load_vram_absolute_mib=0
    local load_vram_workload_mib=0
    local load_server_rss_mib=0
    local peak_vram_mib=0
    local peak_workload_vram_mib=0
    local min_free_vram_mib=0
    local peak_system_ram_used_mib=0
    local peak_swap_mib=0
    local swap_delta_mib=0
    local model_swap_peak_mib=0
    local prompt_tps=""
    local generation_tps=""
    local output_valid="no"
    local gpu_allocation_failure="no"
    local vulkan_warning_count=0
    local status="start_failed"
    local model_id=""
    local prompt=""
    local payload=""
    local server_status=0
    local -a command=(
        "$SERVER"
        -m "$MODEL"
        -ngl all
        -ncmoe "$ncmoe"
        -c "$context"
        -ctk "$cache_k"
        -ctv "$cache_v"
        -fa "$flash_attn"
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

    printf '\n[%s] ctx=%s ncmoe=%s K=%s V=%s FA=%s\n' \
        "$label" "$context" "$ncmoe" "$cache_k" "$cache_v" "$flash_attn"

    baseline_vram_mib=$(( $(<"${gpu_device}/mem_info_vram_used") / 1048576 ))
    baseline_swap_mib=$(( ($(read_meminfo_kib SwapTotal) - $(read_meminfo_kib SwapFree)) / 1024 ))

    printf '%q ' "${command[@]}" > "$command_file"
    printf '\n' >> "$command_file"
    : > "$samples_file"

    "${command[@]}" > "$log_file" 2>&1 &
    active_server_pid=$!
    sample_resources "$active_server_pid" "$samples_file" "$guard_file" &
    active_sampler_pid=$!

    if wait_for_server "$active_server_pid" "$guard_file"; then
        status="ready"
        load_vram_absolute_mib=$(( $(<"${gpu_device}/mem_info_vram_used") / 1048576 ))
        load_vram_workload_mib=$((load_vram_absolute_mib - baseline_vram_mib))
        ((load_vram_workload_mib >= 0)) || load_vram_workload_mib=0
        load_server_rss_mib="$(read_process_rss_mib "$active_server_pid")"

        model_id="$(curl --fail --silent --max-time 5 "http://127.0.0.1:${PORT}/v1/models" | jq -r '.data[0].id // empty')"
        prompt="$(jq -nr '
            ([range(0; 96) | "Vulkan inference should remain stable while a normal desktop workload continues in the background."] | join(" "))
            + " Reply first with the exact marker QWEN_OK_731 and state the result of 19 multiplied by 23. Then add a concise 100-word plain-English paragraph explaining why GPU memory headroom matters for a desktop running local inference. /no_think"
        ')"
        payload="$(jq -n --arg model "$model_id" --arg prompt "$prompt" '{
            model: $model,
            messages: [{role: "user", content: $prompt}],
            max_tokens: 128,
            temperature: 0,
            seed: 731,
            stream: false,
            timings_per_token: true,
            chat_template_kwargs: {enable_thinking: false}
        }')"

        if curl --fail --silent --show-error \
            --max-time "$REQUEST_TIMEOUT_SECONDS" \
            -H 'Content-Type: application/json' \
            -d "$payload" \
            "http://127.0.0.1:${PORT}/v1/chat/completions" > "$response_file"; then
            status="completed"
            prompt_tps="$(jq -r '.timings.prompt_per_second // empty' "$response_file")"
            generation_tps="$(jq -r '.timings.predicted_per_second // empty' "$response_file")"
            if jq -er '.choices[0].message.content // empty' "$response_file" | \
                grep -q 'QWEN_OK' && \
                jq -er '.choices[0].message.content // empty' "$response_file" | \
                grep -q '437'; then
                output_valid="yes"
            fi
        else
            status="request_failed"
        fi
    elif [[ -e "$guard_file" ]]; then
        status="guard_aborted"
    elif ! kill -0 "$active_server_pid" 2>/dev/null; then
        status="server_exited"
    else
        status="start_timeout"
    fi

    if kill -0 "$active_server_pid" 2>/dev/null; then
        terminate_process "$active_server_pid" || server_status=$?
    else
        wait "$active_server_pid" 2>/dev/null || server_status=$?
    fi
    active_server_pid=""

    if kill -0 "$active_sampler_pid" 2>/dev/null; then
        kill "$active_sampler_pid" 2>/dev/null || true
    fi
    wait "$active_sampler_pid" 2>/dev/null || true
    active_sampler_pid=""

    if [[ -s "$samples_file" ]]; then
        read -r peak_vram_mib min_free_vram_mib peak_system_ram_used_mib peak_swap_mib model_swap_peak_mib < <(
            awk -F '\t' '
                NR == 1 { max_vram=$2; min_free=$3; max_ram=$4; max_swap=$5; max_model_swap=$7 }
                $2 > max_vram { max_vram=$2 }
                $3 < min_free { min_free=$3 }
                $4 > max_ram { max_ram=$4 }
                $5 > max_swap { max_swap=$5 }
                $7 > max_model_swap { max_model_swap=$7 }
                END { print max_vram, min_free, max_ram, max_swap, max_model_swap }
            ' "$samples_file"
        )
        peak_workload_vram_mib=$((peak_vram_mib - baseline_vram_mib))
        ((peak_workload_vram_mib >= 0)) || peak_workload_vram_mib=0
        swap_delta_mib=$((peak_swap_mib - baseline_swap_mib))
        ((swap_delta_mib >= 0)) || swap_delta_mib=0
    fi

    if grep -Eqi 'VK_ERROR_OUT_OF_DEVICE_MEMORY|out of (device )?memory|allocat(e|ion).*fail' "$log_file"; then
        gpu_allocation_failure="yes"
    fi
    vulkan_warning_count="$(grep -Eic 'warning.*vulkan|vulkan.*warning|VK_ERROR| W .*Vulkan' "$log_file" || true)"

    if [[ -e "$guard_file" ]]; then
        status="guard_aborted"
    elif [[ "$status" == "completed" && "$output_valid" != "yes" ]]; then
        status="invalid_output"
    elif [[ "$status" == "completed" && "$model_swap_peak_mib" -gt 0 ]]; then
        status="swap_observed"
    fi

    append_result \
        "$label" "$context" "$ncmoe" "$cache_k" "$cache_v" "$flash_attn" \
        "$status" "$baseline_vram_mib" "$load_vram_absolute_mib" \
        "$load_vram_workload_mib" "$peak_vram_mib" "$peak_workload_vram_mib" \
        "$min_free_vram_mib" "$load_server_rss_mib" "$peak_system_ram_used_mib" \
        "$swap_delta_mib" "$model_swap_peak_mib" "$prompt_tps" "$generation_tps" "$gpu_allocation_failure" \
        "$output_valid" "$DESKTOP_NOTE" "$vulkan_warning_count" "$server_status" \
        "$log_file" "$response_file"

    printf '  status=%s peak=%s MiB free=%s MiB RAM=%s MiB system_swap_delta=%s MiB model_swap=%s MiB pp=%s t/s tg=%s t/s valid=%s\n' \
        "$status" "$peak_vram_mib" "$min_free_vram_mib" \
        "$peak_system_ram_used_mib" "$swap_delta_mib" "$model_swap_peak_mib" \
        "${prompt_tps:-n/a}" "${generation_tps:-n/a}" "$output_valid"

    wait_for_vram_release "$baseline_vram_mib" || true

    [[ "$status" == "completed" ]]
}

latest_safe_ncmoe() {
    awk -F '\t' -v min_free="$MIN_FREE_MIB" '
        NR > 1 && $7 == "completed" && $13 >= min_free && $17 == 0 && $21 == "yes" {
            if (safe == "" || $3 < safe) safe=$3
            if ($13 >= 2048 && (preferred == "" || $3 < preferred)) preferred=$3
        }
        END {
            if (preferred != "") print preferred
            else if (safe != "") print safe
        }
    ' "$results_file"
}

latest_safe_turbo_ncmoe() {
    awk -F '\t' -v min_free="$MIN_FREE_MIB" '
        NR > 1 && $5 == "turbo3" && $7 == "completed" && $13 >= min_free && $17 == 0 && $21 == "yes" {
            if (safe == "" || $3 < safe) safe=$3
            if ($13 >= 2048 && (preferred == "" || $3 < preferred)) preferred=$3
        }
        END {
            if (preferred != "") print preferred
            else if (safe != "") print safe
        }
    ' "$results_file"
}

case_definition() {
    case "$1" in
        A) printf 'A 32768 30 q8_0 q8_0 on\n' ;;
        B) printf 'B 32768 28 q8_0 q8_0 on\n' ;;
        C) printf 'C 32768 26 q8_0 q8_0 on\n' ;;
        D) printf 'D 32768 24 q8_0 q8_0 on\n' ;;
        E) printf 'E 32768 %s q8_0 turbo3 on\n' "${QWEN_BEST_NCMOE:-}" ;;
        F) printf 'F 65536 %s q8_0 turbo3 on\n' "${QWEN_FA_NCMOE:-${QWEN_BEST_NCMOE:-}}" ;;
        G) printf 'G 32768 %s q8_0 f16 off\n' "${QWEN_FA_NCMOE:-${QWEN_BEST_NCMOE:-}}" ;;
        H) printf 'H 32768 %s q8_0 f16 on\n' "${QWEN_FA_NCMOE:-${QWEN_BEST_NCMOE:-}}" ;;
        I) printf 'I 32768 %s q8_0 turbo3 on\n' "${QWEN_TURBO_NCMOE:-}" ;;
        J) printf 'J 65536 %s q8_0 turbo3 on\n' "${QWEN_BEST_NCMOE:-}" ;;
        *) return 1 ;;
    esac
}

run_named_case() {
    local definition
    local label
    local context
    local ncmoe
    local cache_k
    local cache_v
    local flash_attn

    definition="$(case_definition "$1")" || {
        error "unknown case: $1"
        return 2
    }
    read -r label context ncmoe cache_k cache_v flash_attn <<< "$definition"
    if [[ ! "$ncmoe" =~ ^[0-9]+$ ]]; then
        error "QWEN_BEST_NCMOE must be set to run case ${label}"
        return 2
    fi
    run_case "$label" "$context" "$ncmoe" "$cache_k" "$cache_v" "$flash_attn"
}

run_matrix() {
    local best_ncmoe
    local b_free
    local c_free
    local observed_step_mib=512
    local d_required_free_mib
    local e_free
    local turbo_required_free_mib
    local turbo_ncmoe

    if ! run_named_case A; then
        error "safest baseline A failed; refusing to move more experts onto the GPU"
        return 1
    fi
    if ! run_named_case B; then
        error "baseline B failed; refusing to continue to C/D"
        return 1
    fi
    if run_named_case C; then
        b_free="$(awk -F '\t' '$1 == "B" { value=$13 } END { print value }' "$results_file")"
        c_free="$(awk -F '\t' '$1 == "C" { value=$13 } END { print value }' "$results_file")"
        if [[ "$b_free" =~ ^[0-9]+$ && "$c_free" =~ ^[0-9]+$ && b_free > c_free ]]; then
            observed_step_mib=$((b_free - c_free))
        fi
        d_required_free_mib=$((MIN_FREE_MIB + observed_step_mib + 128))
        if [[ "$c_free" =~ ^[0-9]+$ ]] && ((c_free >= d_required_free_mib)); then
            run_named_case D || true
        else
            printf '\n[D] skipped: C did not leave the estimated safe %s MiB free VRAM.\n' "$d_required_free_mib"
        fi
    else
        error "baseline C failed; D is unsafe and will be skipped"
    fi

    best_ncmoe="$(latest_safe_ncmoe)"
    if [[ -z "$best_ncmoe" ]]; then
        error "no safe q8_0/q8_0 baseline was found; skipping E/F/G/H"
        return 1
    fi
    printf '\nBest safe baseline ncmoe for comparisons: %s\n' "$best_ncmoe"
    export QWEN_BEST_NCMOE="$best_ncmoe"
    export QWEN_FA_NCMOE="$best_ncmoe"

    if run_named_case E; then
        e_free="$(awk -F '\t' '$1 == "E" { value=$13 } END { print value }' "$results_file")"
        turbo_ncmoe=$((best_ncmoe - 2))
        turbo_required_free_mib=$((MIN_FREE_MIB + observed_step_mib + 128))
        if ((turbo_ncmoe >= 0)) && [[ "$e_free" =~ ^[0-9]+$ ]] && \
            ((e_free >= turbo_required_free_mib)); then
            export QWEN_TURBO_NCMOE="$turbo_ncmoe"
            run_named_case I || true
        else
            printf '\n[I] skipped: E did not leave the estimated safe %s MiB free VRAM.\n' \
                "$turbo_required_free_mib"
        fi
        best_ncmoe="$(latest_safe_turbo_ncmoe)"
        export QWEN_BEST_NCMOE="$best_ncmoe"
        run_named_case F || true
        if [[ "$best_ncmoe" != "$QWEN_FA_NCMOE" ]]; then
            run_named_case J || true
        fi
    else
        error "turbo3 baseline failed; skipping the 64K turbo3 case"
    fi
    run_named_case G || true
    run_named_case H || true
}

list_matrix() {
    cat <<'EOF'
Case  Context  ncmoe  K     V       Flash Attention
A     32768    30     q8_0  q8_0    on
B     32768    28     q8_0  q8_0    on
C     32768    26     q8_0  q8_0    on
D     32768    24     q8_0  q8_0    on (gated by the measured B-to-C VRAM step)
E     32768    best   q8_0  turbo3  on
I     32768    best-2 q8_0  turbo3  on (gated by measured expert-step VRAM)
F     65536    best   q8_0  turbo3  on
J     65536    best-T q8_0  turbo3  on (additional guarded retune probe)
G     32768    best   q8_0  f16     off
H     32768    best   q8_0  f16     on
EOF
}

main() {
    local timestamp
    local command

    if [[ "${1:-matrix}" == "list" ]]; then
        list_matrix
        return
    fi
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || "${1:-}" == "help" ]]; then
        usage
        return
    fi

    enter_no_swap_scope "$@" || return 1

    [[ -x "$SERVER" ]] || {
        error "llama-server not found or not executable: ${SERVER}"
        return 1
    }
    [[ -r "$MODEL" ]] || {
        error "model not found: ${MODEL}"
        return 1
    }
    if (( $(stat -c '%s' "$MODEL") < MIN_MODEL_BYTES )); then
        error "model file is incomplete: ${MODEL}"
        return 1
    fi
    command -v curl >/dev/null 2>&1 || {
        error "required command not found: curl"
        return 1
    }
    command -v jq >/dev/null 2>&1 || {
        error "required command not found: jq"
        return 1
    }
    find_gpu_device || return 1
    if curl --fail --silent --max-time 1 "http://127.0.0.1:${PORT}/health" >/dev/null 2>&1; then
        error "another llama-server is already listening on 127.0.0.1:${PORT}"
        return 1
    fi

    timestamp="$(date +'%Y%m%d-%H%M%S')"
    run_dir="${STATE_ROOT}/${timestamp}"
    results_file="${run_dir}/results.tsv"
    mkdir -p "$run_dir" || return 1
    append_result \
        label context ncmoe cache_k cache_v flash_attn status \
        baseline_vram_mib load_vram_absolute_mib load_workload_vram_mib \
        peak_vram_mib peak_workload_vram_mib min_free_vram_mib \
        load_server_rss_mib peak_system_ram_used_mib system_swap_delta_mib model_swap_peak_mib \
        prompt_tps generation_tps gpu_allocation_failure output_valid \
        desktop_responsiveness vulkan_warning_count server_exit_status log response

    if (($# == 0)) || [[ "$1" == "matrix" ]]; then
        run_matrix
    else
        for command in "$@"; do
            run_named_case "${command^^}" || true
        done
    fi

    printf '\nResults: %s\n' "$results_file"
    column -s $'\t' -t "$results_file" 2>/dev/null || sed -n '1,200p' "$results_file"
}

main "$@"
