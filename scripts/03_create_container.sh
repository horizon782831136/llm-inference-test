#!/bin/bash
# ============================================================
# Phase 3: 容器创建
# 创建两个容器：
#   1. 服务容器 - 运行推理服务（参考 run_docker_p800.sh / run_docker_h20.sh）
#   2. 测试容器 - 运行性能/精度测试（参考 run_docker_test.sh）
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

log_step "Phase 3: 容器创建"

# --- 公共参数 ---
HW_TYPE="${CFG_HARDWARE_TYPE:-auto}"
WORKSPACE="${CFG_WORKSPACE:-$(pwd)}"
XPU_NUM="${CFG_XPU_NUM:-8}"

# --- 服务容器参数 ---
SVC_CONTAINER="${CFG_SERVICE_CONTAINER_NAME:-lw_sglang}"
SVC_IMAGE="${CFG_SERVICE_IMAGE_ID:-}"
SVC_SHM_SIZE="${CFG_SERVICE_SHARED_MEMORY_SIZE:-256g}"
SVC_TMPFS_SIZE="${CFG_SERVICE_TMPFS_SIZE:-32g}"
SVC_EXTRA_VOLUMES="${CFG_SERVICE_EXTRA_VOLUMES:-}"

# --- 测试容器参数 ---
TEST_CONTAINER="${CFG_TEST_CONTAINER_NAME:-lw_qa_infer}"
TEST_IMAGE="${CFG_TEST_IMAGE_ID:-iregistry.baidu-int.com/xpu/infer_qa:v4.0}"
TEST_SHM_SIZE="${CFG_TEST_SHARED_MEMORY_SIZE:-256g}"
TEST_TMPFS_SIZE="${CFG_TEST_TMPFS_SIZE:-32g}"
TEST_EXTRA_VOLUMES="${CFG_TEST_EXTRA_VOLUMES:-}"

# --- 自动检测硬件 ---
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

# --- 构建额外挂载参数 ---
build_extra_volumes() {
    local extra="$1"
    local vol_args=""
    if [[ -n "$extra" ]]; then
        IFS=',' read -ra vols <<< "$extra"
        for v in "${vols[@]}"; do
            vol_args+=" -v ${v}"
        done
    fi
    echo "$vol_args"
}

# --- 创建 P800 容器（通用函数） ---
create_p800_container() {
    local name="$1"
    local image="$2"
    local tmpfs_size="$3"
    local extra_vols="$4"

    DEVICE_ARGS=""
    for ((idx=0; idx<XPU_NUM; idx++)); do
        DEVICE_ARGS+=" --device=/dev/xpu${idx}:/dev/xpu${idx}"
    done
    DEVICE_ARGS+=" --device=/dev/xpuctrl:/dev/xpuctrl"

    local EXTRA_VOL_ARGS
    EXTRA_VOL_ARGS=$(build_extra_volumes "$extra_vols")

    docker run -it ${DEVICE_ARGS} \
        --privileged \
        --net=host \
        -dti \
        --cap-add=SYS_PTRACE --security-opt seccomp=unconfined \
        --tmpfs /dev/shm:rw,nosuid,nodev,exec,size=${tmpfs_size} \
        --cap-add=SYS_PTRACE \
        -v "${WORKSPACE}:/dir" \
        -v /ssd1:/ssd1 \
        -v /ssd2:/ssd2 \
        -v /ssd3:/ssd3 \
        -v /ssd4:/ssd4 \
        ${EXTRA_VOL_ARGS} \
        --name "${name}" \
        -w /dir \
        --restart=always \
        "${image}" /bin/bash
}

# --- 创建 H20 容器（通用函数） ---
create_h20_container() {
    local name="$1"
    local image="$2"
    local shm_size="$3"
    local extra_vols="$4"

    local EXTRA_VOL_ARGS
    EXTRA_VOL_ARGS=$(build_extra_volumes "$extra_vols")

    docker run \
        --privileged \
        --name="${name}" \
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
        --shm-size="${shm_size}" \
        --restart=always \
        "${image}"
}

# --- 启动或创建单个容器 ---
ensure_container() {
    local name="$1"
    local image="$2"
    local role="$3"  # "服务" or "测试"
    local shm_size="$4"
    local tmpfs_size="$5"
    local extra_vols="$6"

    if container_running "$name"; then
        log_info "${role}容器 ${name} 已在运行中，跳过创建"
        return 0
    fi

    if container_exists "$name"; then
        log_warn "${role}容器 ${name} 已存在但未运行，尝试启动..."
        docker start "$name"
        if container_running "$name"; then
            log_info "${role}容器启动成功"
            return 0
        else
            log_warn "启动失败，删除旧容器并重新创建..."
            docker rm -f "$name"
        fi
    fi

    log_info "创建${role}容器: ${name} (镜像: ${image})"

    case "$HW_TYPE" in
        p800)
            create_p800_container "$name" "$image" "$tmpfs_size" "$extra_vols"
            ;;
        h20)
            create_h20_container "$name" "$image" "$shm_size" "$extra_vols"
            ;;
        *)
            log_error "不支持的硬件类型: ${HW_TYPE}"
            return 1
            ;;
    esac

    sleep 2
    if container_running "$name"; then
        log_info "${role}容器创建成功: ${name} ✓"
    else
        log_error "${role}容器创建失败!"
        docker logs "$name" 2>&1 | tail -20
        return 1
    fi
}

# ===== 创建服务容器 =====
log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_info "步骤 1/2: 创建服务容器"
ensure_container "$SVC_CONTAINER" "$SVC_IMAGE" "服务" "$SVC_SHM_SIZE" "$SVC_TMPFS_SIZE" "$SVC_EXTRA_VOLUMES" || exit 1

# ===== 创建测试容器 =====
log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_info "步骤 2/2: 创建测试容器"
ensure_container "$TEST_CONTAINER" "$TEST_IMAGE" "测试" "$TEST_SHM_SIZE" "$TEST_TMPFS_SIZE" "$TEST_EXTRA_VOLUMES" || exit 1

# --- 汇总 ---
log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_info "容器创建完成:"
log_info "  服务容器: ${SVC_CONTAINER} (${SVC_IMAGE})"
log_info "  测试容器: ${TEST_CONTAINER} (${TEST_IMAGE})"
log_info "  硬件类型: ${HW_TYPE}"
log_info "  工作目录: /dir (-> ${WORKSPACE})"
log_info "Phase 3 完成 ✓"
