#!/bin/bash
# ============================================================
# 公共工具函数库
# ============================================================
set -o pipefail

# --- 颜色输出 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info()  { echo -e "${GREEN}[INFO]${NC} $(date '+%H:%M:%S') $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $(date '+%H:%M:%S') $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $(date '+%H:%M:%S') $*"; }
log_step()  { echo -e "${BLUE}[STEP]${NC} $(date '+%H:%M:%S') ========== $* =========="; }

# --- 配置解析 ---
# 简易YAML解析（支持基本键值对），复杂结构用 yq 或 python
parse_yaml() {
    local yaml_file="$1"
    local prefix="${2:-CFG_}"

    # 使用 python 解析 yaml（更可靠）
    python3 -c "
import yaml, sys, os

with open('${yaml_file}') as f:
    config = yaml.safe_load(f)

def flatten(d, parent_key='', sep='_'):
    items = []
    for k, v in d.items():
        new_key = (parent_key + sep + k) if parent_key else k
        if isinstance(v, dict):
            items.extend(flatten(v, new_key, sep).items())
        elif isinstance(v, list):
            items.append((new_key, ' '.join(str(i) for i in v)))
        elif isinstance(v, bool):
            items.append((new_key, 'true' if v else 'false'))
        elif v is None:
            items.append((new_key, ''))
        else:
            items.append((new_key, str(v)))
    return dict(items)

flat = flatten(config)
for k, v in flat.items():
    print(f'${prefix}{k.upper()}=\"{v}\"')
" 2>/dev/null
}

# 加载配置到当前shell
load_config() {
    local config_file="${1:-config.yaml}"
    if [[ ! -f "$config_file" ]]; then
        log_error "配置文件不存在: $config_file"
        return 1
    fi
    eval "$(parse_yaml "$config_file" "CFG_")"
    log_info "已加载配置: $config_file"
}

# 获取配置值（带默认值）
get_config() {
    local key="CFG_${1^^}"
    local default="${2:-}"
    local val="${!key:-$default}"
    echo "$val"
}

# --- 重试机制 ---
retry() {
    local max_attempts="${1}"
    local delay="${2}"
    shift 2
    local attempt=1

    while [[ $attempt -le $max_attempts ]]; do
        if "$@"; then
            return 0
        fi
        log_warn "第 ${attempt}/${max_attempts} 次尝试失败，${delay}s 后重试..."
        sleep "$delay"
        ((attempt++))
    done
    log_error "重试 ${max_attempts} 次后仍然失败: $*"
    return 1
}

# --- 等待条件满足 ---
wait_for() {
    local description="$1"
    local timeout="$2"
    local interval="${3:-5}"
    shift 3

    log_info "等待: ${description} (超时: ${timeout}s)"
    local elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        if "$@" 2>/dev/null; then
            log_info "${description} - 就绪！(耗时 ${elapsed}s)"
            return 0
        fi
        sleep "$interval"
        ((elapsed += interval))
    done
    log_error "${description} - 超时！(${timeout}s)"
    return 1
}

# --- Docker 辅助 ---
container_exists() {
    docker ps -a --format '{{.Names}}' | grep -qw "$1"
}

container_running() {
    docker ps --format '{{.Names}}' | grep -qw "$1"
}

image_exists() {
    docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "$1"
}

exec_in_container() {
    local container="$1"
    shift
    docker exec "$container" bash -c "$*"
}

# --- 网络检测 ---
check_network() {
    local target="${1:-https://www.baidu.com}"
    curl -s --connect-timeout 5 -o /dev/null -w "%{http_code}" "$target" | grep -q "^[23]"
}

check_registry_access() {
    local registry="$1"
    # 去掉协议前缀，检测端口连通性
    local host="${registry#*//}"
    host="${host%%/*}"
    timeout 5 bash -c "echo > /dev/tcp/${host}/443" 2>/dev/null || \
    timeout 5 bash -c "echo > /dev/tcp/${host}/80" 2>/dev/null
}

# --- 时间戳 ---
timestamp() { date '+%Y%m%d_%H%M%S'; }
date_str()  { date '+%Y-%m-%d %H:%M:%S'; }

# --- 结果目录 ---
ensure_output_dir() {
    local base="${1:-./results}"
    mkdir -p "${base}/perf" "${base}/eval" "${base}/reports" "${base}/logs"
}
