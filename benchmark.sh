#!/bin/bash
# 智能号现场测试脚本
MODEL_NAME=DeepSeek-V4-Flash-INT8
tokenizer_path=/ssd4/models/DeepSeek-V4-Flash-INT8

#====gr1===
input_len=9000
output_len=100

TIME_STAMP=$(date '+%Y%m%d_%H%M%S')

# Loop through rate and parallel combinations (rate:parallel pairs)
declare -A rate_parallel=(
    ["0.3"]=3
    ["0.5"]=5
    ["0.6"]=6
    ["0.7"]=7
    ["0.8"]=8
    ["1.0"]=10
    ["1.5"]=15
    ["2.0"]=20
    ["3.0"]=30
    ["4.0"]=40
    ["5.0"]=50
    ["10.0"]=100
    ["20.0"]=200
)

# Iterate through sorted keys to maintain order
for rate in $(echo "${!rate_parallel[@]}" | tr ' ' '\n' | sort -n); do
    parallel=${rate_parallel[$rate]}
    echo "Running with rate=$rate, parallel=$parallel"

    evalscope perf \
            --url http://127.0.0.1:30000/v1/completions \
            --model ${MODEL_NAME} \
            --dataset random \
            --api-key "" \
            --parallel ${parallel} \
            --rate "${rate}"  \
            --number 200 \
            --temperature 0.7 \
            --max-prompt-length "${input_len}" \
            --min-prompt-length "${input_len}" \
            --max-tokens "${output_len}" \
            --min-tokens "${output_len}" \
            --prefix-length 0 \
            --tokenizer-path "${tokenizer_path}" \
            --name ${MODEL_NAME}
    echo "Finished rate=$rate, parallel=$parallel, num=200"
    echo "-----------------------------------"
done

echo "All runs completed!"

