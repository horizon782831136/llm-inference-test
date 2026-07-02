# 通用测试性能测试脚本
MODEL_NAME="Qwen3.5-35B"
input_len=2600
output_len=30
tokenizer_path="/models/Qwen3.5-35B-A3B"
LOG_FILE="perf.log"

evalscope perf \
    --url http://0.0.0.0:8810/v1/chat/completions \
    --model ${MODEL_NAME} \
    --dataset random \
    --api-key "" \
    --parallel 10 \
    --number 1000  \
    --temperature 0.7 \
    --max-prompt-length "${input_len}" \
    --min-prompt-length "${input_len}" \
    --max-tokens "${output_len}" \
    --min-tokens "${output_len}" \
    --prefix-length 0 \
    --tokenizer-path "${tokenizer_path}" \
    --name ${MODEL_NAME} # > "${LOG_FILE}" 2>&1