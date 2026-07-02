#!/bin/bash
set -euo pipefail
# 通用精度测试脚本
# ============================================================
# 使用说明
#   1. DATASETS_TO_RUN：取消注释 = 启用，注释 = 跳过
#   2. generation-config 参数对所有数据集统一生效
#      如需单独覆盖某数据集的 max_tokens，写入 MAX_TOKENS_OVERRIDE
#   3. subset_list：在 SUBSET_LISTS 里配置，JSON 数组格式，留空 = 跑全量
#   4. THINKING_MODE: "true" 开启 / "false" 关闭 / "" 不传
#   5. Judge LLM: 通过环境变量或脚本内变量配置，留空则用被测模型自己当裁判
#      JUDGE_API_URL / JUDGE_API_KEY / JUDGE_MODEL_ID
#   6. 运行：
#      bash evalscope_test.sh
#      # 或指定外部 judge:
#      JUDGE_API_URL=https://xxx/v1/chat/completions \
#      JUDGE_API_KEY=your-key \
#      JUDGE_MODEL_ID=ernie-4.5-turbo-128k \
#      bash evalscope_test.sh
# ============================================================

# ===== 全局配置 =====
MODEL_NAME="DeepSeek-V4-Flash-INT4"
BASE_URL="http://127.0.0.1:8810"
EBS=128

# ===== generation-config =====
GEN_MAX_TOKENS=131072
GEN_TEMPERATURE=1.0
GEN_TOP_P=1.0
GEN_TOP_K=           # 留空 = 不传
THINKING_MODE="true" # "true" / "false" / ""

# avoid tau2 log flood
export LOGURU_LEVEL=INFO
mkdir -p logs
# ===== 评测数据集列表（取消注释 = 启用） =====
DATASETS_TO_RUN=(
  #aime24
  aime25
  gpqa_diamond
  #mmlu
  #mmlu_pro
  #bbh
  #ceval
  gsm8k
  #math_500
  humaneval
  #live_code_bench
  #ifeval
  #bfcl_v3
  #aime26
  #hmmt25
  #cmmlu
  #humaneval_plus
  #ifbench
  #mmlu_redux
  #mmmlu
  #super_gpqa       
  #tau2_bench      
  #bfcl_v4          # agent数据集
  #bfcl_v3          # agent数据集
  #tool_bench       # agent数据集
  #general_fc       # agent数据集
  #gsm8k_v          # vlm数据集
  #ocr_bench        # vlm数据集
  #hallusion_bench  # vlm数据集
  #ai2d             # vlm数据集
  #mm_star          # vlm数据集
  #mmmu_pro         # vlm数据集
  #mmmu             # vlm数据集
  #chartqa          # vlm数据集
  #simple_qa        # judge：自己当裁判， llm数据集
  #zerobench        # judge：自己当裁判， vlm数据集
  #hle              # judge：自己当裁判， llm数据集
  #aa_lcr           # judge：自己当裁判， llm数据集
  #chinese_simpleqa # judge：自己当裁判，llm数据集
  #longbench_v2     # 默认只跑 short 子集，medium/long 超出模型上下文
)

# ===== 本地数据集路径 =====
declare -A LOCAL_PATHS=(
  [aime24]="/data/evalscope/data/aime24/"
  [aime25]="/data/evalscope/data/aime25/"
  [aime26]="/data/evalscope/data/aime26/"
  [hle]="/data/evalscope/data/hle/"
  [super_gpqa]="/data/evalscope/data/SuperGPQA/"
  [gpqa_diamond]="/data/evalscope/data/gpqa/"
  [gsm8k]="/data/evalscope/data/gsm8k/"
  [mmlu]="/data/evalscope/data/mmlu/"
  [mmlu_pro]="/data/evalscope/data/MMLU-Pro"
  [bbh]="/data/evalscope/data/bbh"
  [ceval]="/data/evalscope/data/ceval"
  [humaneval]="/data/evalscope/data/humaneval/"
  [math_500]="/data/evalscope/data/math500/"
  [ifeval]="/data/evalscope/data/ifeval/"
  [bfcl_v3]="/data/evalscope/data/bfcl_v3/"
  [simple_qa]="/data/evalscope/data/simpleqa"
  [live_code_bench]="/data/evalscope/data/code_generation_lite"
  [longbench_v2]="/data/evalscope/data/LongBench-v2/"
  [chinese_simpleqa]="/data/evalscope/data/Chinese-SimpleQA/"
  [hmmt25]="/data/evalscope/data/hmmt_feb_2025/"
  [cmmlu]="/data/evalscope/data/cmmlu/"
  [humaneval_plus]="/data/evalscope/data/humanevalplus/"
  [ifbench]="/data/evalscope/data/IFBench_test/"
  [mmlu_redux]="/data/evalscope/data/mmlu-redux-2.0/"
  [mmmlu]="/data/evalscope/data/MMMLU/"
  [zerobench]="/data/evalscope/data/zerobench/"
  [ai2d]="/data/evalscope/data/ai2d/"
  [mm_star]="/data/evalscope/data/MMStar/"
  [mmmu_pro]="/data/evalscope/data/MMMU_Pro/"
  [mmmu]="/data/evalscope/data/MMMU/"
  [hallusion_bench]="/data/evalscope/data/HallusionBench/"
  [ocr_bench]="/data/evalscope/data/OCRBench/"
  [chartqa]="/data/evalscope/data/chartqa/"
  [tau2_bench]="/data/evalscope/data/tau2-bench-data/"
  [aa_lcr]="/data/evalscope/data/AA-LCR"
  [gsm8k_v]="/data/evalscope/data/GSM8K-V/"
  [tool_bench]="/data/evalscope/data/ToolBench-Static/"
  [general_fc]="/data/evalscope/data/GeneralFunctionCall-Test/"
  [bfcl_v4]=""
  [bfcl_v3]=""
)

# ===== 每数据集 subset_list（JSON 数组，留空 = 跑全量） =====
declare -A SUBSET_LISTS=(
  [live_code_bench]='["test6"]'
  [tau2_bench]='["retail", "airline", "telecom"]'
  [tool_bench]='["in_domain", "out_of_domain"]'
  [bfcl_v4]='["irrelevance", "live_irrelevance", "live_multiple"]'
  [longbench_v2]='["short"]'
)

# ===== 每数据集 max_tokens 覆盖（用于超长上下文数据集） =====
declare -A MAX_TOKENS_OVERRIDE=(
)

# ===== 额外 dataset-args（local_path/subset_list 已自动处理，勿重复填写） =====
declare -A EXTRA_DATASET_ARGS=(
  [tau2_bench]="{\"extra_params\": {\"user_model\": \"${MODEL_NAME}\", \"api_key\": \"EMPTY\", \"api_base\": \"${BASE_URL}/v1\"}}"
)

# ===== 需要 LLM Judge 的数据集 =====
JUDGE_DATASETS=(zerobench hle aa_lcr chinese_simpleqa simple_qa)

# ===== Judge LLM 配置（留空则用被测模型自己当裁判） =====
JUDGE_API_URL="${JUDGE_API_URL:-}"          # e.g. https://qianfan.baidubce.com/v2/chat/completions
JUDGE_API_KEY="${JUDGE_API_KEY:-}"          # e.g. bce-v3/ALTAK-xxx/xxx（不要带 Bearer 前缀）
JUDGE_MODEL_ID="${JUDGE_MODEL_ID:-}"        # e.g. ernie-4.5-turbo-128k

# ============================================================
# 辅助函数
# ============================================================

# 构建 generation-config JSON，可传入 max_tokens 覆盖全局值
build_generation_config() {
  local max_tokens="${1:-$GEN_MAX_TOKENS}"
  local json="{\"max_tokens\":${max_tokens},\"temperature\":${GEN_TEMPERATURE},\"top_p\":${GEN_TOP_P}"
  [[ -n "${GEN_TOP_K:-}" ]] && json+=",\"top_k\":${GEN_TOP_K}"
  if [[ "$THINKING_MODE" == "true" ]]; then
    json+=",\"extra_body\":{\"chat_template_kwargs\":{\"thinking\":true,\"enable_thinking\":true}}"
  elif [[ "$THINKING_MODE" == "false" ]]; then
    json+=",\"extra_body\":{\"chat_template_kwargs\":{\"thinking\":false,\"enable_thinking\":false}}"
  fi
  json+="}"
  echo "$json"
}

# 通用评测函数
run_dataset() {
  local dataset_name="$1"
  local timestamp; timestamp=$(date +%Y%m%d_%H%M%S)
  local local_path="${LOCAL_PATHS[$dataset_name]:-}"
  local work_dir="${dataset_name}_mock"

  # 构建 dataset-args：自动合并 local_path、subset_list、额外参数
  local parts=()
  [[ -n "$local_path" ]] && parts+=("\"local_path\":\"${local_path}\"")
  local subset="${SUBSET_LISTS[$dataset_name]:-}"
  [[ -n "$subset" ]] && parts+=("\"subset_list\":${subset}")
  local extra="${EXTRA_DATASET_ARGS[$dataset_name]:-}"
  [[ -n "$extra" ]] && parts+=("${extra:1:${#extra}-2}")
  local IFS=","; local inner="{${parts[*]:-}}"

  # generation-config（支持每数据集覆盖 max_tokens）
  local max_tokens="${MAX_TOKENS_OVERRIDE[$dataset_name]:-$GEN_MAX_TOKENS}"
  local gen_json; gen_json=$(build_generation_config "$max_tokens")

  echo "=========================================="
  echo "Running eval: ${dataset_name}  (max_tokens=${max_tokens})"
  echo "  generation-config: ${gen_json}"
  echo "=========================================="

  # 判断是否需要 LLM Judge
  local judge_args=()
  for _jds in "${JUDGE_DATASETS[@]}"; do
    if [[ "$_jds" == "$dataset_name" ]]; then
      local j_url="${JUDGE_API_URL:-${BASE_URL}/v1}"
      local j_key="${JUDGE_API_KEY:-EMPTY}"
      local j_model="${JUDGE_MODEL_ID:-${MODEL_NAME}}"
      judge_args=(
        --judge-strategy llm
        --judge-model-args "{\"api_url\": \"${j_url}\", \"api_key\": \"${j_key}\", \"model_id\": \"${j_model}\"}"
      )
      break
    fi
  done

  # 如果有文心一言的key，可以设置 MODELSCOPE_USE_ERNIE_JUDGE=1 来使用文心一言做裁判，否则用本地的模型做裁判
  evalscope eval \
    --model "${MODEL_NAME}" \
    --api-url "${BASE_URL}/v1" \
    --api-key "EMPTY" \
    --eval-type openai_api \
    --datasets "${dataset_name}" \
    --generation-config "${gen_json}" \
    --timeout 10000 \
    --stream \
    --eval-batch-size "${EBS}" \
    --dataset-args "{\"${dataset_name}\":${inner}}" \
    --work-dir "./outputs/${work_dir}" \
    --ignore-errors \
    "${judge_args[@]}" \
    2>&1 | tee "logs/${dataset_name}_${timestamp}.log"
}

# ============================================================
# 主入口
# ============================================================
echo "============================================"
echo "EvalScope Run - $(date)"
echo "Datasets : ${DATASETS_TO_RUN[*]:-<none>}"
echo "Gen cfg  : max_tokens=${GEN_MAX_TOKENS}, temperature=${GEN_TEMPERATURE}, top_p=${GEN_TOP_P}, top_k=${GEN_TOP_K:-<not set>}, thinking=${THINKING_MODE:-<not set>}"
echo "============================================"

[[ ${#DATASETS_TO_RUN[@]} -eq 0 ]] && { echo "No datasets selected."; exit 0; }

for ds in "${DATASETS_TO_RUN[@]}"; do
  run_dataset "$ds" || echo "WARNING: $ds failed, continuing..."
  echo ""
done

echo "============================================"
echo "All done - $(date)"
echo "============================================"