# 开关与按键外设演示

`peripheral_demo.S` 从课程 SoC 的 `0xbfaf_f060` 开关寄存器和 `0xbfaf_f070` 按键寄存器读取数据，按位或后写到 `0xbfaf_f020` LED 和 `0xbfaf_f050` 数码管寄存器。`uart_echo.S` 保留这组控制，同时轮询物理 UART 的接收状态并把收到的字节回显。

`perf_demo.S` 在此基础上增加性能展示。串口发送小写 `p`，CPU 冻结计数、依次读取八个寄存器并输出一行十六进制数；其他字符仍直接回显。格式为 `C=` 周期、`R=` 完成指令、`I=`/`i=` 指令 Cache 命中/缺失、`D=`/`d=` 数据 Cache 命中/缺失、`B=`/`b=` 分支预测正确/失败。按复位键重新计数。程序在普通 RAM 地址 0 做读写，因此 D-Cache 也会有统计值。

这些是 SoC 自定义的内存映射寄存器，不是 LoongArch 标准性能监测 CSR。地址 `0xbfaf_fe00` 为控制：写 1 清零并开始，写 2 冻结，写 0 继续；`0xbfaf_fe04` 至 `0xbfaf_fe20` 每隔 4 字节依次对应上述八项。外设访问会绕过 D-Cache，也不会计入 D-Cache 命中/缺失。计数器宽 32 位，溢出后回绕。

UART 为 8N1，默认按 25 MHz 时钟配置为 115200 bit/s（每位 217 个时钟）。数据寄存器地址为 `0xbfaf_ff10`，状态寄存器为 `0xbfaf_ff14`：状态 bit 0 表示收到一个字节，bit 1 表示发送端空闲；读数据寄存器取走接收字节，写数据寄存器发送低 8 位。

macOS 先运行 `brew install llvm`，再在本目录运行 `make` 生成三个演示程序的 `.hex`。它使用 `llvm-mc` 的 `loongarch32-unknown-elf` 目标和 `llvm-objcopy`，无需 Vivado。其他系统可通过 `LLVM_BIN` 指向安装了这两个程序的目录。

在仓库根目录运行 SoC 仿真：

```sh
iverilog -g2012 -s soc_demo_tb -I labs/lab01/mycpu_env/myCPU \
  -o /tmp/soc_demo_tb labs/lab01/mycpu_env/myCPU/*.v \
  labs/lab01/mycpu_env/soc_demo/rtl/*.v \
  labs/lab01/mycpu_env/tests/soc_demo_tb.v
vvp /tmp/soc_demo_tb
```

在仓库根目录运行板卡接口仿真：

```sh
iverilog -g2012 -s remote_demo_tb -I labs/lab01/mycpu_env/myCPU \
  -o /tmp/remote_demo_tb labs/lab01/mycpu_env/myCPU/*.v \
  labs/lab01/mycpu_env/soc_demo/rtl/*.v \
  labs/lab01/mycpu_env/tests/remote_demo_tb.v
vvp /tmp/remote_demo_tb
```

串口收发回显端到端仿真：

```sh
iverilog -g2012 -s uart_echo_tb -I labs/lab01/mycpu_env/myCPU \
  -o /tmp/uart_echo_tb labs/lab01/mycpu_env/myCPU/*.v \
  labs/lab01/mycpu_env/soc_demo/rtl/*.v \
  labs/lab01/mycpu_env/tests/uart_echo_tb.v
vvp /tmp/uart_echo_tb
```

性能监测与串口输出的端到端仿真：

```sh
iverilog -g2012 -s perf_demo_tb -I labs/lab01/mycpu_env/myCPU \
  -o /tmp/perf_demo_tb labs/lab01/mycpu_env/myCPU/*.v \
  labs/lab01/mycpu_env/soc_demo/rtl/*.v \
  labs/lab01/mycpu_env/tests/perf_demo_tb.v
vvp /tmp/perf_demo_tb
```

计数器的清零、冻结、恢复和事件分类另有 `tests/perf_monitor_tb.v` 测试。比较运行效率时可用 `C/R` 算平均每条指令的周期数，Cache 命中率可用 `I/(I+i)`、`D/(D+d)`；串口轮询和打印本身也会运行指令，读取 `p` 快照时已暂停计数。

远程板卡构建脚本为 `labs/lab01/mycpu_env/soc_demo/build_openxc7.py`。默认使用仓库旁边已有的 `bitstream-openxc7/tools`；也可设置 `OPENXC7_TOOLS` 指向工具目录。脚本先核对综合后的指令 ROM 与 `perf_demo.hex`，也可以用 `--check-rom` 单独检查。输出文件为 `soc_demo/out/perf_demo_25MHz.bit`。远程板卡上使用低 8 位拨码开关、4 个触摸按键，LED 显示结果低 16 位，两个数码管显示结果低 8 位；`txd`、`rxd` 是 UART 串口引脚。
