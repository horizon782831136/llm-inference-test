#!/bin/bash
# ============================================================
# Phase 5: 性能测试
# 在测试容器内使用 evalscope perf 进行性能基准测试
# 支持 benchmark(多rate梯度) 和 single(单配置) 两种模式
# 测试日志和结果保存在服务脚本目录下的 test/ 文件夹中
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

log_step "Phase 5: 性能测试"

# --- 参数 ---
TEST_CONTAINER="${CFG_TEST_CONTAINER_NAME:-lw_qa_infer}"
SERVICE_SCRIPT="${CFG_SERVICE_SCRIPT:-}"
MODEL_NAME="${CFG_MODEL_NAME:-}"
TOKENIZER_PATH="${CFG_TOKENIZER_PATH:-${CFG_MODEL_PATH:-}}"
SERVICE_PORT="${CFG_SERVICE_PORT:-30000}"
PERF_MODE="${CFG_PERF_MODE:-benchmark}"
PERF_URL="${CFG_PERF_URL:-}"
INPUT_LEN="${CFG_PERF_INPUT_LEN:-9000}"
OUTPUT_LEN="${CFG_PERF_OUTPUT_LEN:-100}"
PERF_NUMBER="${CFG_PERF_NUMBER:-200}"
PERF_TEMP="${CFG_PERF_TEMPERATURE:-0.7}"
PERF_RATES="${CFG_PERF_RATES:-0.3,0.5,0.6,0.7,0.8,1.0,1.5,2.0,3.0,4.0,5.0,10.0,20.0}"
PERF_PARALLELS="${CFG_PERF_PARALLELS:-3,5,6,7,8,10,15,20,30,40,50,100,200}"
SINGLE_PARALLEL="${CFG_PERF_SINGLE_PARALLEL:-10}"
SINGLE_NUMBER="${CFG_PERF_SINGLE_NUMBER:-1000}"
MAX_RETRIES="${CFG_MAX_RETRIES:-2}"
RETRY_ON_ANOMALY="${CFG_RETRY_ON_ANOMALY:-true}"

# 自动拼接URL
if [[ -z "$PERF_URL" ]]; then
    PERF_URL="http://127.0.0.1:${SERVICE_PORT}/v1/completions"
fi

# --- 测试输出目录：服务脚本同目录下的 test/ ---
if [[ -n "$SERVICE_SCRIPT" ]]; then
    SERVICE_SCRIPT_DIR=$(dirname "$SERVICE_SCRIPT")
    TEST_OUTPUT_DIR="${SERVICE_SCRIPT_DIR}/test"
else
    TEST_OUTPUT_DIR="./test"
fi
mkdir -p "$TEST_OUTPUT_DIR"

TIMESTAMP=$(timestamp)
LOG_FILE="${TEST_OUTPUT_DIR}/perf_${PERF_MODE}_${TIMESTAMP}.log"

log_info "测试输出目录: ${TEST_OUTPUT_DIR}"
log_info "性能日志文件: ${LOG_FILE}"

# --- 检查测试容器运行状态 ---
if ! container_running "$TEST_CONTAINER"; then
    log_error "测试容器 ${TEST_CONTAINER} 未运行!"
    exit 1
fi

# --- 检查容器内 evalscope[perf] ---
if ! docker exec "$TEST_CONTAINER" bash -c 'export PATH="/root/miniconda/envs/evalscope_env/bin:$PATH" && evalscope perf --help >/dev/null 2>&1'; then
    log_warn "测试容器内 evalscope[perf] 未安装，尝试自动安装..."
    docker exec "$TEST_CONTAINER" bash -c 'export PATH="/root/miniconda/envs/evalscope_env/bin:$PATH" && pip install evalscope "evalscope[perf]" -i https://repo.huaweicloud.com/repository/pypi/simple' 2>&1
    if ! docker exec "$TEST_CONTAINER" bash -c 'export PATH="/root/miniconda/envs/evalscope_env/bin:$PATH" && evalscope perf --help >/dev/null 2>&1'; then
        log_error "evalscope[perf] 安装失败! 请手动进入测试容器安装: docker exec -it ${TEST_CONTAINER} bash"
        exit 1
    fi
    log_info "evalscope[perf] 安装完成 ✓"
fi

# --- 运行单次性能测试（在测试容器内执行） ---
run_perf_single() {
    local rate="$1"
    local parallel="$2"
    local num="${3:-$PERF_NUMBER}"

    echo "Running with rate=${rate}, parallel=${parallel}" | tee -a "$LOG_FILE"

    docker exec "$TEST_CONTAINER" bash -c '\
        export PATH="/root/miniconda/envs/evalscope_env/bin:$PATH" && \
        cd /dir && evalscope perf \
        --url "'"$PERF_URL"'" \
        --model "'"$MODEL_NAME"'" \
        --dataset random \
        --api-key "" \
        --parallel '"$parallel"' \
        --rate '"$rate"' \
        --number '"$num"' \
        --temperature '"$PERF_TEMP"' \
        --max-prompt-length '"$INPUT_LEN"' \
        --min-prompt-length '"$INPUT_LEN"' \
        --max-tokens '"$OUTPUT_LEN"' \
        --min-tokens '"$OUTPUT_LEN"' \
        --prefix-length 0 \
        --tokenizer-path "'"$TOKENIZER_PATH"'" \
        --name "'"$MODEL_NAME"'"' 2>&1 | tee -a "$LOG_FILE"

    local exit_code=${PIPESTATUS[0]}
    echo "Finished rate=${rate}, parallel=${parallel}" | tee -a "$LOG_FILE"
    echo "-----------------------------------" | tee -a "$LOG_FILE"
    return $exit_code
}

# --- 检查结果是否异常 ---
check_perf_anomaly() {
    local log="$1"
    # 检查是否有大量失败请求
    local failed
    failed=$(grep -o "Failed.*[0-9]\+" "$log" 2>/dev/null | tail -1 | grep -o "[0-9]\+$")
    if [[ -n "$failed" && "$failed" -gt 0 ]]; then
        local total
        total=$(grep -o "Total.*[0-9]\+" "$log" 2>/dev/null | tail -1 | grep -o "[0-9]\+$")
        if [[ -n "$total" ]]; then
            local fail_rate=$((failed * 100 / total))
            if [[ $fail_rate -gt 20 ]]; then
                log_warn "失败率过高: ${fail_rate}% (${failed}/${total})"
                return 1
            fi
        fi
    fi
    return 0
}

# --- 执行测试 ---
log_info "性能测试模式: ${PERF_MODE}"
log_info "模型: ${MODEL_NAME}"
log_info "URL: ${PERF_URL}"
log_info "输入长度: ${INPUT_LEN}, 输出长度: ${OUTPUT_LEN}"
log_info "日志文件: ${LOG_FILE}"

case "$PERF_MODE" in
    benchmark)
        IFS=',' read -ra rates <<< "$PERF_RATES"
        IFS=',' read -ra parallels <<< "$PERF_PARALLELS"

        if [[ ${#rates[@]} -ne ${#parallels[@]} ]]; then
            log_error "rates 和 parallels 数量不匹配!"
            exit 1
        fi

        log_info "Benchmark模式: ${#rates[@]} 个梯度"

        for i in "${!rates[@]}"; do
            rate="${rates[$i]}"
            parallel="${parallels[$i]}"
            log_info "[${i}/${#rates[@]}] rate=${rate}, parallel=${parallel}"

            attempt=0
            success=false
            while [[ $attempt -le $MAX_RETRIES ]]; do
                run_perf_single "$rate" "$parallel"
                if [[ "$RETRY_ON_ANOMALY" == "true" ]] && ! check_perf_anomaly "$LOG_FILE"; then
                    ((attempt++))
                    if [[ $attempt -le $MAX_RETRIES ]]; then
                        log_warn "结果异常，重试 (${attempt}/${MAX_RETRIES})..."
                    fi
                else
                    success=true
                    break
                fi
            done
            if [[ "$success" == "false" ]]; then
                log_warn "rate=${rate} 多次重试仍异常，继续下一个..."
            fi
        done
        ;;
    single)
        log_info "Single模式: parallel=${SINGLE_PARALLEL}, number=${SINGLE_NUMBER}"
        run_perf_single "0" "$SINGLE_PARALLEL" "$SINGLE_NUMBER"
        ;;
    *)
        log_error "未知的 perf_mode: ${PERF_MODE}"
        exit 1
        ;;
esac

log_info "性能测试完成，日志: ${LOG_FILE}"
log_info "Phase 5 完成 ✓"

# 导出测试目录路径供后续使用
export TEST_OUTPUT_DIR="${TEST_OUTPUT_DIR}"
echo "$LOG_FILE"
