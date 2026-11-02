# 计算机组成原理课程设计：LoongArch32R 五级流水 CPU

本仓库在课程提供的 LA32R 实验环境中实现五级流水 CPU，并扩展异常与中断、AXI 总线、Cache、分支预测和 SoC 外设。主要实现位于 [`labs/lab01/mycpu_env/myCPU/`](labs/lab01/mycpu_env/myCPU/)，测试位于 [`labs/lab01/mycpu_env/tests/`](labs/lab01/mycpu_env/tests/)。`course_materials/` 保存课程原始资料，供对照使用。

## 实现内容

- **创新基础**：CSR 指令、系统调用、精确异常、`ertn`、地址错与非法指令异常、软件/硬件/定时器中断。
- **Cache 与 AXI**：可变等待的 AXI 读写通道、可配置一路/两路 I-Cache 和 D-Cache、脏行写回、`cacop`、外设地址绕过。
- **其他扩展**：两项 Store Buffer、四项取指队列、I-Cache 顺序预取、BTB 与全局历史分支预测、汇编外设控制、UART 回显和 SoC 性能计数器。

CPU 顶层为 `mycpu_top.v`。`mycpu_core.v` 实现流水线；`mycpu_sram_top.v` 和 `mycpu_hs_top.v` 分别适配课程 SRAM 与握手接口。SoC 演示代码位于 [`labs/lab01/mycpu_env/soc_demo/rtl/`](labs/lab01/mycpu_env/soc_demo/rtl/)。

## 快速复现

需要 Icarus Verilog。以下命令在仓库根目录执行，验证 AXI、Cache、异常路径和分支纠正：

```sh
iverilog -g2012 -s axi_cpu_tb -P axi_cpu_tb.WAYS=2 \
  -I labs/lab01/mycpu_env/myCPU \
  -o /tmp/axi_cpu_tb labs/lab01/mycpu_env/myCPU/*.v \
  labs/lab01/mycpu_env/tests/axi_cpu_tb.v
vvp /tmp/axi_cpu_tb
```

其他模块测试和配置开关见 [`tests/README.md`](labs/lab01/mycpu_env/tests/README.md)；UART、性能寄存器及板卡演示见 [`examples/peripherals/README.md`](labs/lab01/mycpu_env/examples/peripherals/README.md)。

## 定向性能复验

下表为仓库中各定向程序在关闭/开启对应扩展时的仿真周期。每行使用同一程序做对照，不代表完整课程测试集的总体加速比。

| 扩展 | 基线周期 | 扩展后周期 | 降幅 |
| --- | ---: | ---: | ---: |
| Store Buffer | 245 | 234 | 4.5% |
| 四项取指队列 | 289 | 272 | 5.9% |
| I-Cache 顺序预取 | 653 | 383 | 41.3% |
| 全局历史分支预测 | 2239 | 1859 | 17.0% |

这些程序的测试入口分别为 `store_buffer_perf_tb.v`、`axi_cpu_tb.v`、`prefetch_perf_tb.v` 和 `predictor_perf_tb.v`。分支预测定向程序的误预测次数由 202 次降至 12 次。

本实现不含地址翻译和 TLB；相关课程测试不能作为本阶段的完整验收。
