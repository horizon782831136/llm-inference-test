#!/bin/bash
# ============================================================
# Phase 7: 结果导出与报告生成
# 将性能测试日志导出为Excel，生成测试报告
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

log_step "Phase 7: 结果导出与报告生成"

# --- 参数 ---
SERVICE_SCRIPT="${CFG_SERVICE_SCRIPT:-}"
MODEL_NAME="${CFG_MODEL_NAME:-}"
PERF_ENABLED="${CFG_PERF_ENABLED:-true}"
EVAL_ENABLED="${CFG_EVAL_ENABLED:-true}"

# --- 测试输出目录：服务脚本同目录下的 test/ ---
if [[ -n "$SERVICE_SCRIPT" ]]; then
    SERVICE_SCRIPT_DIR=$(dirname "$SERVICE_SCRIPT")
    TEST_OUTPUT_DIR="${SERVICE_SCRIPT_DIR}/test"
else
    TEST_OUTPUT_DIR="./test"
fi

PERF_DIR="${TEST_OUTPUT_DIR}"
EVAL_DIR="${TEST_OUTPUT_DIR}/eval"
EVAL_LOG_DIR="${TEST_OUTPUT_DIR}/logs"
REPORT_DIR="${TEST_OUTPUT_DIR}/reports"
mkdir -p "$REPORT_DIR"

TIMESTAMP=$(timestamp)

log_info "测试输出目录: ${TEST_OUTPUT_DIR}"

# ===== 性能结果导出到 Excel =====
export_perf_to_excel() {
    log_info "导出性能测试结果到 Excel..."

    # 找到最新的性能日志
    local perf_log
    perf_log=$(ls -t "${PERF_DIR}"/perf_*.log 2>/dev/null | head -1)

    if [[ -z "$perf_log" || ! -f "$perf_log" ]]; then
        log_warn "未找到性能测试日志，跳过Excel导出"
        return 1
    fi

    local excel_path="${PERF_DIR}/perf_results_${TIMESTAMP}.xlsx"

    python3 - "$perf_log" "$excel_path" <<'PYTHON_SCRIPT'
import re, sys
from pathlib import Path

try:
    from openpyxl import Workbook
    from openpyxl.styles import Alignment, Font, PatternFill
except ImportError:
    print("openpyxl 未安装，尝试安装...")
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "openpyxl", "-q"])
    from openpyxl import Workbook
    from openpyxl.styles import Alignment, Font, PatternFill

LOG_PATH = Path(sys.argv[1])
OUT_PATH = Path(sys.argv[2])

ANSI_RE = re.compile(r"\x1b\[[0-9;]*m")

METRIC_COLUMNS = [
    ("Test Duration (s)", "Test Duration (s)"),
    ("Concurrency", "Concurrency"),
    ("Request Rate (req/s)", "Request Rate (req/s)"),
    ("Total / Success / Failed", "Total / Success / Failed"),
    ("Req Throughput (req/s)", "Req Throughput (req/s)"),
    ("Avg Latency (s)", "Avg Latency (s)"),
    ("TTFT (ms)", "TTFT (ms)"),
    ("TPOT (ms)", "TPOT (ms)"),
    ("ITL (ms)", "ITL (ms)"),
    ("Avg Input Tokens", "Avg Input Tokens"),
    ("Avg Output Tokens", "Avg Output Tokens"),
    ("Output Throughput (tok/s)", "Output Throughput (tok/s)"),
    ("Total Throughput (tok/s)", "Total Throughput (tok/s)"),
    ("Decoded Tok/Iter", "Decoded Tok/Iter"),
    ("Spec. Accept Rate", "Spec. Accept Rate"),
]

def parse_value(raw):
    raw = raw.strip()
    if not raw:
        return ""
    if "/" in raw:
        return raw
    try:
        return float(raw) if "." in raw else int(raw)
    except ValueError:
        return raw

def extract_rows(log_text):
    lines = log_text.splitlines()
    rows = []
    current_run = {"rate": None, "parallel": None}
    run_re = re.compile(r"Running with rate=([\d.]+),\s*parallel=(\d+)")
    header_marker = "│ Metric"
    end_marker_prefix = "└"
    i = 0
    while i < len(lines):
        line = ANSI_RE.sub("", lines[i])
        m = run_re.search(line)
        if m:
            current_run = {"rate": float(m.group(1)), "parallel": int(m.group(2))}
        if header_marker in line and "Value" in line:
            preceding = "\n".join(ANSI_RE.sub("", lines[j]) for j in range(max(0, i - 4), i))
            if "Benchmarking summary" not in preceding:
                i += 1
                continue
            row = {col: "" for _, col in METRIC_COLUMNS}
            row["Rate (req/s) [config]"] = current_run["rate"]
            row["Parallel [config]"] = current_run["parallel"]
            j = i + 1
            while j < len(lines):
                inner = ANSI_RE.sub("", lines[j])
                if inner.lstrip().startswith(end_marker_prefix):
                    break
                if "├" in inner or "──" in inner.replace("│", "").replace(" ", "")[:6]:
                    j += 1
                    continue
                cells = [c.strip() for c in inner.strip().strip("│").split("│")]
                if len(cells) == 2:
                    label, value = cells
                    if label.startswith("──"):
                        j += 1
                        continue
                    for metric_label, column in METRIC_COLUMNS:
                        if label == metric_label:
                            row[column] = parse_value(value)
                            break
                j += 1
            rows.append(row)
            i = j + 1
            continue
        i += 1
    return rows

def write_excel(rows):
    wb = Workbook()
    ws = wb.active
    ws.title = "Benchmark Summary"
    headers = ["#", "Rate (req/s) [config]", "Parallel [config]"] + [col for _, col in METRIC_COLUMNS]
    ws.append(headers)
    header_font = Font(bold=True, color="FFFFFF")
    header_fill = PatternFill("solid", fgColor="305496")
    center = Alignment(horizontal="center", vertical="center")
    for col_idx, _ in enumerate(headers, start=1):
        cell = ws.cell(row=1, column=col_idx)
        cell.font = header_font
        cell.fill = header_fill
        cell.alignment = center
    for idx, row in enumerate(rows, start=1):
        ws.append([idx] + [row.get(h, "") for h in headers[1:]])
    for col_idx, header in enumerate(headers, start=1):
        max_len = len(str(header))
        for r in range(2, ws.max_row + 1):
            v = ws.cell(row=r, column=col_idx).value
            if v is None:
                continue
            max_len = max(max_len, len(str(v)))
        ws.column_dimensions[ws.cell(row=1, column=col_idx).column_letter].width = max_len + 2
    ws.freeze_panes = "B2"
    wb.save(OUT_PATH)

text = LOG_PATH.read_text(encoding="utf-8", errors="replace")
rows = extract_rows(text)
print(f"Extracted {len(rows)} benchmark summary rows")
write_excel(rows)
print(f"Saved -> {OUT_PATH}")
PYTHON_SCRIPT

    if [[ $? -eq 0 ]]; then
        log_info "Excel 导出成功: ${excel_path}"
    else
        log_error "Excel 导出失败!"
        return 1
    fi
}

# ===== 精度测试结果汇总 =====
collect_eval_results() {
    log_info "汇总精度测试结果..."

    local eval_summary="${EVAL_DIR}/eval_summary_${TIMESTAMP}.txt"
    echo "# 精度测试结果汇总 - $(date_str)" > "$eval_summary"
    echo "# 模型: ${MODEL_NAME}" >> "$eval_summary"
    echo "========================================" >> "$eval_summary"

    # 收集所有评测输出目录中的结果
    for dir in "${EVAL_DIR}"/*/; do
        [[ -d "$dir" ]] || continue
        local ds_name
        ds_name=$(basename "$dir" | sed 's/_[0-9]\{8\}_[0-9]\{6\}$//')
        echo "" >> "$eval_summary"
        echo "--- ${ds_name} ---" >> "$eval_summary"

        # 查找结果文件
        local result_file
        result_file=$(find "$dir" -name "*.json" -o -name "*result*" 2>/dev/null | head -1)
        if [[ -n "$result_file" ]]; then
            python3 -c "
import json, sys
try:
    with open('$result_file') as f:
        data = json.load(f)
    if isinstance(data, dict):
        for k, v in data.items():
            if 'score' in k.lower() or 'accuracy' in k.lower() or 'pass' in k.lower():
                print(f'  {k}: {v}')
except Exception as e:
    print(f'  (解析失败: {e})')
" >> "$eval_summary" 2>/dev/null
        fi

        # 也从日志中提取最终得分
        local log_file
        log_file=$(ls -t "${EVAL_LOG_DIR}/${ds_name}_"*.log 2>/dev/null | head -1)
        if [[ -n "$log_file" ]]; then
            grep -i "score\|accuracy\|pass_rate\|final" "$log_file" | tail -5 >> "$eval_summary" 2>/dev/null
        fi
    done

    log_info "精度汇总: ${eval_summary}"
}

# ===== 生成测试报告 =====
generate_report() {
    log_info "生成测试报告..."

    local report_file="${REPORT_DIR}/test_report_${TIMESTAMP}.md"
    local env_report="${TEST_OUTPUT_DIR}/env_report.json"

    # 读取环境信息
    local hw_type="未知"
    local driver_ver="未知"
    local device_count="未知"
    local hostname_str="未知"
    if [[ -f "$env_report" ]]; then
        hw_type=$(python3 -c "import json; d=json.load(open('$env_report')); print(d.get('hardware_type','未知'))" 2>/dev/null)
        driver_ver=$(python3 -c "import json; d=json.load(open('$env_report')); print(d.get('driver_version','未知'))" 2>/dev/null)
        device_count=$(python3 -c "import json; d=json.load(open('$env_report')); print(d.get('device_count','未知'))" 2>/dev/null)
        hostname_str=$(python3 -c "import json; d=json.load(open('$env_report')); print(d.get('hostname','未知'))" 2>/dev/null)
    fi

    cat > "$report_file" <<EOF
# 模型推理服务测试报告

| 项目 | 信息 |
|------|------|
| 测试日期 | $(date_str) |
| 模型名称 | ${MODEL_NAME} |
| 硬件类型 | ${hw_type} |
| 设备数量 | ${device_count} |
| 驱动版本 | ${driver_ver} |
| 主机名 | ${hostname_str} |

---

## 1. 环境信息

硬件平台: **${hw_type}** (${device_count} 卡)
驱动版本: ${driver_ver}

---

## 2. 性能测试结果

EOF

    # 添加性能测试数据
    local perf_log
    perf_log=$(ls -t "${PERF_DIR}"/perf_*.log 2>/dev/null | head -1)
    if [[ -n "$perf_log" ]]; then
        echo "日志文件: \`$(basename "$perf_log")\`" >> "$report_file"
        echo "" >> "$report_file"
        # 提取关键指标
        echo "| Rate | Parallel | Throughput (tok/s) | TTFT (ms) | TPOT (ms) | Success |" >> "$report_file"
        echo "|------|----------|-------------------|-----------|-----------|---------|" >> "$report_file"
        grep -A 20 "Benchmarking summary" "$perf_log" 2>/dev/null | head -30 >> "$report_file" || echo "详见 Excel 文件" >> "$report_file"
        local excel_file
        excel_file=$(ls -t "${PERF_DIR}"/perf_results_*.xlsx 2>/dev/null | head -1)
        if [[ -n "$excel_file" ]]; then
            echo "" >> "$report_file"
            echo "Excel详细结果: \`$(basename "$excel_file")\`" >> "$report_file"
        fi
    else
        echo "性能测试未执行或日志未找到。" >> "$report_file"
    fi

    cat >> "$report_file" <<EOF

---

## 3. 精度测试结果

EOF

    local eval_summary
    eval_summary=$(ls -t "${EVAL_DIR}"/eval_summary_*.txt 2>/dev/null | head -1)
    if [[ -n "$eval_summary" ]]; then
        cat "$eval_summary" >> "$report_file"
    else
        echo "精度测试未执行或结果未找到。" >> "$report_file"
    fi

    cat >> "$report_file" <<EOF

---

## 4. 结论

- 性能测试: $(if [[ -n "$perf_log" ]]; then echo "✅ 已完成"; else echo "⏭ 未执行"; fi)
- 精度测试: $(if [[ -n "$eval_summary" ]]; then echo "✅ 已完成"; else echo "⏭ 未执行"; fi)

---

*报告自动生成于 $(date_str)*
EOF

    log_info "测试报告已生成: ${report_file}"
}

# --- 主逻辑 ---
if [[ "$PERF_ENABLED" == "true" ]]; then
    export_perf_to_excel
fi

if [[ "$EVAL_ENABLED" == "true" ]]; then
    collect_eval_results
fi

generate_report

log_info "Phase 7 完成 ✓"
log_info "所有测试输出保存在: ${TEST_OUTPUT_DIR}/"
