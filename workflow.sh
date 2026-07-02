#!/bin/bash
# ============================================================
# 模型推理服务测试 - 主工作流编排脚本
# ============================================================
# 使用方式:
#   1. 修改 config.yaml 中的参数
#   2. 执行: bash workflow.sh [options]
#
# Options:
#   --config <path>    指定配置文件 (默认: config.yaml)
#   --skip-env         跳过环境检测
#   --skip-prepare     跳过模型/镜像准备
#   --skip-container   跳过容器创建
#   --skip-service     跳过服务启动
#   --skip-perf        跳过性能测试
#   --skip-eval        跳过精度测试
#   --only <phase>     只运行指定阶段 (env/prepare/container/service/perf/eval/export)
#   --help             显示帮助
# ============================================================
set -o pipefail

WORKFLOW_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${WORKFLOW_DIR}/scripts"

source "${SCRIPTS_DIR}/utils.sh"

# --- 参数解析 ---
CONFIG_FILE="${WORKFLOW_DIR}/config.yaml"
SKIP_ENV=false
SKIP_PREPARE=false
SKIP_CONTAINER=false
SKIP_SERVICE=false
SKIP_PERF=false
SKIP_EVAL=false
ONLY_PHASE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)      CONFIG_FILE="$2"; shift 2 ;;
        --skip-env)    SKIP_ENV=true; shift ;;
        --skip-prepare) SKIP_PREPARE=true; shift ;;
        --skip-container) SKIP_CONTAINER=true; shift ;;
        --skip-service) SKIP_SERVICE=true; shift ;;
        --skip-perf)   SKIP_PERF=true; shift ;;
        --skip-eval)   SKIP_EVAL=true; shift ;;
        --only)        ONLY_PHASE="$2"; shift 2 ;;
        --help|-h)
            head -20 "$0" | grep "^#" | sed 's/^# *//'
            exit 0
            ;;
        *)
            log_error "未知参数: $1"
            exit 1
            ;;
    esac
done

# --- 加载配置 ---
log_step "加载配置"
load_config "$CONFIG_FILE" || exit 1

# 确保输出目录存在
OUTPUT_DIR="$(get_config OUTPUT_DIR './results')"
ensure_output_dir "$OUTPUT_DIR"

# --- 打印测试计划 ---
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║        模型推理服务测试 - 自动化工作流              ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║  模型: $(printf '%-43s' "$(get_config MODEL_NAME)")║"
echo "║  硬件: $(printf '%-43s' "$(get_config HARDWARE_TYPE 'auto')")║"
echo "║  镜像: $(printf '%-43s' "$(get_config IMAGE_ID '' | cut -c1-43)")║"
echo "║  性能测试: $(printf '%-39s' "$(get_config PERF_ENABLED 'true')")║"
echo "║  精度测试: $(printf '%-39s' "$(get_config EVAL_ENABLED 'true')")║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# --- 记录开始时间 ---
WORKFLOW_START=$(date +%s)

# --- 执行阶段函数 ---
run_phase() {
    local phase_num="$1"
    local phase_name="$2"
    local script="$3"
    local skip_flag="$4"

    # 检查 --only 模式
    if [[ -n "$ONLY_PHASE" && "$ONLY_PHASE" != "$phase_name" ]]; then
        return 0
    fi

    # 检查 skip 标记
    if [[ "$skip_flag" == "true" ]]; then
        log_info "跳过 Phase ${phase_num}: ${phase_name}"
        return 0
    fi

    local phase_start=$(date +%s)
    log_step "Phase ${phase_num}: ${phase_name}"

    if bash "$script"; then
        local phase_end=$(date +%s)
        local duration=$((phase_end - phase_start))
        log_info "Phase ${phase_num} 耗时: ${duration}s ✓"
        return 0
    else
        log_error "Phase ${phase_num} 失败!"
        return 1
    fi
}

# --- 导出配置变量供子脚本使用 ---
eval "$(parse_yaml "$CONFIG_FILE" "CFG_")"
export $(parse_yaml "$CONFIG_FILE" "CFG_" | cut -d= -f1) 2>/dev/null

# --- 执行流程 ---
FAILED=false

# Phase 1: 环境检测
run_phase 1 "env" "${SCRIPTS_DIR}/01_check_env.sh" "$SKIP_ENV" || FAILED=true

# Phase 2: 模型与镜像准备
if [[ "$FAILED" == "false" ]]; then
    run_phase 2 "prepare" "${SCRIPTS_DIR}/02_prepare.sh" "$SKIP_PREPARE" || FAILED=true
fi

# Phase 3: 容器创建
if [[ "$FAILED" == "false" ]]; then
    run_phase 3 "container" "${SCRIPTS_DIR}/03_create_container.sh" "$SKIP_CONTAINER" || FAILED=true
fi

# Phase 4: 服务启动
if [[ "$FAILED" == "false" ]]; then
    run_phase 4 "service" "${SCRIPTS_DIR}/04_start_service.sh" "$SKIP_SERVICE" || FAILED=true
fi

# Phase 5: 性能测试
if [[ "$FAILED" == "false" && "$(get_config PERF_ENABLED 'true')" == "true" ]]; then
    run_phase 5 "perf" "${SCRIPTS_DIR}/05_run_perf.sh" "$SKIP_PERF" || FAILED=true
fi

# Phase 6: 精度测试
if [[ "$FAILED" == "false" && "$(get_config EVAL_ENABLED 'true')" == "true" ]]; then
    run_phase 6 "eval" "${SCRIPTS_DIR}/06_run_eval.sh" "$SKIP_EVAL" || FAILED=true
fi

# Phase 7: 结果导出（即使前面有失败也尝试导出已有结果）
run_phase 7 "export" "${SCRIPTS_DIR}/07_export_results.sh" "false"

# --- 总结 ---
WORKFLOW_END=$(date +%s)
TOTAL_DURATION=$((WORKFLOW_END - WORKFLOW_START))

echo ""
echo "╔══════════════════════════════════════════════════════╗"
if [[ "$FAILED" == "false" ]]; then
echo "║            ✅ 工作流执行完成                         ║"
else
echo "║            ⚠️  工作流执行完成（有错误）               ║"
fi
echo "╠══════════════════════════════════════════════════════╣"
echo "║  总耗时: $(printf '%-42s' "${TOTAL_DURATION}s")║"
echo "║  结果目录: $(printf '%-40s' "${OUTPUT_DIR}")║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

if [[ "$FAILED" == "true" ]]; then
    exit 1
fi
