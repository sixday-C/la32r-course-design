# 计算机组成原理课程设计

当前阶段：第一章「不考虑冲突的简单五级流水划分」。先完成 RTL 与功能仿真，之后再进行 Vivado 综合和上板。

## 目录

```text
course_materials/                 课程提供的原始资料，保留不改
  docs/                          指导书与参考文档
  cdp_ede_local-master/           原始 CPU、SoC 和验证环境
  for_test_obj/                  ex1_obj～ex9_obj 课程测试资料
  SHA256SUMS.json                 导入时各原始文件的 SHA-256
labs/
  lab01/
    mycpu_env/                   第一章实验工作副本
      myCPU/                     我们实现和修改的 CPU 代码
      soc_verify/                工作副本中的 SoC 验证环境
      func/                      课程功能测试源码副本
      gettrace/                  课程参考 trace 环境副本
      module_verify/             课程模块验证环境副本
```

课程来源：`/Users/sixdayc/Projects/2026 秋/作业/计组课设/`。

`labs/lab01/mycpu_env` 初始内容与课程原版一致，尚未实现五级流水线，也尚未配置第一章测试镜像。后续实现只修改该工作副本，原始资料用于对照和恢复。完整复制验证环境是为了保留课程脚本的相对路径。

## 第一章工作范围

1. 增加 `inst_sram_en`、`data_sram_en`，将两个 RAM 写使能改为 4 位字节写使能。
2. 将 LA 单周期 CPU 拆成 IF、ID、EX、MEM、WB 五级，增加级间寄存器和有效位控制，适配同步 RAM 时序。
3. 配置 `course_materials/for_test_obj/ex1_obj` 对应的功能测试并进行仿真，核对写回 trace。

第一章暂不实现数据相关阻塞、前递、新指令扩展或乘除法。

LA 版指导书是当前实验依据。`docs/成绩.pdf` 是旧的 TinyMIPS 评分资料，仅保留作参考。既有 `riscvlab-work` 是 RISC-V 项目，本次没有导入到 LA 实验中。

课程提供 Icarus Verilog 仿真 Makefile，但当前尚未验证本机仿真工具和测试路径。资料中的 Vivado 工程创建与上板步骤留待后续执行。
