1. 机器环境，模型，镜像，服务脚本（服务）
- 首先通过xpu-smi或者nvidia-smi确认机器是P800还是H20，最终要体现在测试报告中, 环境检查可参考@env.md
- 模型可选，若已有需要填写模型路径，若没有通过modelscope下载，或者手动下载，若没有evalscope要pip下载, 模型下载可参考@model_download.sh
- 提供镜像ID或者镜像链接，若使镜像ID则需要docker pull拉取，若是tar包则docker load-i 导入，若是tar.gz压缩包则需要先tar -xzvf 解压缩，然后再docker load -i 导入， 提供链接或镜像id需要先检查网络是否可以正常访问，若不可以则需要提醒用户设置代理, 设置好以后，通过wget下载或pull拉取
- 创建容器，根据机器选择不同的容器创建脚本，可参考@run_docker_h20.sh 和 @run_docker_p800.sh
- 根据提供好的服务脚本，启动服务
2. curl 看模型回答是否正常,可参考@curl.sh
3. 测试
 - 环境（镜像, 脚本）镜像使用 参考@run_docker_test.sh
 - 性能测试, 参考@benchmark.sh和@perf.sh,看要选哪一种进行测试
 - 精度测试, 参考@eval.sh
 - 结果保存，性能测试通过python脚本@extract_to_excel.py提取后保存在excel中，精度测试截取精度测试结果
4. 查看测试结果是否异常，如果异常需要重复测试两次
5. 最终生成测试报告
