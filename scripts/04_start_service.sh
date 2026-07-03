#!/bin/bash
# ============================================================
# Phase 4: 服务启动与验证
# 在服务容器内启动推理服务，并通过curl验证服务可用
# 日志保存在服务脚本所在目录，以时间为后缀命名
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

log_step "Phase 4: 服务启动与验证"

# --- 参数 ---
CONTAINER_NAME="${CFG_SERVICE_CONTAINER_NAME:-lw_sglang}"
SERVICE_SCRIPT="${CFG_SERVICE_SCRIPT:-}"
SERVICE_PORT="${CFG_SERVICE_PORT:-30000}"
SERVICE_TIMEOUT="${CFG_SERVICE_TIMEOUT:-600}"
MODEL_NAME="${CFG_MODEL_NAME:-}"
MODEL_PATH="${CFG_MODEL_PATH:-}"

TIMESTAMP=$(timestamp)

# --- 检查容器运行状态 ---
if ! container_running "$CONTAINER_NAME"; then
    log_error "服务容器 ${CONTAINER_NAME} 未运行!"
    exit 1
fi

# --- 检查端口是否已被占用（旧服务） ---
if curl -s --connect-timeout 3 "http://127.0.0.1:${SERVICE_PORT}/v1/models" > /dev/null 2>&1; then
    log_warn "端口 ${SERVICE_PORT} 已被占用，停止旧服务..."
    docker exec "$CONTAINER_NAME" bash -c "pkill -9 -f 'port.*${SERVICE_PORT}' 2>/dev/null; pkill -9 -f 'vllm' 2>/dev/null; pkill -9 -f 'sglang' 2>/dev/null" || true
    sleep 5
    if curl -s --connect-timeout 3 "http://127.0.0.1:${SERVICE_PORT}/v1/models" > /dev/null 2>&1; then
        log_warn "端口仍被占用，尝试强制清理容器内所有推理进程..."
        docker exec "$CONTAINER_NAME" bash -c "pkill -9 python3.10 2>/dev/null; pkill -9 python 2>/dev/null" || true
        sleep 5
    fi
    if curl -s --connect-timeout 3 "http://127.0.0.1:${SERVICE_PORT}/v1/models" > /dev/null 2>&1; then
        log_error "无法停止端口 ${SERVICE_PORT} 上的旧服务，请手动处理"
        exit 1
    fi
    log_info "旧服务已停止 ✓"
fi

# --- 启动服务 ---
if [[ -n "$SERVICE_SCRIPT" ]]; then
    # 服务日志放在服务脚本同目录下，以时间为后缀
    local_script_dir=$(dirname "$SERVICE_SCRIPT")
    SERVICE_LOG="${local_script_dir}/service_${TIMESTAMP}.log"

    log_info "在服务容器内启动服务: ${SERVICE_SCRIPT}"
    log_info "服务日志: ${SERVICE_LOG}"

    # 在容器内后台执行服务脚本，日志输出到脚本同目录
    # SERVICE_LOG 已经是容器内绝对路径（如 /dir/qwen3.5/.../service_xxx.log）
    # 显式激活 conda 环境后执行服务脚本，确保 vllm 等命令可用
    docker exec -d "$CONTAINER_NAME" bash -c "\
        source /root/miniconda/etc/profile.d/conda.sh; \
        conda activate python310_torch29_cuda; \
        bash ${SERVICE_SCRIPT} > ${SERVICE_LOG} 2>&1"
    log_info "服务启动命令已发送"
else
    SERVICE_LOG="service_${TIMESTAMP}.log"
    log_warn "未配置 service_script，假设服务已在运行或需手动启动"
    log_warn "如需手动启动，请在容器内执行服务启动脚本"
fi

# --- 等待服务就绪 ---
check_service_health() {
    curl -s --connect-timeout 3 "http://127.0.0.1:${SERVICE_PORT}/v1/models" > /dev/null 2>&1
}

log_info "等待服务就绪 (端口: ${SERVICE_PORT}, 超时: ${SERVICE_TIMEOUT}s)..."
if ! wait_for "服务端口就绪" "$SERVICE_TIMEOUT" 10 check_service_health; then
    log_error "服务启动超时!"
    log_error "容器内服务日志 (最后50行):"
    docker exec "$CONTAINER_NAME" tail -50 "${SERVICE_LOG}" 2>/dev/null || true
    exit 1
fi

# --- 验证模型回答 ---
log_info "验证模型回答..."

VERIFY_RESPONSE=$(curl -s -X POST "http://127.0.0.1:${SERVICE_PORT}/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d "{
        \"model\": \"${MODEL_NAME}\",
        \"messages\": [{\"role\": \"user\", \"content\": \"介绍一下你自己\"}],
        \"temperature\": 0.7,
        \"max_tokens\": 256,
        \"stream\": false
    }" 2>/dev/null)

# 检查响应是否包含有效内容
if echo "$VERIFY_RESPONSE" | python3 -c "
import sys, json
resp = json.load(sys.stdin)
msg = resp.get('choices', [{}])[0].get('message', {})
content = msg.get('content', '') or ''
reasoning = msg.get('reasoning', '') or msg.get('reasoning_content', '') or ''
total = content + reasoning
if len(total) > 10:
    print(f'模型回答正常 (content: {len(content)} 字符, reasoning: {len(reasoning)} 字符)')
    preview = content[:100] if content else reasoning[:100]
    print(f'回答预览: {preview}...')
    sys.exit(0)
else:
    print(f'回答异常: {resp}')
    sys.exit(1)
" 2>/dev/null; then
    log_info "模型验证通过 ✓"
else
    log_error "模型回答验证失败!"
    log_error "响应内容: ${VERIFY_RESPONSE}"
    exit 1
fi

# --- 导出服务日志路径供后续使用 ---
export SERVICE_LOG_PATH="${SERVICE_LOG}"
log_info "Phase 4 完成 ✓"
