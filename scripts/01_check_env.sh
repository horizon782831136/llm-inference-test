#!/bin/bash
# ============================================================
# Phase 1: 环境检测
# 检测硬件类型、驱动版本、设备数量、磁盘空间、网络状态
# 输出: results/env_report.json
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

log_step "Phase 1: 环境检测"

OUTPUT_DIR="${1:-./results}"
REPORT_FILE="${OUTPUT_DIR}/env_report.json"
mkdir -p "$OUTPUT_DIR"

# --- 检测硬件类型 ---
detect_hardware() {
    if command -v xpu-smi &>/dev/null && xpu-smi &>/dev/null; then
        echo "p800"
    elif command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; then
        echo "h20"
    else
        echo "unknown"
    fi
}

# --- 获取设备数量 ---
get_device_count() {
    local hw_type="$1"
    case "$hw_type" in
        p800)
            xpu-smi 2>/dev/null | grep -c "P800 OAM" || echo 0
            ;;
        h20)
            nvidia-smi -L 2>/dev/null | wc -l || echo 0
            ;;
        *)
            echo 0
            ;;
    esac
}

# --- 获取驱动版本 ---
get_driver_version() {
    local hw_type="$1"
    case "$hw_type" in
        p800)
            xpu-smi 2>/dev/null | grep "Driver Version" | sed 's/.*Driver Version: *//;s/ .*//'
            ;;
        h20)
            nvidia-smi 2>/dev/null | grep "Driver Version" | sed 's/.*Driver Version: *//;s/ .*//'
            ;;
        *)
            echo "N/A"
            ;;
    esac
}

# --- 获取磁盘空间 ---
get_disk_info() {
    local mount_points=("/ssd1" "/ssd2" "/ssd3" "/ssd4")
    local disk_json="{"
    local first=true

    for mp in "${mount_points[@]}"; do
        if mountpoint -q "$mp" 2>/dev/null || [[ -d "$mp" ]]; then
            local avail
            avail=$(df -BG "$mp" 2>/dev/null | tail -1 | awk '{print $4}' | tr -d 'G')
            local total
            total=$(df -BG "$mp" 2>/dev/null | tail -1 | awk '{print $2}' | tr -d 'G')
            if [[ "$first" == "true" ]]; then
                first=false
            else
                disk_json+=","
            fi
            disk_json+="\"${mp}\":{\"total_gb\":${total:-0},\"available_gb\":${avail:-0}}"
        fi
    done
    disk_json+="}"
    echo "$disk_json"
}

# --- 检测网络 ---
check_network_status() {
    local targets=("https://www.baidu.com" "https://modelscope.cn" "https://iregistry.baidu-int.com")
    local net_json="{"
    local first=true

    for target in "${targets[@]}"; do
        local status="false"
        if curl -s --connect-timeout 5 -o /dev/null "$target" 2>/dev/null; then
            status="true"
        fi
        if [[ "$first" == "true" ]]; then
            first=false
        else
            net_json+=","
        fi
        net_json+="\"${target}\":${status}"
    done
    net_json+="}"
    echo "$net_json"
}

# --- 检测 Docker ---
check_docker() {
    if command -v docker &>/dev/null && docker info &>/dev/null; then
        echo "true"
    else
        echo "false"
    fi
}

# --- 主逻辑 ---
HW_TYPE=$(detect_hardware)
DEVICE_COUNT=$(get_device_count "$HW_TYPE")
DRIVER_VERSION=$(get_driver_version "$HW_TYPE")
DISK_INFO=$(get_disk_info)
NETWORK_STATUS=$(check_network_status)
DOCKER_OK=$(check_docker)
HOSTNAME_STR=$(hostname)
KERNEL_VER=$(uname -r)

log_info "硬件类型: ${HW_TYPE}"
log_info "设备数量: ${DEVICE_COUNT}"
log_info "驱动版本: ${DRIVER_VERSION}"
log_info "Docker可用: ${DOCKER_OK}"

# 生成 JSON 报告
cat > "$REPORT_FILE" <<EOF
{
  "timestamp": "$(date_str)",
  "hostname": "${HOSTNAME_STR}",
  "kernel": "${KERNEL_VER}",
  "hardware_type": "${HW_TYPE}",
  "device_count": ${DEVICE_COUNT},
  "driver_version": "${DRIVER_VERSION}",
  "docker_available": ${DOCKER_OK},
  "disk": ${DISK_INFO},
  "network": ${NETWORK_STATUS}
}
EOF

log_info "环境报告已生成: ${REPORT_FILE}"

# --- 检查结果 ---
if [[ "$HW_TYPE" == "unknown" ]]; then
    log_error "无法识别硬件类型! 请确认 xpu-smi 或 nvidia-smi 可用。"
    exit 1
fi

if [[ "$DOCKER_OK" == "false" ]]; then
    log_error "Docker 不可用! 请先安装或启动 Docker。"
    exit 1
fi

# 检测网络并给出代理提示
if echo "$NETWORK_STATUS" | grep -q '"false"'; then
    log_warn "部分网络目标不可达，可能需要设置代理:"
    log_warn "  export http_proxy=http://your-proxy:port"
    log_warn "  export https_proxy=http://your-proxy:port"
fi

log_info "Phase 1 完成 ✓"
echo "$HW_TYPE"  # 返回硬件类型供后续脚本使用
