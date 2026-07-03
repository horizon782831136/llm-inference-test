#!/bin/bash
# ============================================================
# Phase 2: 模型与镜像准备
# 处理模型下载、镜像拉取/导入、evalscope安装
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

log_step "Phase 2: 模型与镜像准备"

# --- 参数（由 workflow.sh 传入或从config读取） ---
MODEL_DOWNLOAD_SOURCE="${CFG_MODEL_DOWNLOAD_SOURCE:-}"
MODEL_DOWNLOAD_ID="${CFG_MODEL_DOWNLOAD_ID:-}"
MODEL_PATH="${CFG_MODEL_PATH:-}"

# 服务镜像
SVC_IMAGE_SOURCE="${CFG_SERVICE_IMAGE_SOURCE:-registry}"
SVC_IMAGE_ID="${CFG_SERVICE_IMAGE_ID:-}"
SVC_IMAGE_URL="${CFG_SERVICE_IMAGE_URL:-}"
SVC_IMAGE_TAR_PATH="${CFG_SERVICE_IMAGE_TAR_PATH:-}"

# 测试镜像
TEST_IMAGE_SOURCE="${CFG_TEST_IMAGE_SOURCE:-registry}"
TEST_IMAGE_ID="${CFG_TEST_IMAGE_ID:-iregistry.baidu-int.com/xpu/infer_qa:v4.0}"
TEST_IMAGE_URL="${CFG_TEST_IMAGE_URL:-}"
TEST_IMAGE_TAR_PATH="${CFG_TEST_IMAGE_TAR_PATH:-}"

# ===== 模型准备 =====
prepare_model() {
    log_info "--- 模型准备 ---"

    if [[ -z "$MODEL_DOWNLOAD_SOURCE" ]]; then
        # 已有模型，验证路径
        if [[ -n "$MODEL_PATH" && -d "$MODEL_PATH" ]]; then
            log_info "模型路径已存在: ${MODEL_PATH}"
            return 0
        elif [[ -n "$MODEL_PATH" ]]; then
            log_error "指定的模型路径不存在: ${MODEL_PATH}"
            return 1
        fi
        log_info "未指定模型路径，跳过模型准备"
        return 0
    fi

    case "$MODEL_DOWNLOAD_SOURCE" in
        modelscope)
            log_info "从 ModelScope 下载模型: ${MODEL_DOWNLOAD_ID}"
            if ! command -v modelscope &>/dev/null; then
                log_info "安装 modelscope CLI..."
                pip install modelscope -q
            fi
            local target_dir="${MODEL_PATH:-./models}"
            mkdir -p "$target_dir"
            modelscope download --model "$MODEL_DOWNLOAD_ID" --local_dir "$target_dir"
            if [[ $? -eq 0 ]]; then
                log_info "模型下载完成: ${target_dir}"
            else
                log_error "模型下载失败!"
                return 1
            fi
            ;;
        *)
            log_warn "未知的下载源: ${MODEL_DOWNLOAD_SOURCE}，跳过"
            ;;
    esac
}

# ===== 镜像准备（通用函数） =====
prepare_single_image() {
    local role="$1"       # "服务" or "测试"
    local IMAGE_SOURCE="$2"
    local IMAGE_ID="$3"
    local IMAGE_URL="$4"
    local IMAGE_TAR_PATH="$5"

    log_info "--- ${role}镜像准备 ---"

    case "$IMAGE_SOURCE" in
        registry)
            if [[ -z "$IMAGE_ID" ]]; then
                log_error "${role}镜像 image_id 未配置!"
                return 1
            fi
            if image_exists "$IMAGE_ID"; then
                log_info "${role}镜像已存在: ${IMAGE_ID}"
                return 0
            fi
            if ! check_network; then
                log_error "网络不可达! 请设置代理后重试:"
                log_error "  export http_proxy=http://your-proxy:port"
                log_error "  export https_proxy=http://your-proxy:port"
                return 1
            fi
            log_info "拉取${role}镜像: ${IMAGE_ID}"
            docker pull "$IMAGE_ID"
            ;;
        tar)
            if [[ -z "$IMAGE_TAR_PATH" || ! -f "$IMAGE_TAR_PATH" ]]; then
                log_error "${role}镜像 tar 文件不存在: ${IMAGE_TAR_PATH}"
                return 1
            fi
            log_info "导入${role}镜像 (tar): ${IMAGE_TAR_PATH}"
            docker load -i "$IMAGE_TAR_PATH"
            ;;
        tar_gz)
            if [[ -z "$IMAGE_TAR_PATH" || ! -f "$IMAGE_TAR_PATH" ]]; then
                log_error "${role}镜像 tar.gz 文件不存在: ${IMAGE_TAR_PATH}"
                return 1
            fi
            log_info "解压并导入${role}镜像 (tar.gz): ${IMAGE_TAR_PATH}"
            local tar_file="${IMAGE_TAR_PATH%.gz}"
            tar -xzvf "$IMAGE_TAR_PATH" -C "$(dirname "$IMAGE_TAR_PATH")"
            if [[ -f "$tar_file" ]]; then
                docker load -i "$tar_file"
                rm -f "$tar_file"
            else
                local found_tar
                found_tar=$(find "$(dirname "$IMAGE_TAR_PATH")" -maxdepth 1 -name "*.tar" -newer "$IMAGE_TAR_PATH" | head -1)
                if [[ -n "$found_tar" ]]; then
                    docker load -i "$found_tar"
                else
                    log_error "解压后未找到 .tar 文件"
                    return 1
                fi
            fi
            ;;
        url)
            if [[ -z "$IMAGE_URL" ]]; then
                log_error "${role}镜像 image_url 未配置!"
                return 1
            fi
            if ! check_network; then
                log_error "网络不可达! 请设置代理后重试。"
                return 1
            fi
            log_info "下载${role}镜像: ${IMAGE_URL}"
            local download_path="/tmp/image_download_$(timestamp).tar"
            if [[ "$IMAGE_URL" == *.tar.gz ]]; then
                download_path="${download_path}.gz"
            fi
            wget -O "$download_path" "$IMAGE_URL"
            if [[ $? -ne 0 ]]; then
                log_error "${role}镜像下载失败!"
                return 1
            fi
            if [[ "$download_path" == *.gz ]]; then
                log_info "解压下载的镜像..."
                gunzip "$download_path"
                download_path="${download_path%.gz}"
            fi
            docker load -i "$download_path"
            rm -f "$download_path"
            ;;
        *)
            log_error "未知的 image_source: ${IMAGE_SOURCE}"
            return 1
            ;;
    esac

    log_info "${role}镜像准备完成 ✓"
}

# ===== evalscope 安装（在测试容器内） =====
ensure_evalscope() {
    local test_container="${CFG_TEST_CONTAINER_NAME:-lw_qa_infer}"

    log_info "--- 检查测试容器内 evalscope ---"

    # 检查测试容器是否运行中
    if ! container_running "$test_container"; then
        log_warn "测试容器 ${test_container} 未运行，将在 Phase 5 前自动检查"
        return 0
    fi

    # 直接将 conda env 的 bin 目录加入 PATH（避免 conda activate 的各种兼容问题）
    local env_bin="/root/miniconda/envs/evalscope_env/bin"

    if docker exec "$test_container" bash -c "export PATH=${env_bin}:\$PATH && pip show evalscope" &>/dev/null; then
        local ver
        ver=$(docker exec "$test_container" bash -c "export PATH=${env_bin}:\$PATH && pip show evalscope 2>/dev/null | grep Version | awk '{print \$2}'" 2>/dev/null)
        log_info "测试容器内 evalscope 已安装: ${ver}"
        return 0
    fi

    log_info "在测试容器内安装 evalscope..."
    docker exec "$test_container" bash -c "export PATH=${env_bin}:\$PATH && pip install evalscope 'evalscope[perf]' -i https://repo.huaweicloud.com/repository/pypi/simple" 2>&1

    if docker exec "$test_container" bash -c "export PATH=${env_bin}:\$PATH && pip show evalscope" &>/dev/null; then
        log_info "evalscope 安装完成 ✓"
    else
        log_warn "evalscope 安装可能未成功，请手动进入测试容器检查: docker exec -it ${test_container} bash"
    fi
}

# --- 主逻辑 ---
prepare_model || exit 1

# 准备服务镜像
prepare_single_image "服务" "$SVC_IMAGE_SOURCE" "$SVC_IMAGE_ID" "$SVC_IMAGE_URL" "$SVC_IMAGE_TAR_PATH" || exit 1

# 准备测试镜像
prepare_single_image "测试" "$TEST_IMAGE_SOURCE" "$TEST_IMAGE_ID" "$TEST_IMAGE_URL" "$TEST_IMAGE_TAR_PATH" || exit 1

ensure_evalscope

log_info "Phase 2 完成 ✓"
