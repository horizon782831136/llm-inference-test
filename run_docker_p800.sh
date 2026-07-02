# P800镜像
#!/bin/bash
# 修改docker name
readonly CONTAINER_NAME="lw_xsgl_056_20260512_386"

readonly DOCKER_IMAGE="iregistry.baidu-int.com/xpu/sglang-p800-pd-disagg-056:20260512_386"

### 修改成自己的工作目录，并确保xvllm产出包和examples脚本压缩包在内
readonly Workspace="$(pwd)"

XPU_NUM=8
DOCKER_DEVICE_CONFIG=" "
if [ $XPU_NUM -gt 0 ]; then
for ((idx=0; idx<=$XPU_NUM-1; idx++)); do
        DOCKER_DEVICE_CONFIG+=" --device=/dev/xpu${idx}:/dev/xpu${idx} "
done
DOCKER_DEVICE_CONFIG+=" --device=/dev/xpuctrl:/dev/xpuctrl "
fi

# 可以继续添加-v 挂载其他磁盘, 比如内部用户可以添加 -v /klxlake:/klxlake
# 启动docker时候，注意要新增‘--privileged’确保容器内可以看到设备节点
docker run -it ${DOCKER_DEVICE_CONFIG}                         \
        --privileged                                           \
        --net=host                                             \
        -dti \
        --cap-add=SYS_PTRACE --security-opt seccomp=unconfined \
        --tmpfs /dev/shm:rw,nosuid,nodev,exec,size=32g         \
        --cap-add=SYS_PTRACE                                   \
        -v ${Workspace}:/dir                             \
        -v /ssd3:/ssd3                             \
        -v /ssd1:/ssd1 \
        -v /ssd2:/ssd2 \
 	    -v /ssd4:/ssd4 \
        --name ${CONTAINER_NAME}                               \
        -w /dir                                          \
        --restart=always \
        ${DOCKER_IMAGE} /bin/bash
