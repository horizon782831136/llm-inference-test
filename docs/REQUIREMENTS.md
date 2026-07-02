# 模型推理服务测试 - 需求文档

> 版本: v1.0  
> 日期: 2026-07-02  
> 适用场景: 百度昆仑P800 / NVIDIA H20 机器上的 LLM 推理服务部署与性能/精度测试

---

## 1. 概述

本项目为 LLM 推理服务的标准化测试流程，覆盖从环境检测、容器创建、服务启动、模型验证、性能测试、精度测试到结果导出的全生命周期。支持 P800（昆仑XPU）和 H20（NVIDIA GPU）两种硬件平台。

---

## 2. 流程总览

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  1.环境检测  │───▶│ 2.容器创建   │───▶│ 3.服务启动   │───▶│  4.测试执行  │───▶│ 5.结果导出   │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
       │                  │                  │                  │                  │
       ▼                  ▼                  ▼                  ▼                  ▼
  识别硬件平台       拉取/导入镜像       启动推理引擎       性能+精度测试      Excel+报告
  检测驱动版本       创建容器实例       curl验证回答        异常自动重试       自动归档
```

---

## 3. 详细需求

### 3.1 环境检测（Phase 1）

| 需求项 | 说明 |
|--------|------|
| 硬件识别 | 通过 `xpu-smi` / `nvidia-smi` 自动识别机器类型（P800 或 H20） |
| 驱动版本 | 记录驱动版本号，写入最终测试报告 |
| GPU/XPU数量 | 自动检测可用设备数量 |
| 磁盘空间 | 检查 /ssd1-4 挂载点可用空间 |
| 网络连通性 | 检测是否可访问 docker registry / modelscope，不通则提示设置代理 |

**输出**: `env_report.json`，包含硬件类型、设备数、驱动版本、磁盘空间等信息。

### 3.2 模型与镜像准备（Phase 2）

#### 3.2.1 模型下载
| 需求项 | 说明 |
|--------|------|
| 已有模型 | 用户指定路径，验证路径存在即可 |
| ModelScope下载 | 通过 `modelscope download` 下载到指定目录 |
| 手动下载 | 用户自行准备，脚本验证路径 |

#### 3.2.2 镜像准备
| 输入方式 | 处理逻辑 |
|-----------|----------|
| 镜像ID（registry地址） | `docker pull <image_id>` |
| tar包路径 | `docker load -i <path>` |
| tar.gz压缩包路径 | `tar -xzvf <path>` → `docker load -i <解压结果>` |
| 下载链接 | 先检测网络，不通提示代理；通则 `wget` 下载后 `docker load` |

#### 3.2.3 evalscope安装
| 需求项 | 说明 |
|--------|------|
| 检测evalscope | `which evalscope` 或 `pip show evalscope` |
| 自动安装 | 若不存在则 `pip install evalscope` |

### 3.3 容器创建（Phase 3）

根据硬件类型选择不同的容器创建策略：

#### P800 容器
- 设备映射: `/dev/xpu0` ~ `/dev/xpu7` + `/dev/xpuctrl`
- 特权模式: `--privileged`
- 共享内存: `--tmpfs /dev/shm:rw,nosuid,nodev,exec,size=32g`
- 磁盘挂载: `/ssd1` ~ `/ssd4`
- 网络模式: `--net=host`

#### H20 容器
- GPU支持: `--gpus all`
- 共享内存: `--shm-size=256g`
- 网络模式: `--net=host`
- 磁盘挂载: `/ssd1` ~ `/ssd4`

**通用参数**:
- `--restart=always`
- `-w /dir`（工作目录）
- 安全选项: `--security-opt seccomp=unconfined`

### 3.4 服务启动与验证（Phase 4）

| 需求项 | 说明 |
|--------|------|
| 启动脚本 | 用户提供的服务启动脚本，在容器内执行 |
| 健康检查 | 循环 curl 检测服务端口，直到返回正常响应 |
| 验证请求 | 发送标准 chat completion 请求，验证模型回答正常 |
| 超时机制 | 服务启动超时（默认600s），超时则报错退出 |

**验证请求格式**:
```json
{
  "model": "<model_name>",
  "messages": [{"role": "user", "content": "介绍一下你自己"}],
  "temperature": 0.7,
  "max_tokens": 1024,
  "stream": false
}
```

### 3.5 测试执行（Phase 5）

#### 3.5.1 性能测试

**测试工具**: evalscope perf

**参数配置**:
| 参数 | 说明 |
|------|------|
| url | 服务端点（如 `http://127.0.0.1:30000/v1/completions`） |
| model | 模型名称 |
| dataset | `random`（随机生成输入） |
| parallel | 并发数（与rate配对） |
| rate | 请求速率（req/s） |
| number | 总请求数 |
| input_len | 输入token长度 |
| output_len | 输出token长度 |
| tokenizer-path | tokenizer路径 |

**默认Rate-Parallel配对**:
```
rate=0.3  parallel=3
rate=0.5  parallel=5
rate=0.6  parallel=6
rate=0.7  parallel=7
rate=0.8  parallel=8
rate=1.0  parallel=10
rate=1.5  parallel=15
rate=2.0  parallel=20
rate=3.0  parallel=30
rate=4.0  parallel=40
rate=5.0  parallel=50
rate=10.0 parallel=100
rate=20.0 parallel=200
```

**两种模式**:
1. **benchmark模式**（benchmark.sh）: 多rate梯度压测，用于找到服务吞吐上限
2. **perf模式**（perf.sh）: 单配置定量测试，用于固定场景性能数据

#### 3.5.2 精度测试

**测试工具**: evalscope eval

**支持数据集**:
- 数学推理: aime24, aime25, aime26, gsm8k, math_500, hmmt25
- 通用知识: mmlu, mmlu_pro, mmlu_redux, mmmlu, ceval, cmmlu, gpqa_diamond, super_gpqa
- 编程: humaneval, humaneval_plus, live_code_bench
- 指令跟随: ifeval, ifbench
- 长文本: longbench_v2
- 多模态: gsm8k_v, ocr_bench, hallusion_bench, ai2d, mm_star, mmmu_pro, mmmu, chartqa, zerobench
- Agent: bfcl_v3, bfcl_v4, tool_bench, general_fc
- LLM Judge: simple_qa, hle, aa_lcr, chinese_simpleqa
- 综合: bbh, tau2_bench

**Generation配置**:
| 参数 | 默认值 |
|------|--------|
| max_tokens | 131072 |
| temperature | 1.0 |
| top_p | 1.0 |
| thinking_mode | 可选 true/false |

### 3.6 异常处理与重试（Phase 6）

| 场景 | 处理 |
|------|------|
| 测试结果异常 | 自动重试2次 |
| 服务崩溃 | 自动重启服务，等待就绪后继续 |
| 网络超时 | 重试当前请求 |
| 容器异常退出 | 尝试重启容器 |

### 3.7 结果导出与报告（Phase 7）

| 输出项 | 格式 | 说明 |
|--------|------|------|
| 性能测试结果 | Excel (.xlsx) | 通过 extract_to_excel.py 从日志提取 |
| 精度测试结果 | 文本/截图 | 从 evalscope 输出截取 |
| 测试报告 | Markdown | 汇总所有结果 |

**Excel列**:
- 配置列: Rate, Parallel
- 通用指标: Test Duration, Concurrency, Total/Success/Failed, Req Throughput
- 延迟指标: Avg Latency, TTFT, TPOT, ITL
- Token指标: Avg Input/Output Tokens, Output/Total Throughput
- 投机解码: Decoded Tok/Iter, Spec. Accept Rate

---

## 4. 配置文件格式

工作流通过 `config.yaml` 驱动，所有可变参数集中管理：

```yaml
# 硬件与环境
hardware_type: auto          # auto / p800 / h20
workspace: /ssd3/liuwei

# 模型
model_name: "Qwen3.5-27B"
model_path: "/ssd3/models/Qwen3.5-27B"
tokenizer_path: "/ssd3/models/Qwen3.5-27B"
model_download_source: ""    # 留空=已有, modelscope=从modelscope下载

# 镜像
image_source: "registry"     # registry / tar / tar.gz / url
image_id: "vllm/vllm-openai:v0.17.0"
image_url: ""
image_tar_path: ""

# 容器
container_name: "lw_test"
extra_volumes: []

# 服务
service_script: "./start_server.sh"
service_port: 30000
service_timeout: 600

# 性能测试
perf_enabled: true
perf_mode: "benchmark"       # benchmark / single
perf_input_len: 9000
perf_output_len: 100
perf_number: 200
perf_rate_parallel_map:
  0.3: 3
  0.5: 5
  1.0: 10
  2.0: 20
  5.0: 50

# 精度测试
eval_enabled: true
eval_datasets:
  - aime25
  - gpqa_diamond
  - gsm8k
  - humaneval
eval_max_tokens: 131072
eval_temperature: 1.0
eval_thinking_mode: "true"
eval_batch_size: 128

# 重试
retry_on_anomaly: true
max_retries: 2

# 输出
output_dir: "./results"
```

---

## 5. 可复用性设计

1. **配置驱动**: 所有可变参数通过 config.yaml 注入，无需修改脚本
2. **模块化**: 每个阶段独立脚本，可单独运行或组合执行
3. **平台自适应**: 自动检测硬件，选择对应的容器创建策略
4. **幂等性**: 重复运行不会创建重复资源（检测已有容器/镜像）
5. **可扩展**: 新增测试数据集只需在配置中添加
6. **日志完整**: 每步骤记录时间戳日志，便于问题排查

---

## 6. 目录结构

```
project/
├── config.yaml              # 全局配置文件
├── workflow.sh              # 主入口（全流程编排）
├── scripts/
│   ├── 01_check_env.sh      # 环境检测
│   ├── 02_prepare.sh        # 模型&镜像准备
│   ├── 03_create_container.sh  # 容器创建
│   ├── 04_start_service.sh  # 服务启动&验证
│   ├── 05_run_perf.sh       # 性能测试
│   ├── 06_run_eval.sh       # 精度测试
│   ├── 07_export_results.sh # 结果导出
│   └── utils.sh             # 公共工具函数
├── templates/
│   └── report_template.md   # 报告模板
├── results/                 # 测试结果输出目录
│   ├── perf/
│   ├── eval/
│   └── reports/
└── docs/
    └── REQUIREMENTS.md      # 本文档
```
