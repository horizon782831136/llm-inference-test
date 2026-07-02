docker run \
    --privileged \
    --name=lw_qwen \
    --ulimit core=-1 --security-opt seccomp=unconfined \
    -dti \
    --entrypoint='/bin/bash' \
    --gpus all \
    --net=host --uts=host --ipc=host \
    -v $(pwd):/dir \
    -v /ssd1:/ssd1/ \
    -v /ssd2:/ssd2/ \
    -v /ssd3:/ssd3/ \
    -v /ssd4:/ssd4/ \
    -w /dir \
    --shm-size=256g \
    --restart=always \
    vllm/vllm-openai:v0.17.0
