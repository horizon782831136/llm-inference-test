#!/bin/bash
# ============================================================
# Phase 3: 容器创建
# 根据硬件类型创建对应的 Docker 容器
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

log_step "Phase 3: 容器创建"

# --- 参数 ---
HW_TYPE="${CFG_HARDWARE_TYPE:-auto}"
CONTAINER_NAME="${CFG_CONTAINER_NAME:-lw_test}"
IMAGE_ID="${CFG_IMAGE_ID:-}"
WORKSPACE="${CFG_WORKSPACE:-$(pwd)}"
XPU_NUM="${CFG_XPU_NUM:-8}"
SHM_SIZE="${CFG_SHARED_MEMORY_SIZE:-256g}"
TMPFS_SIZE="${CFG_TMPFS_SIZE:-32g}"
EXTRA_VOLUMES="${CFG_EXTRA_VOLUMES:-}"

# 自动检测硬件（如果设为auto）
if [[ "$HW_TYPE" == "auto" ]]; then
    if command -v xpu-smi &>/dev/null && xpu-smi &>/dev/null; then
        HW_TYPE="p800"
    elif command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; then
        HW_TYPE="h20"
    else
        log_error "无法自动检测硬件类型!"
        exit 1
    fi
    log_info "自动检测到硬件: ${HW_TYPE}"
fi

# --- 检查容器是否已存在 ---
if container_running "$CONTAINER_NAME"; then
    log_info "容器 ${CONTAINER_NAME} 已在运行中，跳过创建"
    exit 0
fi

if container_exists "$CONTAINER_NAME"; then
    log_warn "容器 ${CONTAINER_NAME} 已存在但未运行，尝试启动..."
    docker start "$CONTAINER_NAME"
    if container_running "$CONTAINER_NAME"; then
        log_info "容器启动成功"
        exit 0
    else
        log_warn "启动失败，删除旧容器并重新创建..."
        docker rm -f "$CONTAINER_NAME"
    fi
fi

# --- 构建额外挂载参数 ---
build_extra_volumes() {
    local vol_args=""
    if [[ -n "$EXTRA_VOLUMES" ]]; then
        IFS=',' read -ra vols <<< "$EXTRA_VOLUMES"
        for v in "${vols[@]}"; do
            vol_args+=" -v ${v}"
        done
    fi
    echo "$vol_args"
}

EXTRA_VOL_ARGS=$(build_extra_volumes)

# --- 创建容器 ---
case "$HW_TYPE" in
    p800)
        log_info "创建 P800 (昆仑XPU) 容器..."

        # 构建设备映射
        DEVICE_ARGS=""
        for ((idx=0; idx<XPU_NUM; idx++)); do
            DEVICE_ARGS+=" --device=/dev/xpu${idx}:/dev/xpu${idx}"
        done
        DEVICE_ARGS+=" --device=/dev/xpuctrl:/dev/xpuctrl"

        docker run -it ${DEVICE_ARGS} \
            --privileged \
            --net=host \
            -dti \
            --cap-add=SYS_PTRACE --security-opt seccomp=unconfined \
            --tmpfs /dev/shm:rw,nosuid,nodev,exec,size=${TMPFS_SIZE} \
            -v "${WORKSPACE}:/dir" \
            -v /ssd1:/ssd1 \
            -v /ssd2:/ssd2 \
            -v /ssd3:/ssd3 \
            -v /ssd4:/ssd4 \
            ${EXTRA_VOL_ARGS} \
            --name "${CONTAINER_NAME}" \
            -w /dir \
            --restart=always \
            "${IMAGE_ID}" /bin/bash
        ;;
    h20)
        log_info "创建 H20 (NVIDIA GPU) 容器..."

        docker run \
            --privileged \
            --name="${CONTAINER_NAME}" \
            --ulimit core=-1 --security-opt seccomp=unconfined \
            -dti \
            --entrypoint='/bin/bash' \
            --gpus all \
            --net=host --uts=host --ipc=host \
            -v "${WORKSPACE}:/dir" \
            -v /ssd1:/ssd1 \
            -v /ssd2:/ssd2 \
            -v /ssd3:/ssd3 \
            -v /ssd4:/ssd4 \
            ${EXTRA_VOL_ARGS} \
            -w /dir \
            --shm-size="${SHM_SIZE}" \
            --restart=always \
            "${IMAGE_ID}"
        ;;
    *)
        log_error "不支持的硬件类型: ${HW_TYPE}"
        exit 1
        ;;
esac

# --- 验证容器已启动 ---
sleep 2
if container_running "$CONTAINER_NAME"; then
    log_info "容器创建成功: ${CONTAINER_NAME}"
    log_info "  硬件类型: ${HW_TYPE}"
    log_info "  镜像: ${IMAGE_ID}"
    log_info "  工作目录: /dir (-> ${WORKSPACE})"
else
    log_error "容器创建失败!"
    docker logs "$CONTAINER_NAME" 2>&1 | tail -20
    exit 1
fi

log_info "Phase 3 完成 ✓"
