#!/bin/bash
# ============================================================
# Phase 4: 服务启动与验证
# 在容器内启动推理服务，并通过curl验证服务可用
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

log_step "Phase 4: 服务启动与验证"

# --- 参数 ---
CONTAINER_NAME="${CFG_CONTAINER_NAME:-lw_test}"
SERVICE_SCRIPT="${CFG_SERVICE_SCRIPT:-}"
SERVICE_PORT="${CFG_SERVICE_PORT:-30000}"
SERVICE_TIMEOUT="${CFG_SERVICE_TIMEOUT:-600}"
MODEL_NAME="${CFG_MODEL_NAME:-}"
MODEL_PATH="${CFG_MODEL_PATH:-}"

# --- 检查容器运行状态 ---
if ! container_running "$CONTAINER_NAME"; then
    log_error "容器 ${CONTAINER_NAME} 未运行!"
    exit 1
fi

# --- 启动服务 ---
if [[ -n "$SERVICE_SCRIPT" ]]; then
    log_info "在容器内启动服务: ${SERVICE_SCRIPT}"
    # 在容器内后台执行服务脚本
    docker exec -d "$CONTAINER_NAME" bash -c "cd /dir && bash ${SERVICE_SCRIPT} > /dir/service.log 2>&1"
    log_info "服务启动命令已发送"
else
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
    log_error "容器内服务日志:"
    docker exec "$CONTAINER_NAME" tail -50 /dir/service.log 2>/dev/null || true
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
content = resp.get('choices', [{}])[0].get('message', {}).get('content', '')
if len(content) > 10:
    print(f'模型回答正常 (长度: {len(content)} 字符)')
    print(f'回答预览: {content[:100]}...')
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

log_info "Phase 4 完成 ✓"
