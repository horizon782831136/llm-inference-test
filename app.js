/* ================================================================
   QATools 配置管理平台 - 前端逻辑
   ================================================================ */

// ==================== 全局数据 ====================

var EVAL_DATASETS = [
    {name: 'aime24', group: 'llm'}, {name: 'aime25', group: 'llm'},
    {name: 'aime26', group: 'llm'}, {name: 'gpqa_diamond', group: 'llm'},
    {name: 'mmlu', group: 'llm'}, {name: 'mmlu_pro', group: 'llm'},
    {name: 'mmlu_redux', group: 'llm'}, {name: 'mmmlu', group: 'llm'},
    {name: 'bbh', group: 'llm'}, {name: 'ceval', group: 'llm'},
    {name: 'cmmlu', group: 'llm'}, {name: 'gsm8k', group: 'llm'},
    {name: 'math_500', group: 'llm'}, {name: 'humaneval', group: 'llm'},
    {name: 'humaneval_plus', group: 'llm'}, {name: 'live_code_bench', group: 'llm'},
    {name: 'ifeval', group: 'llm'}, {name: 'ifbench', group: 'llm'},
    {name: 'hmmt25', group: 'llm'}, {name: 'super_gpqa', group: 'llm'},
    {name: 'longbench_v2', group: 'llm'}, {name: 'tau2_bench', group: 'llm'},
    {name: 'bfcl_v3', group: 'agent'}, {name: 'bfcl_v4', group: 'agent'},
    {name: 'tool_bench', group: 'agent'}, {name: 'general_fc', group: 'agent'},
    {name: 'gsm8k_v', group: 'vlm'}, {name: 'ocr_bench', group: 'vlm'},
    {name: 'hallusion_bench', group: 'vlm'}, {name: 'ai2d', group: 'vlm'},
    {name: 'mm_star', group: 'vlm'}, {name: 'mmmu_pro', group: 'vlm'},
    {name: 'mmmu', group: 'vlm'}, {name: 'chartqa', group: 'vlm'},
    {name: 'zerobench', group: 'judge'}, {name: 'simple_qa', group: 'judge'},
    {name: 'hle', group: 'judge'}, {name: 'aa_lcr', group: 'judge'},
    {name: 'chinese_simpleqa', group: 'judge'},
];

var EVAL_SUBSET_LISTS = {
    live_code_bench: '["test6"]',
    tau2_bench: '["retail", "airline", "telecom"]',
    tool_bench: '["in_domain", "out_of_domain"]',
    bfcl_v4: '["irrelevance", "live_irrelevance", "live_multiple"]',
    longbench_v2: '["short"]',
};

var EVAL_JUDGE_DATASETS = ['zerobench', 'hle', 'aa_lcr', 'chinese_simpleqa', 'simple_qa'];

var EVAL_LOCAL_PATHS = {
    aime24: '/data/evalscope/data/aime24/', aime25: '/data/evalscope/data/aime25/',
    aime26: '/data/evalscope/data/aime26/', gpqa_diamond: '/data/evalscope/data/gpqa/',
    mmlu: '/data/evalscope/data/mmlu/', mmlu_pro: '/data/evalscope/data/MMLU-Pro',
    mmlu_redux: '/data/evalscope/data/mmlu-redux-2.0/', mmmlu: '/data/evalscope/data/MMMLU/',
    bbh: '/data/evalscope/data/bbh', ceval: '/data/evalscope/data/ceval',
    cmmlu: '/data/evalscope/data/cmmlu/', gsm8k: '/data/evalscope/data/gsm8k/',
    math_500: '/data/evalscope/data/math500/', humaneval: '/data/evalscope/data/humaneval/',
    humaneval_plus: '/data/evalscope/data/humanevalplus/',
    live_code_bench: '/data/evalscope/data/code_generation_lite',
    ifeval: '/data/evalscope/data/ifeval/', ifbench: '/data/evalscope/data/IFBench_test/',
    hmmt25: '/data/evalscope/data/hmmt_feb_2025/', super_gpqa: '/data/evalscope/data/SuperGPQA/',
    longbench_v2: '/data/evalscope/data/LongBench-v2/',
    tau2_bench: '/data/evalscope/data/tau2-bench-data/',
    bfcl_v3: '/data/evalscope/data/bfcl_v3/', tool_bench: '/data/evalscope/data/ToolBench-Static/',
    general_fc: '/data/evalscope/data/GeneralFunctionCall-Test/',
    gsm8k_v: '/data/evalscope/data/GSM8K-V/', ocr_bench: '/data/evalscope/data/OCRBench/',
    hallusion_bench: '/data/evalscope/data/HallusionBench/', ai2d: '/data/evalscope/data/ai2d/',
    mm_star: '/data/evalscope/data/MMStar/', mmmu_pro: '/data/evalscope/data/MMMU_Pro/',
    mmmu: '/data/evalscope/data/MMMU/', chartqa: '/data/evalscope/data/chartqa/',
    zerobench: '/data/evalscope/data/zerobench/', simple_qa: '/data/evalscope/data/simpleqa',
    hle: '/data/evalscope/data/hle/', aa_lcr: '/data/evalscope/data/AA-LCR',
    chinese_simpleqa: '/data/evalscope/data/Chinese-SimpleQA/',
};

// 默认 rate/parallel 配对
var DEFAULT_RATE_PARALLELS = [
    {rate: 0.3, parallel: 3}, {rate: 0.5, parallel: 5},
    {rate: 0.6, parallel: 6}, {rate: 0.7, parallel: 7},
    {rate: 0.8, parallel: 8}, {rate: 1.0, parallel: 10},
    {rate: 1.5, parallel: 15}, {rate: 2.0, parallel: 20},
    {rate: 3.0, parallel: 30}, {rate: 4.0, parallel: 40},
    {rate: 5.0, parallel: 50}, {rate: 10.0, parallel: 100},
    {rate: 20.0, parallel: 200},
];

// 预设模板
var PRESETS = {
    p800_sglang: {
        hardware_type: 'p800', workspace: '/ssd3/liuwei', xpu_num: 8,
        model_name: 'DeepSeek-V4-Flash-INT8', model_path: '/ssd4/models/DeepSeek-V4-Flash-INT8',
        tokenizer_path: '/ssd4/models/DeepSeek-V4-Flash-INT8',
        service_image_source: 'registry', service_image_id: 'iregistry.baidu-int.com/xpu/sglang-p800-pd-disagg-056:20260512_386',
        service_container_name: 'lw_xsgl_056', service_tmpfs_size: '32g',
        test_image_source: 'registry', test_image_id: 'iregistry.baidu-int.com/xpu/infer_qa:v4.0',
        test_container_name: 'lw_qa_infer', test_tmpfs_size: '32g',
        service_port: 30000, perf_input_len: 9000, perf_output_len: 100,
    },
    p800_vllm: {
        hardware_type: 'p800', workspace: '/ssd3/liuwei', xpu_num: 8,
        model_name: 'Qwen3.5-27B', model_path: '/ssd3/models/Qwen3.5-27B',
        tokenizer_path: '/ssd3/models/Qwen3.5-27B',
        service_image_source: 'registry', service_image_id: 'iregistry.baidu-int.com/xpu/infer_qa:v4.0',
        service_container_name: 'lw_qa_infer', service_tmpfs_size: '32g',
        test_image_source: 'registry', test_image_id: 'iregistry.baidu-int.com/xpu/infer_qa:v4.0',
        test_container_name: 'lw_qa_test', test_tmpfs_size: '32g',
        service_port: 30000, perf_input_len: 2600, perf_output_len: 30,
    },
    h20_vllm: {
        hardware_type: 'h20', workspace: '/ssd3/liuwei', xpu_num: 8,
        model_name: 'Qwen3.5-27B', model_path: '/ssd3/models/Qwen3.5-27B',
        tokenizer_path: '/ssd3/models/Qwen3.5-27B',
        service_image_source: 'registry', service_image_id: 'vllm/vllm-openai:v0.17.0',
        service_container_name: 'lw_qwen', service_tmpfs_size: '256g',
        test_image_source: 'registry', test_image_id: 'iregistry.baidu-int.com/xpu/infer_qa:v4.0',
        test_container_name: 'lw_qa_test', test_tmpfs_size: '32g',
        service_port: 30000, perf_input_len: 9000, perf_output_len: 100,
    },
    h20_sglang: {
        hardware_type: 'h20', workspace: '/ssd3/liuwei', xpu_num: 8,
        model_name: 'DeepSeek-V4-Flash-INT8', model_path: '/ssd4/models/DeepSeek-V4-Flash-INT8',
        tokenizer_path: '/ssd4/models/DeepSeek-V4-Flash-INT8',
        service_image_source: 'registry', service_image_id: 'lmsysorg/sglang:latest',
        service_container_name: 'lw_sglang', service_tmpfs_size: '256g',
        test_image_source: 'registry', test_image_id: 'iregistry.baidu-int.com/xpu/infer_qa:v4.0',
        test_container_name: 'lw_qa_test', test_tmpfs_size: '32g',
        service_port: 30000, perf_input_len: 9000, perf_output_len: 100,
    },
};

// 状态
var rateParallels = JSON.parse(JSON.stringify(DEFAULT_RATE_PARALLELS));
var cfgEvalSelected = new Set(['aime25', 'gpqa_diamond', 'gsm8k', 'humaneval']);
var evalSelected = new Set(['aime25', 'gpqa_diamond', 'humaneval']);

// ==================== 初始化 ====================
document.addEventListener('DOMContentLoaded', function() {
    renderRateParallel();
    cfgEvalRenderDatasets();
    configGenerate();
    if (document.getElementById('bench-cmdText')) {
        benchGenerate();
    }
});

// ==================== Tab 切换 ====================
function showTab(name) {
    document.querySelectorAll('.tab-content').forEach(function(el) {
        el.classList.remove('active');
    });
    document.getElementById('tab-' + name).classList.add('active');
    document.querySelectorAll('.nav-actions .btn-ghost').forEach(function(btn) {
        var target = btn.getAttribute('data-tab');
        btn.classList.toggle('active', target === name);
    });
    if (name === 'cmdgen' && !window._evalDatasetsRendered) {
        evalRenderDatasets();
        evalGenerate();
        window._evalDatasetsRendered = true;
    }
    if (name === 'scripts') {
        scriptsGenerate();
    }
}

// ==================== 配置管理 Tab ====================

function configApplyPreset(name) {
    var preset = PRESETS[name];
    if (!preset) return;
    // 高亮按钮
    document.querySelectorAll('#tab-config .preset-btn').forEach(function(b) { b.classList.remove('active'); });
    event.target.classList.add('active');
    // 填充字段
    Object.keys(preset).forEach(function(key) {
        var el = document.getElementById('cfg-' + key);
        if (el) {
            el.value = preset[key];
            // 触发 change 事件以更新联动显示
            if (el.tagName === 'SELECT') {
                el.dispatchEvent(new Event('change'));
            }
        }
    });
    onImageSourceChange();
    configGenerate();
}

function onImageSourceChange(prefix) {
    prefix = prefix || 'service';
    var src = document.getElementById('cfg-' + prefix + '_image_source').value;
    document.getElementById('cfg-' + prefix + '_image_id-group').style.display = src === 'registry' ? '' : 'none';
    document.getElementById('cfg-' + prefix + '_image_url-group').style.display = src === 'url' ? '' : 'none';
    document.getElementById('cfg-' + prefix + '_image_tar-group').style.display = (src === 'tar' || src === 'tar_gz') ? '' : 'none';
}

// --- Rate/Parallel 编辑器 ---
function renderRateParallel() {
    var container = document.getElementById('rate-parallel-editor');
    if (!container) return;
    container.innerHTML = rateParallels.map(function(rp, idx) {
        return '<div class="rp-item">' +
            '<input type="number" value="' + rp.rate + '" step="0.1" min="0" onchange="updateRP(' + idx + ', this, \'rate\')">' +
            '<span class="rp-sep">:</span>' +
            '<input type="number" value="' + rp.parallel + '" min="1" onchange="updateRP(' + idx + ', this, \'parallel\')">' +
            '<button class="rp-del" onclick="deleteRP(' + idx + ')">&times;</button>' +
            '</div>';
    }).join('');
}

function updateRP(idx, el, field) {
    rateParallels[idx][field] = parseFloat(el.value);
    configGenerate();
}

function deleteRP(idx) {
    rateParallels.splice(idx, 1);
    renderRateParallel();
    configGenerate();
}

function addRateParallel() {
    var last = rateParallels[rateParallels.length - 1] || {rate: 1, parallel: 10};
    rateParallels.push({rate: last.rate + 1, parallel: last.parallel + 10});
    renderRateParallel();
    configGenerate();
}

function resetRateParallel() {
    rateParallels = JSON.parse(JSON.stringify(DEFAULT_RATE_PARALLELS));
    renderRateParallel();
    configGenerate();
}

// --- Dataset chip 选择器 (配置Tab用) ---
function cfgEvalRenderDatasets() {
    var grid = document.getElementById('cfg-eval-datasetGrid');
    if (!grid) return;
    grid.innerHTML = EVAL_DATASETS.map(function(d) {
        var cls = 'cmdgen-dataset-chip' + (cfgEvalSelected.has(d.name) ? ' selected' : '');
        return '<div class="' + cls + '" onclick="cfgEvalToggleDs(\'' + d.name + '\')">' +
            d.name + '<span class="tag">' + d.group + '</span></div>';
    }).join('');
}

function cfgEvalToggleDs(name) {
    if (cfgEvalSelected.has(name)) cfgEvalSelected.delete(name);
    else cfgEvalSelected.add(name);
    cfgEvalRenderDatasets();
    configGenerate();
}

function cfgEvalSelectAll() {
    EVAL_DATASETS.forEach(function(d) { cfgEvalSelected.add(d.name); });
    cfgEvalRenderDatasets(); configGenerate();
}

function cfgEvalSelectNone() {
    cfgEvalSelected.clear();
    cfgEvalRenderDatasets(); configGenerate();
}

function cfgEvalSelectGroup(g) {
    cfgEvalSelected.clear();
    EVAL_DATASETS.filter(function(d) { return d.group === g; })
        .forEach(function(d) { cfgEvalSelected.add(d.name); });
    cfgEvalRenderDatasets(); configGenerate();
}

// --- 生成 config.yaml ---
function configGenerate() {
    var lines = [];
    lines.push('# ============================================================');
    lines.push('# 全局配置文件 - 模型推理服务测试工作流');
    lines.push('# 生成时间: ' + new Date().toLocaleString('zh-CN'));
    lines.push('# ============================================================');
    lines.push('');

    lines.push('# --- 硬件与环境 ---');
    lines.push('hardware_type: ' + gv('cfg-hardware_type'));
    lines.push('workspace: ' + gv('cfg-workspace'));
    lines.push('xpu_num: ' + gv('cfg-xpu_num'));
    lines.push('');

    lines.push('# --- 模型 ---');
    lines.push('model_name: "' + gv('cfg-model_name') + '"');
    lines.push('model_path: "' + gv('cfg-model_path') + '"');
    lines.push('tokenizer_path: "' + (gv('cfg-tokenizer_path') || gv('cfg-model_path')) + '"');
    lines.push('model_download_source: "' + gv('cfg-model_download_source') + '"');
    lines.push('model_download_id: "' + gv('cfg-model_download_id') + '"');
    lines.push('');

    lines.push('# --- 服务镜像 ---');
    lines.push('service_image_source: "' + gv('cfg-service_image_source') + '"');
    lines.push('service_image_id: "' + gv('cfg-service_image_id') + '"');
    lines.push('service_image_url: "' + gv('cfg-service_image_url') + '"');
    lines.push('service_image_tar_path: "' + gv('cfg-service_image_tar_path') + '"');
    lines.push('');

    lines.push('# --- 服务容器 ---');
    lines.push('service_container_name: "' + gv('cfg-service_container_name') + '"');
    lines.push('service_shared_memory_size: "256g"');
    lines.push('service_tmpfs_size: "' + gv('cfg-service_tmpfs_size') + '"');
    lines.push('service_extra_volumes: "' + gv('cfg-service_extra_volumes') + '"');
    lines.push('');

    lines.push('# --- 测试镜像 ---');
    lines.push('test_image_source: "' + gv('cfg-test_image_source') + '"');
    lines.push('test_image_id: "' + gv('cfg-test_image_id') + '"');
    lines.push('test_image_url: "' + gv('cfg-test_image_url') + '"');
    lines.push('test_image_tar_path: "' + gv('cfg-test_image_tar_path') + '"');
    lines.push('');

    lines.push('# --- 测试容器 ---');
    lines.push('test_container_name: "' + gv('cfg-test_container_name') + '"');
    lines.push('test_shared_memory_size: "256g"');
    lines.push('test_tmpfs_size: "' + gv('cfg-test_tmpfs_size') + '"');
    lines.push('test_extra_volumes: "' + gv('cfg-test_extra_volumes') + '"');
    lines.push('');

    lines.push('# --- 服务 ---');
    lines.push('service_script: "' + gv('cfg-service_script') + '"');
    lines.push('service_port: ' + gv('cfg-service_port'));
    lines.push('service_timeout: ' + gv('cfg-service_timeout'));
    lines.push('service_api_type: "' + gv('cfg-service_api_type') + '"');
    lines.push('');

    lines.push('# --- 性能测试 ---');
    var perfEnabled = document.getElementById('cfg-perf_enabled').checked;
    lines.push('perf_enabled: ' + perfEnabled);
    lines.push('perf_mode: "' + gv('cfg-perf_mode') + '"');
    lines.push('perf_url: "' + gv('cfg-perf_url') + '"');
    lines.push('perf_input_len: ' + gv('cfg-perf_input_len'));
    lines.push('perf_output_len: ' + gv('cfg-perf_output_len'));
    lines.push('perf_number: ' + gv('cfg-perf_number'));
    lines.push('perf_temperature: ' + gv('cfg-perf_temperature'));
    lines.push('perf_rates: "' + rateParallels.map(function(r) { return r.rate; }).join(',') + '"');
    lines.push('perf_parallels: "' + rateParallels.map(function(r) { return r.parallel; }).join(',') + '"');
    lines.push('perf_single_parallel: ' + gv('cfg-perf_single_parallel'));
    lines.push('perf_single_number: ' + gv('cfg-perf_single_number'));
    lines.push('');

    lines.push('# --- 精度测试 ---');
    var evalEnabled = document.getElementById('cfg-eval_enabled').checked;
    lines.push('eval_enabled: ' + evalEnabled);
    lines.push('eval_url: "' + gv('cfg-eval_url') + '"');
    lines.push('eval_datasets: "' + Array.from(cfgEvalSelected).join(',') + '"');
    lines.push('eval_max_tokens: ' + gv('cfg-eval_max_tokens'));
    lines.push('eval_temperature: ' + gv('cfg-eval_temperature'));
    lines.push('eval_top_p: ' + gv('cfg-eval_top_p'));
    lines.push('eval_thinking_mode: "' + gv('cfg-eval_thinking_mode') + '"');
    lines.push('eval_batch_size: ' + gv('cfg-eval_batch_size'));
    lines.push('judge_api_url: "' + gv('cfg-judge_api_url') + '"');
    lines.push('judge_api_key: "' + gv('cfg-judge_api_key') + '"');
    lines.push('judge_model_id: "' + gv('cfg-judge_model_id') + '"');
    lines.push('');

    lines.push('# --- 重试 ---');
    lines.push('retry_on_anomaly: ' + gv('cfg-retry_on_anomaly'));
    lines.push('max_retries: ' + gv('cfg-max_retries'));
    lines.push('');

    lines.push('# --- 输出 ---');
    lines.push('output_dir: "' + gv('cfg-output_dir') + '"');

    var yaml = lines.join('\n');
    var el = document.getElementById('config-yaml-preview');
    if (el) el.textContent = yaml;
    return yaml;
}

function gv(id) {
    var el = document.getElementById(id);
    return el ? el.value : '';
}

function configCopy() {
    var yaml = configGenerate();
    copyToClipboard(yaml);
    showToast('config.yaml 已复制到剪贴板');
}

function configDownload() {
    var yaml = configGenerate();
    downloadFile('config.yaml', yaml, 'text/yaml');
}

// ==================== 脚本预览 Tab ====================

function scriptsGenerate() {
    var hw = gv('cfg-hardware_type');
    var containerName = gv('cfg-container_name');
    var imageId = gv('cfg-image_id');
    var workspace = gv('cfg-workspace');
    var modelName = gv('cfg-model_name');
    var modelPath = gv('cfg-model_path');
    var tokenizerPath = gv('cfg-tokenizer_path') || modelPath;
    var port = gv('cfg-service_port');
    var serviceScript = gv('cfg-service_script');

    var phases = [
        {
            num: 1, title: '环境检测',
            cmd: '# Phase 1: 环境检测\n' +
                (hw === 'p800' || hw === 'auto' ? 'xpu-smi\n' : '') +
                (hw === 'h20' || hw === 'auto' ? 'nvidia-smi\n' : '') +
                'df -h /ssd1 /ssd2 /ssd3 /ssd4\n' +
                'docker info --format \'Docker: {{.ServerVersion}}\''
        },
        {
            num: 2, title: '镜像与模型准备',
            cmd: (function() {
                var src = gv('cfg-image_source');
                var c = '# Phase 2: 镜像与模型准备\n';
                if (src === 'registry') c += 'docker pull ' + imageId + '\n';
                else if (src === 'tar') c += 'docker load -i ' + gv('cfg-image_tar_path') + '\n';
                else if (src === 'tar_gz') c += 'tar -xzvf ' + gv('cfg-image_tar_path') + '\ndocker load -i <解压后的tar文件>\n';
                else if (src === 'url') c += 'wget -O /tmp/image.tar ' + gv('cfg-image_url') + '\ndocker load -i /tmp/image.tar\n';
                var dlSrc = gv('cfg-model_download_source');
                if (dlSrc === 'modelscope') {
                    c += '\n# 下载模型\nmodelscope download --model ' + gv('cfg-model_download_id') + ' --local_dir ' + modelPath;
                }
                c += '\n\n# 检查 evalscope\nwhich evalscope || pip install evalscope';
                return c;
            })()
        },
        {
            num: 3, title: '创建容器',
            cmd: (function() {
                var c = '# Phase 3: 创建容器 (' + (hw === 'auto' ? '自动检测' : hw) + ')\n';
                if (hw === 'p800' || hw === 'auto') {
                    c += 'docker run -it \\\n';
                    c += '    --device=/dev/xpu0:/dev/xpu0 ... --device=/dev/xpu7:/dev/xpu7 \\\n';
                    c += '    --device=/dev/xpuctrl:/dev/xpuctrl \\\n';
                    c += '    --privileged --net=host -dti \\\n';
                    c += '    --cap-add=SYS_PTRACE --security-opt seccomp=unconfined \\\n';
                    c += '    --tmpfs /dev/shm:rw,nosuid,nodev,exec,size=' + gv('cfg-tmpfs_size') + ' \\\n';
                    c += '    -v ' + workspace + ':/dir \\\n';
                    c += '    -v /ssd1:/ssd1 -v /ssd2:/ssd2 -v /ssd3:/ssd3 -v /ssd4:/ssd4 \\\n';
                    c += '    --name ' + containerName + ' -w /dir --restart=always \\\n';
                    c += '    ' + imageId + ' /bin/bash';
                } else {
                    c += 'docker run --privileged \\\n';
                    c += '    --name=' + containerName + ' \\\n';
                    c += '    --ulimit core=-1 --security-opt seccomp=unconfined \\\n';
                    c += '    -dti --entrypoint=/bin/bash --gpus all \\\n';
                    c += '    --net=host --uts=host --ipc=host \\\n';
                    c += '    -v ' + workspace + ':/dir \\\n';
                    c += '    -v /ssd1:/ssd1 -v /ssd2:/ssd2 -v /ssd3:/ssd3 -v /ssd4:/ssd4 \\\n';
                    c += '    -w /dir --shm-size=' + gv('cfg-shared_memory_size') + ' --restart=always \\\n';
                    c += '    ' + imageId;
                }
                return c;
            })()
        },
        {
            num: 4, title: '启动服务 & 验证',
            cmd: '# Phase 4: 启动服务\n' +
                (serviceScript ? 'docker exec -d ' + containerName + ' bash -c "cd /dir && bash ' + serviceScript + '"\n\n' : '# (需手动启动服务)\n\n') +
                '# 等待服务就绪后验证\ncurl -X POST "http://127.0.0.1:' + port + '/v1/chat/completions" \\\n' +
                '  -H "Content-Type: application/json" \\\n' +
                '  -d \'{\n' +
                '    "model": "' + modelName + '",\n' +
                '    "messages": [{"role": "user", "content": "介绍一下你自己"}],\n' +
                '    "temperature": 0.7, "max_tokens": 256, "stream": false\n' +
                '  }\''
        },
        {
            num: 5, title: '性能测试',
            cmd: (function() {
                if (!document.getElementById('cfg-perf_enabled').checked) return '# Phase 5: 性能测试 (已禁用)';
                var c = '# Phase 5: 性能测试 (' + gv('cfg-perf_mode') + '模式)\n';
                if (gv('cfg-perf_mode') === 'benchmark') {
                    c += '# 多rate梯度测试\n';
                    rateParallels.slice(0, 3).forEach(function(rp) {
                        c += 'evalscope perf \\\n';
                        c += '    --url http://127.0.0.1:' + port + '/v1/completions \\\n';
                        c += '    --model ' + modelName + ' --dataset random \\\n';
                        c += '    --parallel ' + rp.parallel + ' --rate ' + rp.rate + ' \\\n';
                        c += '    --number ' + gv('cfg-perf_number') + ' \\\n';
                        c += '    --max-prompt-length ' + gv('cfg-perf_input_len') + ' --min-prompt-length ' + gv('cfg-perf_input_len') + ' \\\n';
                        c += '    --max-tokens ' + gv('cfg-perf_output_len') + ' --min-tokens ' + gv('cfg-perf_output_len') + ' \\\n';
                        c += '    --tokenizer-path ' + tokenizerPath + '\n\n';
                    });
                    c += '# ... 共 ' + rateParallels.length + ' 个rate梯度';
                } else {
                    c += 'evalscope perf \\\n';
                    c += '    --url http://127.0.0.1:' + port + '/v1/completions \\\n';
                    c += '    --model ' + modelName + ' --dataset random \\\n';
                    c += '    --parallel ' + gv('cfg-perf_single_parallel') + ' \\\n';
                    c += '    --number ' + gv('cfg-perf_single_number') + ' \\\n';
                    c += '    --max-prompt-length ' + gv('cfg-perf_input_len') + ' --min-prompt-length ' + gv('cfg-perf_input_len') + ' \\\n';
                    c += '    --max-tokens ' + gv('cfg-perf_output_len') + ' --min-tokens ' + gv('cfg-perf_output_len') + ' \\\n';
                    c += '    --tokenizer-path ' + tokenizerPath;
                }
                return c;
            })()
        },
        {
            num: 6, title: '精度测试',
            cmd: (function() {
                if (!document.getElementById('cfg-eval_enabled').checked) return '# Phase 6: 精度测试 (已禁用)';
                var datasets = Array.from(cfgEvalSelected);
                if (datasets.length === 0) return '# Phase 6: 精度测试 (未选择数据集)';
                var c = '# Phase 6: 精度测试\n# 数据集: ' + datasets.join(', ') + '\n\n';
                // 只展示前2个作为示例
                datasets.slice(0, 2).forEach(function(ds) {
                    c += 'evalscope eval \\\n';
                    c += '    --model "' + modelName + '" \\\n';
                    c += '    --api-url "http://127.0.0.1:' + port + '/v1" \\\n';
                    c += '    --api-key "EMPTY" --eval-type openai_api \\\n';
                    c += '    --datasets "' + ds + '" \\\n';
                    c += '    --eval-batch-size ' + gv('cfg-eval_batch_size') + ' \\\n';
                    c += '    --stream --timeout 10000 --ignore-errors\n\n';
                });
                if (datasets.length > 2) c += '# ... 共 ' + datasets.length + ' 个数据集';
                return c;
            })()
        },
        {
            num: 7, title: '结果导出',
            cmd: '# Phase 7: 结果导出\n' +
                'python3 scripts/07_export_results.sh\n' +
                '# 性能结果 -> results/perf/perf_results_*.xlsx\n' +
                '# 精度汇总 -> results/eval/eval_summary_*.txt\n' +
                '# 测试报告 -> results/reports/test_report_*.md'
        }
    ];

    // 渲染可折叠面板
    var previewEl = document.getElementById('scripts-preview');
    previewEl.innerHTML = phases.map(function(p) {
        return '<div class="script-phase open">' +
            '<div class="script-phase-header" onclick="togglePhase(this)">' +
                '<div class="script-phase-num">' + p.num + '</div>' +
                '<div class="script-phase-title">' + p.title + '</div>' +
                '<span class="script-phase-toggle">&#9654;</span>' +
            '</div>' +
            '<div class="script-phase-body"><pre>' + escapeHtml(p.cmd) + '</pre></div>' +
        '</div>';
    }).join('');

    // 汇总全部到底部
    var allText = phases.map(function(p) { return p.cmd; }).join('\n\n' + '='.repeat(50) + '\n\n');
    document.getElementById('scripts-all-text').textContent = allText;
}

function togglePhase(headerEl) {
    headerEl.parentElement.classList.toggle('open');
}

function scriptsCopyAll() {
    var text = document.getElementById('scripts-all-text').textContent;
    copyToClipboard(text);
    showToast('全部脚本已复制到剪贴板');
}

// ==================== 命令生成 Tab ====================

// --- 子 Tab 切换 ---
function showCmdgenSub(sub) {
    document.getElementById('cmdgen-bench').style.display = sub === 'bench' ? '' : 'none';
    document.getElementById('cmdgen-evalscope').style.display = sub === 'evalscope' ? '' : 'none';
    document.getElementById('cmdgen-tab-bench').classList.toggle('active', sub === 'bench');
    document.getElementById('cmdgen-tab-evalscope').classList.toggle('active', sub === 'evalscope');
    if (sub === 'evalscope' && !window._evalDatasetsRendered) {
        evalRenderDatasets();
        evalGenerate();
        window._evalDatasetsRendered = true;
    }
}

// --- Bench 性能测试命令生成 ---
function benchApplyPreset(profile) {
    document.querySelectorAll('#cmdgen-bench .preset-btn').forEach(function(b) { b.classList.remove('active'); });
    if (event && event.target) event.target.classList.add('active');
    switch (profile) {
        case '3.5k':
            benchSetDataset('random', './ShareGPT_V3_unfiltered_cleaned_split.json');
            document.getElementById('bench-inputLen').value = 3500;
            document.getElementById('bench-outputLen').value = 1000;
            document.getElementById('bench-concurrency').value = 32;
            document.getElementById('bench-numPrompts').value = 800;
            break;
        case '16k':
            benchSetDataset('random', './ShareGPT_V3_unfiltered_cleaned_split.json');
            document.getElementById('bench-inputLen').value = 16384;
            document.getElementById('bench-outputLen').value = 1024;
            document.getElementById('bench-concurrency').value = 32;
            document.getElementById('bench-numPrompts').value = 800;
            break;
        case '32k':
            benchSetDataset('random', './ShareGPT_V3_unfiltered_cleaned_split.json');
            document.getElementById('bench-inputLen').value = 32768;
            document.getElementById('bench-outputLen').value = 1024;
            document.getElementById('bench-concurrency').value = 32;
            document.getElementById('bench-numPrompts').value = 800;
            break;
        case 'custom':
            benchSetDataset('custom', './custom_acg_data_sglang.jsonl');
            document.getElementById('bench-sharegptOutputLen').value = 1024;
            document.getElementById('bench-concurrency').value = 32;
            document.getElementById('bench-numPrompts').value = 800;
            break;
    }
    benchOnDatasetChange();
    benchGenerate();
}

function benchSetDataset(name, path) {
    document.getElementById('bench-dataset').value = name;
    document.getElementById('bench-datasetPath').value = path;
}

function benchOnDatasetChange() {
    var ds = document.getElementById('bench-dataset').value;
    document.getElementById('bench-randomFields').style.display = ds === 'random' ? '' : 'none';
    document.getElementById('bench-customFields').style.display = ds === 'custom' ? '' : 'none';
}

function benchGenerate() {
    var host = document.getElementById('bench-host').value;
    var port = document.getElementById('bench-port').value;
    var model = document.getElementById('bench-model').value;
    var backend = document.getElementById('bench-backend').value;
    var dataset = document.getElementById('bench-dataset').value;
    var datasetPath = document.getElementById('bench-datasetPath').value;
    var concurrency = document.getElementById('bench-concurrency').value;
    var numPrompts = document.getElementById('bench-numPrompts').value;

    var DATASET_BASE_URL = 'https://klx-public.bj.bcebos.com/fankexin';
    var lines = [];

    if (datasetPath) {
        var filename = datasetPath.split('/').pop();
        lines.push('# 下载数据集 (如已存在则跳过)');
        lines.push('[ ! -f "' + datasetPath + '" ] && wget -q --show-progress -O "' +
            datasetPath + '" "' + DATASET_BASE_URL + '/' + filename + '"');
        lines.push('');
    }

    var args = [
        'python -m sglang.bench_serving',
        '    --backend ' + backend,
        '    --host ' + host,
        '    --port ' + port,
        '    --model "' + model + '"',
        '    --dataset-name ' + dataset,
    ];

    if (dataset === 'random') {
        var inputLen = document.getElementById('bench-inputLen').value;
        var outputLen = document.getElementById('bench-outputLen').value;
        var rangeRatio = document.getElementById('bench-rangeRatio').value;
        if (datasetPath) args.push('    --dataset-path "' + datasetPath + '"');
        args.push('    --random-input-len ' + inputLen);
        args.push('    --random-output-len ' + outputLen);
        args.push('    --random-range-ratio ' + rangeRatio);
        args.push('    --max-concurrency ' + concurrency);
        args.push('    --num-prompts ' + numPrompts);
    } else if (dataset === 'custom') {
        if (datasetPath) args.push('    --dataset-path "' + datasetPath + '"');
        args.push('    --sharegpt-output-len ' + document.getElementById('bench-sharegptOutputLen').value);
        args.push('    --max-concurrency ' + concurrency);
        args.push('    --num-prompts ' + numPrompts);
    }

    var logFile = document.getElementById('bench-logFile').value.trim();
    if (logFile) {
        lines.push(args.join(' \\\n') + ' \\\n    2>&1 | tee "' + logFile + '_$(date +%Y%m%d_%H%M%S).log"');
    } else {
        lines.push(args.join(' \\\n'));
    }

    document.getElementById('bench-cmdText').textContent = lines.join('\n');
}

function benchCopy() {
    var text = document.getElementById('bench-cmdText').textContent;
    copyToClipboard(text);
    showToast('Bench 命令已复制');
}

// --- EvalScope 评测命令生成 ---
function evalRenderDatasets() {
    var grid = document.getElementById('eval-datasetGrid');
    if (!grid) return;
    grid.innerHTML = EVAL_DATASETS.map(function(d) {
        var cls = 'cmdgen-dataset-chip' + (evalSelected.has(d.name) ? ' selected' : '');
        return '<div class="' + cls + '" onclick="evalToggleDs(\'' + d.name + '\')">' +
            d.name + '<span class="tag">' + d.group + '</span></div>';
    }).join('');
}

function evalToggleDs(name) {
    if (evalSelected.has(name)) evalSelected.delete(name);
    else evalSelected.add(name);
    evalRenderDatasets();
    evalGenerate();
}

function evalSelectAll() {
    EVAL_DATASETS.forEach(function(d) { evalSelected.add(d.name); });
    evalRenderDatasets(); evalGenerate();
}

function evalSelectNone() {
    evalSelected.clear();
    evalRenderDatasets(); evalGenerate();
}

function evalSelectGroup(g) {
    evalSelected.clear();
    EVAL_DATASETS.filter(function(d) { return d.group === g; })
        .forEach(function(d) { evalSelected.add(d.name); });
    evalRenderDatasets(); evalGenerate();
}

function evalGenerate() {
    var cmdText = document.getElementById('eval-cmdText');
    if (!cmdText) return;
    if (evalSelected.size === 0) {
        cmdText.textContent = '# 请选择至少一个数据集';
        return;
    }

    var modelName = document.getElementById('eval-modelName').value;
    var baseUrl = document.getElementById('eval-baseUrl').value;
    var apiKey = document.getElementById('eval-apiKey').value;
    var ebs = document.getElementById('eval-ebs').value;
    var timeout = document.getElementById('eval-timeout').value;
    var stream = document.getElementById('eval-stream').value === 'true';
    var maxTokens = document.getElementById('eval-maxTokens').value;
    var temp = document.getElementById('eval-temperature').value;
    var topP = document.getElementById('eval-topP').value;
    var topK = document.getElementById('eval-topK').value.trim();
    var thinking = document.getElementById('eval-thinkingMode').value;
    var judgeUrl = document.getElementById('eval-judgeUrl').value.trim();
    var judgeKey = document.getElementById('eval-judgeKey').value.trim();
    var judgeModel = document.getElementById('eval-judgeModel').value.trim();

    var genObj = '{"max_tokens":' + maxTokens + ',"temperature":' + temp + ',"top_p":' + topP;
    if (topK) genObj += ',"top_k":' + topK;
    if (thinking === 'true') genObj += ',"extra_body":{"chat_template_kwargs":{"thinking":true,"enable_thinking":true}}';
    else if (thinking === 'false') genObj += ',"extra_body":{"chat_template_kwargs":{"thinking":false,"enable_thinking":false}}';
    genObj += '}';

    var cmds = [];
    evalSelected.forEach(function(dsName) {
        var ds = EVAL_DATASETS.find(function(d) { return d.name === dsName; });
        if (!ds) return;
        var parts = [];
        var localPath = EVAL_LOCAL_PATHS[dsName] || '';
        if (localPath) parts.push('"local_path":"' + localPath + '"');
        if (EVAL_SUBSET_LISTS[dsName]) parts.push('"subset_list":' + EVAL_SUBSET_LISTS[dsName]);
        if (dsName === 'tau2_bench') {
            parts.push('"extra_params":{"user_model":"' + modelName + '","api_key":"EMPTY","api_base":"' + baseUrl + '/v1"}');
        }
        var datasetArgs = '{"' + dsName + '":{' + parts.join(',') + '}}';

        var args = [
            'evalscope eval',
            '  --model "' + modelName + '"',
            '  --api-url "' + baseUrl + '/v1"',
            '  --api-key "' + apiKey + '"',
            '  --eval-type openai_api',
            '  --datasets "' + dsName + '"',
            '  --generation-config \'' + genObj + '\'',
            '  --timeout ' + timeout,
        ];
        if (stream) args.push('  --stream');
        args.push('  --eval-batch-size ' + ebs);
        args.push('  --dataset-args \'' + datasetArgs + '\'');
        args.push('  --work-dir "./outputs/' + dsName + '_mock"');
        args.push('  --ignore-errors');

        if (EVAL_JUDGE_DATASETS.indexOf(dsName) !== -1) {
            var jUrl = judgeUrl || (baseUrl + '/v1');
            var jKey = judgeKey || 'EMPTY';
            var jModel = judgeModel || modelName;
            args.push('  --judge-strategy llm');
            args.push('  --judge-model-args \'{"api_url":"' + jUrl + '","api_key":"' + jKey + '","model_id":"' + jModel + '"}\'');
        }
        cmds.push(args.join(' \\\n') + ' \\\n  2>&1 | tee "logs/' + dsName + '_$(date +%Y%m%d_%H%M%S).log"');
    });
    cmdText.textContent = 'mkdir -p logs\n\n' + cmds.join('\n\n');
}

function evalCopy() {
    var text = document.getElementById('eval-cmdText').textContent;
    copyToClipboard(text);
    showToast('EvalScope 命令已复制');
}

// ==================== 通用工具函数 ====================

function escapeHtml(str) {
    var div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
}

function copyToClipboard(text) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text);
    } else {
        var textarea = document.createElement('textarea');
        textarea.value = text;
        textarea.style.position = 'fixed';
        textarea.style.opacity = '0';
        document.body.appendChild(textarea);
        textarea.select();
        document.execCommand('copy');
        document.body.removeChild(textarea);
    }
}

function downloadFile(filename, content, mime) {
    var blob = new Blob([content], { type: mime || 'text/plain;charset=utf-8' });
    var url = URL.createObjectURL(blob);
    var a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
}

function showToast(msg) {
    var toast = document.createElement('div');
    toast.textContent = msg;
    toast.style.cssText = 'position:fixed;bottom:30px;left:50%;transform:translateX(-50%);' +
        'background:#333;color:#fff;padding:10px 24px;border-radius:8px;font-size:14px;z-index:9999;' +
        'animation:fadeIn .3s ease;box-shadow:0 4px 12px rgba(0,0,0,.2)';
    document.body.appendChild(toast);
    setTimeout(function() {
        toast.style.opacity = '0';
        toast.style.transition = 'opacity .3s';
        setTimeout(function() { document.body.removeChild(toast); }, 300);
    }, 2000);
}
