# AXI 接口验证

`mycpu_top` 是课程 `soc_axi` 模板使用的 AXI 顶层；`mycpu_core` 使用取指、访存各一组 `req / addr_ok / data_ok` 信号；`mycpu_sram_top` 和 `mycpu_hs_top` 分别适配原同步 SRAM 与握手 SRAM 模板。原同步 SRAM 实验继续使用 `soc_bram` 测试入口。

在仓库根目录运行：

```sh
iverilog -g2012 -s axi_cpu_tb -P axi_cpu_tb.WAYS=2 \
  -I labs/lab01/mycpu_env/myCPU \
  -o /tmp/axi_cpu_tb labs/lab01/mycpu_env/myCPU/*.v \
  labs/lab01/mycpu_env/tests/axi_cpu_tb.v
vvp /tmp/axi_cpu_tb
```

测试模型会分别延迟读地址、读数据、写地址和写数据，检查整字与字节访问、依赖指令、分支错误路径、D-Cache 脏行写回、`cacop` 的索引/命中写回，以及 `0xbfaf_f020` 外设地址的绕过访问。把 `WAYS` 改为 1 可回归一路实现；`mycpu_top` 默认使用两路。I-Cache 和 D-Cache 缺失时发 4 拍突发读取；D-Cache 写回也使用 4 拍突发写入。

单独检查 I-Cache 命中、同索引替换和三种维护操作：

```sh
iverilog -g2012 -s icache_tb -P icache_tb.WAYS=2 -o /tmp/icache_tb \
  labs/lab01/mycpu_env/myCPU/icache.v labs/lab01/mycpu_env/tests/icache_tb.v
vvp /tmp/icache_tb
```

`cacop` 按参考手册实现 code[4:3] 为 0（Store Tag）、1（索引无效/写回）、2（命中无效/写回），对象 code[2:0] 为 0（I-Cache）或 1（D-Cache）。当前 CPU 没有地址翻译/TLB，课程 n73–n78 中涉及 DMW/TLB 的部分不能作为本阶段的完整验收。
