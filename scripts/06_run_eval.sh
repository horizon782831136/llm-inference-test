#!/bin/bash
# ============================================================
# Phase 6: 精度测试
# 在测试容器内使用 evalscope eval 进行精度评测
# 测试日志和结果保存在服务脚本目录下的 test/ 文件夹中
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

log_step "Phase 6: 精度测试"

# --- 参数 ---
TEST_CONTAINER="${CFG_TEST_CONTAINER_NAME:-lw_qa_infer}"
SERVICE_SCRIPT="${CFG_SERVICE_SCRIPT:-}"
MODEL_NAME="${CFG_MODEL_NAME:-}"
SERVICE_PORT="${CFG_SERVICE_PORT:-30000}"
EVAL_URL="${CFG_EVAL_URL:-}"
EVAL_DATASETS="${CFG_EVAL_DATASETS:-aime25,gpqa_diamond,gsm8k,humaneval}"
EVAL_MAX_TOKENS="${CFG_EVAL_MAX_TOKENS:-131072}"
EVAL_TEMPERATURE="${CFG_EVAL_TEMPERATURE:-1.0}"
EVAL_TOP_P="${CFG_EVAL_TOP_P:-1.0}"
EVAL_THINKING="${CFG_EVAL_THINKING_MODE:-}"
EVAL_BATCH_SIZE="${CFG_EVAL_BATCH_SIZE:-128}"
JUDGE_API_URL="${CFG_JUDGE_API_URL:-}"
JUDGE_API_KEY="${CFG_JUDGE_API_KEY:-}"
JUDGE_MODEL_ID="${CFG_JUDGE_MODEL_ID:-}"
MAX_RETRIES="${CFG_MAX_RETRIES:-2}"
RETRY_ON_ANOMALY="${CFG_RETRY_ON_ANOMALY:-true}"

# 自动拼接URL
if [[ -z "$EVAL_URL" ]]; then
    EVAL_URL="http://127.0.0.1:${SERVICE_PORT}"
fi

# --- 测试输出目录：服务脚本同目录下的 test/ ---
if [[ -n "$SERVICE_SCRIPT" ]]; then
    SERVICE_SCRIPT_DIR=$(dirname "$SERVICE_SCRIPT")
    TEST_OUTPUT_DIR="${SERVICE_SCRIPT_DIR}/test"
else
    TEST_OUTPUT_DIR="./test"
fi

EVAL_OUTPUT_DIR="${TEST_OUTPUT_DIR}/eval"
EVAL_LOG_DIR="${TEST_OUTPUT_DIR}/logs"
mkdir -p "$EVAL_OUTPUT_DIR" "$EVAL_LOG_DIR"

log_info "测试输出目录: ${TEST_OUTPUT_DIR}"

# --- 需要 LLM Judge 的数据集 ---
JUDGE_DATASETS=(zerobench hle aa_lcr chinese_simpleqa simple_qa)

# --- 本地数据集路径 ---
declare -A LOCAL_PATHS=(
    [aime24]="/data/evalscope/data/aime24/"
    [aime25]="/data/evalscope/data/aime25/"
    [aime26]="/data/evalscope/data/aime26/"
    [hle]="/data/evalscope/data/hle/"
    [super_gpqa]="/data/evalscope/data/SuperGPQA/"
    [gpqa_diamond]="/data/evalscope/data/gpqa/"
    [gsm8k]="/data/evalscope/data/gsm8k/"
    [mmlu]="/data/evalscope/data/mmlu/"
    [mmlu_pro]="/data/evalscope/data/MMLU-Pro"
    [bbh]="/data/evalscope/data/bbh"
    [ceval]="/data/evalscope/data/ceval"
    [humaneval]="/data/evalscope/data/humaneval/"
    [math_500]="/data/evalscope/data/math500/"
    [ifeval]="/data/evalscope/data/ifeval/"
    [bfcl_v3]="/data/evalscope/data/bfcl_v3/"
    [simple_qa]="/data/evalscope/data/simpleqa"
    [live_code_bench]="/data/evalscope/data/code_generation_lite"
    [longbench_v2]="/data/evalscope/data/LongBench-v2/"
    [chinese_simpleqa]="/data/evalscope/data/Chinese-SimpleQA/"
    [hmmt25]="/data/evalscope/data/hmmt_feb_2025/"
    [cmmlu]="/data/evalscope/data/cmmlu/"
    [humaneval_plus]="/data/evalscope/data/humanevalplus/"
    [ifbench]="/data/evalscope/data/IFBench_test/"
    [mmlu_redux]="/data/evalscope/data/mmlu-redux-2.0/"
    [mmmlu]="/data/evalscope/data/MMMLU/"
    [zerobench]="/data/evalscope/data/zerobench/"
    [ai2d]="/data/evalscope/data/ai2d/"
    [mm_star]="/data/evalscope/data/MMStar/"
    [mmmu_pro]="/data/evalscope/data/MMMU_Pro/"
    [mmmu]="/data/evalscope/data/MMMU/"
    [hallusion_bench]="/data/evalscope/data/HallusionBench/"
    [ocr_bench]="/data/evalscope/data/OCRBench/"
    [chartqa]="/data/evalscope/data/chartqa/"
    [tau2_bench]="/data/evalscope/data/tau2-bench-data/"
    [aa_lcr]="/data/evalscope/data/AA-LCR"
    [gsm8k_v]="/data/evalscope/data/GSM8K-V/"
    [tool_bench]="/data/evalscope/data/ToolBench-Static/"
    [general_fc]="/data/evalscope/data/GeneralFunctionCall-Test/"
)

# --- subset 配置 ---
declare -A SUBSET_LISTS=(
    [live_code_bench]='["test6"]'
    [tau2_bench]='["retail", "airline", "telecom"]'
    [tool_bench]='["in_domain", "out_of_domain"]'
    [bfcl_v4]='["irrelevance", "live_irrelevance", "live_multiple"]'
    [longbench_v2]='["short"]'
)

# --- 构建 generation-config ---
build_generation_config() {
    local max_tokens="${1:-$EVAL_MAX_TOKENS}"
    local json="{\"max_tokens\":${max_tokens},\"temperature\":${EVAL_TEMPERATURE},\"top_p\":${EVAL_TOP_P}"
    if [[ "$EVAL_THINKING" == "true" ]]; then
        json+=",\"extra_body\":{\"chat_template_kwargs\":{\"thinking\":true,\"enable_thinking\":true}}"
    elif [[ "$EVAL_THINKING" == "false" ]]; then
        json+=",\"extra_body\":{\"chat_template_kwargs\":{\"thinking\":false,\"enable_thinking\":false}}"
    fi
    json+="}"
    echo "$json"
}

# --- 运行单个数据集 ---
run_eval_dataset() {
    local dataset_name="$1"
    local ts; ts=$(timestamp)
    local local_path="${LOCAL_PATHS[$dataset_name]:-}"
    local work_dir="${EVAL_OUTPUT_DIR}/${dataset_name}_${ts}"

    # 构建 dataset-args
    local parts=()
    [[ -n "$local_path" ]] && parts+=("\"local_path\":\"${local_path}\"")
    local subset="${SUBSET_LISTS[$dataset_name]:-}"
    [[ -n "$subset" ]] && parts+=("\"subset_list\":${subset}")
    local IFS=","; local inner="{${parts[*]:-}}"

    local gen_json; gen_json=$(build_generation_config)

    log_info "运行评测: ${dataset_name}"
    log_info "  generation-config: ${gen_json}"

    # 判断是否需要 Judge
    local judge_args=()
    for jds in "${JUDGE_DATASETS[@]}"; do
        if [[ "$jds" == "$dataset_name" ]]; then
            local j_url="${JUDGE_API_URL:-${EVAL_URL}/v1}"
            local j_key="${JUDGE_API_KEY:-EMPTY}"
            local j_model="${JUDGE_MODEL_ID:-${MODEL_NAME}}"
            judge_args=(
                --judge-strategy llm
                --judge-model-args "{\"api_url\": \"${j_url}\", \"api_key\": \"${j_key}\", \"model_id\": \"${j_model}\"}"
            )
            break
        fi
    done

    evalscope eval \
        --model "$MODEL_NAME" \
        --api-url "${EVAL_URL}/v1" \
        --api-key "EMPTY" \
        --eval-type openai_api \
        --datasets "$dataset_name" \
        --generation-config "$gen_json" \
        --timeout 10000 \
        --stream \
        --eval-batch-size "$EVAL_BATCH_SIZE" \
        --dataset-args "{\"${dataset_name}\":${inner}}" \
        --work-dir "$work_dir" \
        --ignore-errors \
        "${judge_args[@]}" \
        2>&1 | tee "${EVAL_LOG_DIR}/${dataset_name}_${ts}.log"

    return ${PIPESTATUS[0]}
}

# --- 检查精度结果是否异常 ---
check_eval_anomaly() {
    local dataset_name="$1"
    local log_file="$2"
    # 简单检查：如果日志中出现大量 ERROR 或 score=0，可能异常
    local error_count
    error_count=$(grep -ci "error\|exception\|traceback" "$log_file" 2>/dev/null || echo 0)
    if [[ "$error_count" -gt 10 ]]; then
        log_warn "${dataset_name}: 检测到 ${error_count} 个错误"
        return 1
    fi
    return 0
}

# --- 主逻辑 ---
log_info "评测模型: ${MODEL_NAME}"
log_info "评测地址: ${EVAL_URL}"
log_info "数据集: ${EVAL_DATASETS}"

IFS=',' read -ra datasets <<< "$EVAL_DATASETS"

EVAL_RESULTS=()

for ds in "${datasets[@]}"; do
    ds=$(echo "$ds" | xargs)  # trim spaces
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "开始评测: ${ds}"

    attempt=0
    success=false
    while [[ $attempt -le $MAX_RETRIES ]]; do
        run_eval_dataset "$ds"
        exit_code=$?

        latest_log=$(ls -t "${EVAL_LOG_DIR}/${ds}_"*.log 2>/dev/null | head -1)
        if [[ $exit_code -eq 0 ]] && check_eval_anomaly "$ds" "$latest_log"; then
            success=true
            break
        fi

        ((attempt++))
        if [[ "$RETRY_ON_ANOMALY" == "true" && $attempt -le $MAX_RETRIES ]]; then
            log_warn "${ds} 结果异常或失败，重试 (${attempt}/${MAX_RETRIES})..."
        else
            break
        fi
    done

    if [[ "$success" == "true" ]]; then
        log_info "${ds}: 完成 ✓"
        EVAL_RESULTS+=("${ds}:PASS")
    else
        log_warn "${ds}: 完成但可能存在异常"
        EVAL_RESULTS+=("${ds}:WARN")
    fi
done

# --- 汇总 ---
log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_info "精度测试汇总:"
for r in "${EVAL_RESULTS[@]}"; do
    log_info "  ${r}"
done

log_info "Phase 6 完成 ✓"
