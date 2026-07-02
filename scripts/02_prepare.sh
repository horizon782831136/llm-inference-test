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
IMAGE_SOURCE="${CFG_IMAGE_SOURCE:-registry}"
IMAGE_ID="${CFG_IMAGE_ID:-}"
IMAGE_URL="${CFG_IMAGE_URL:-}"
IMAGE_TAR_PATH="${CFG_IMAGE_TAR_PATH:-}"

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

# ===== 镜像准备 =====
prepare_image() {
    log_info "--- 镜像准备 ---"

    case "$IMAGE_SOURCE" in
        registry)
            if [[ -z "$IMAGE_ID" ]]; then
                log_error "image_id 未配置!"
                return 1
            fi
            # 检查镜像是否已存在
            if image_exists "$IMAGE_ID"; then
                log_info "镜像已存在: ${IMAGE_ID}"
                return 0
            fi
            # 检查网络
            local registry_host="${IMAGE_ID%%/*}"
            if ! check_network; then
                log_error "网络不可达! 请设置代理后重试:"
                log_error "  export http_proxy=http://your-proxy:port"
                log_error "  export https_proxy=http://your-proxy:port"
                return 1
            fi
            log_info "拉取镜像: ${IMAGE_ID}"
            docker pull "$IMAGE_ID"
            ;;
        tar)
            if [[ -z "$IMAGE_TAR_PATH" || ! -f "$IMAGE_TAR_PATH" ]]; then
                log_error "tar 文件不存在: ${IMAGE_TAR_PATH}"
                return 1
            fi
            log_info "导入镜像 (tar): ${IMAGE_TAR_PATH}"
            docker load -i "$IMAGE_TAR_PATH"
            ;;
        tar_gz)
            if [[ -z "$IMAGE_TAR_PATH" || ! -f "$IMAGE_TAR_PATH" ]]; then
                log_error "tar.gz 文件不存在: ${IMAGE_TAR_PATH}"
                return 1
            fi
            log_info "解压并导入镜像 (tar.gz): ${IMAGE_TAR_PATH}"
            local tar_file="${IMAGE_TAR_PATH%.gz}"
            tar -xzvf "$IMAGE_TAR_PATH" -C "$(dirname "$IMAGE_TAR_PATH")"
            # 找到解压后的 tar 文件
            if [[ -f "$tar_file" ]]; then
                docker load -i "$tar_file"
                rm -f "$tar_file"  # 清理解压后的中间文件
            else
                # 尝试找到目录下的 .tar 文件
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
                log_error "image_url 未配置!"
                return 1
            fi
            if ! check_network; then
                log_error "网络不可达! 请设置代理后重试。"
                return 1
            fi
            log_info "下载镜像: ${IMAGE_URL}"
            local download_path="/tmp/image_download_$(timestamp).tar"
            # 判断是否是 .tar.gz
            if [[ "$IMAGE_URL" == *.tar.gz ]]; then
                download_path="${download_path}.gz"
            fi
            wget -O "$download_path" "$IMAGE_URL"
            if [[ $? -ne 0 ]]; then
                log_error "镜像下载失败!"
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

    log_info "镜像准备完成 ✓"
}

# ===== evalscope 安装 =====
ensure_evalscope() {
    log_info "--- 检查 evalscope ---"
    if command -v evalscope &>/dev/null; then
        local ver
        ver=$(evalscope --version 2>/dev/null || pip show evalscope 2>/dev/null | grep Version | awk '{print $2}')
        log_info "evalscope 已安装: ${ver}"
        return 0
    fi
    log_info "安装 evalscope..."
    pip install evalscope -q
    if command -v evalscope &>/dev/null; then
        log_info "evalscope 安装完成 ✓"
    else
        log_warn "evalscope 安装可能未成功，请手动检查"
    fi
}

# --- 主逻辑 ---
prepare_model || exit 1
prepare_image || exit 1
ensure_evalscope

log_info "Phase 2 完成 ✓"
