# {{MODEL_NAME}} 推理服务测试报告

| 项目 | 信息 |
|------|------|
| 测试日期 | {{DATE}} |
| 模型名称 | {{MODEL_NAME}} |
| 硬件类型 | {{HW_TYPE}} |
| 设备数量 | {{DEVICE_COUNT}} |
| 驱动版本 | {{DRIVER_VERSION}} |
| 主机名 | {{HOSTNAME}} |
| 镜像 | {{IMAGE_ID}} |

---

## 1. 环境信息

| 项目 | 详情 |
|------|------|
| 硬件平台 | {{HW_TYPE}} × {{DEVICE_COUNT}} |
| 驱动版本 | {{DRIVER_VERSION}} |
| 容器镜像 | {{IMAGE_ID}} |
| 服务端口 | {{SERVICE_PORT}} |

---

## 2. 性能测试结果

### 2.1 测试配置

| 参数 | 值 |
|------|-----|
| 测试模式 | {{PERF_MODE}} |
| 输入长度 | {{INPUT_LEN}} tokens |
| 输出长度 | {{OUTPUT_LEN}} tokens |
| 每组请求数 | {{PERF_NUMBER}} |

### 2.2 测试结果

{{PERF_RESULTS_TABLE}}

> 详细数据见 Excel: `{{EXCEL_FILE}}`

---

## 3. 精度测试结果

### 3.1 测试配置

| 参数 | 值 |
|------|-----|
| max_tokens | {{EVAL_MAX_TOKENS}} |
| temperature | {{EVAL_TEMPERATURE}} |
| thinking_mode | {{THINKING_MODE}} |
| 数据集 | {{EVAL_DATASETS}} |

### 3.2 测试结果

{{EVAL_RESULTS_TABLE}}

---

## 4. 结论与建议

{{CONCLUSION}}

---

*报告自动生成于 {{DATE}}*
