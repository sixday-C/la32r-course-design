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

测试模型会分别延迟读地址、读数据、写地址和写数据，检查整字与字节访问、依赖指令、分支错误路径、D-Cache 脏行写回、`cacop` 的索引/命中写回，以及 `0xbfaf_f020` 外设地址的绕过访问。末尾的循环还会检查分支预测被使用，以及首次跳转和退出循环时的两次纠正。把 `WAYS` 改为 1 可回归一路实现；`mycpu_top` 默认使用两路。I-Cache 和 D-Cache 缺失时发 4 拍突发读取；D-Cache 写回也使用 4 拍突发写入。

单独检查 I-Cache 命中、同索引替换和三种维护操作：

```sh
iverilog -g2012 -s icache_tb -P icache_tb.WAYS=2 -o /tmp/icache_tb \
  labs/lab01/mycpu_env/myCPU/icache.v labs/lab01/mycpu_env/tests/icache_tb.v
vvp /tmp/icache_tb
```

逐拍检查 D-Cache 连续命中请求：

```sh
iverilog -g2012 -s dcache_pipeline_tb -o /tmp/dcache_pipeline_tb \
  labs/lab01/mycpu_env/myCPU/dcache.v \
  labs/lab01/mycpu_env/tests/dcache_pipeline_tb.v
vvp /tmp/dcache_pipeline_tb
```

两个 Cache 的命中响应与下一条请求在同一时钟沿交接；缺失和维护操作仍会暂停接收。CPU 当前每个访存端口只保留一笔未完成请求，因此逐拍吞吐由模块测试验证。

普通 RAM 写入可进入两项 store buffer；load、外设访问和 `cacop` 会等已确认的写入排空。`mycpu_top.STORE_BUFFER=0` 保留原来的同步等待路径。`store_buffer_tb.v` 检查写入顺序、load/MMIO 阻塞和暖复位保留；`store_buffer_perf_tb.v` 用同一程序分别运行关闭/开启配置，以 LED 完成时刻比较周期数。基准程序由 `tests/bench_store_buffer.S` 生成对应的 `.hex`。

取指阶段使用 64 项 BTB 和两位饱和计数器。ID 阶段比较预测与实际下一 PC，只有预测错误才重定向；异常、`ertn` 和 I-Cache 维护仍以流水线清空为准。

AXI 顶层默认使用四项取指缓冲队列；`mycpu_top.FETCH_QUEUE_DEPTH=1` 使用原单条缓冲路径。AXI 测试在四项配置中检查队列确实装入多条指令；同一程序到达完成标记分别需要 289 拍（单条）和 272 拍（四项）。`fetch_queue_tb.v` 另外检查分支纠正清空旧队列，以及异常跳转后丢弃迟到的旧取指响应。

`cacop` 按参考手册实现 code[4:3] 为 0（Store Tag）、1（索引无效/写回）、2（命中无效/写回），对象 code[2:0] 为 0（I-Cache）或 1（D-Cache）。当前 CPU 没有地址翻译/TLB，课程 n73–n78 中涉及 DMW/TLB 的部分不能作为本阶段的完整验收。
