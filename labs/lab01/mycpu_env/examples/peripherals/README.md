# 开关与按键外设演示

`peripheral_demo.S` 从课程 SoC 的 `0xbfaf_f060` 开关寄存器和 `0xbfaf_f070` 按键寄存器读取数据，按位或后写到 `0xbfaf_f020` LED 和 `0xbfaf_f050` 数码管寄存器。程序循环运行；改动输入后可以直接观察输出变化。

macOS 先运行 `brew install llvm`，再在本目录运行 `make` 生成 `peripheral_demo.hex`。它使用 `llvm-mc` 的 `loongarch32-unknown-elf` 目标和 `llvm-objcopy`，无需 Vivado。其他系统可通过 `LLVM_BIN` 指向安装了这两个程序的目录。

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

远程板卡构建脚本为 `labs/lab01/mycpu_env/soc_demo/build_openxc7.py`。默认使用仓库旁边已有的 `bitstream-openxc7/tools`；也可设置 `OPENXC7_TOOLS` 指向工具目录。输出保存在 `soc_demo/out`。远程板卡上使用低 8 位拨码开关、4 个触摸按键，LED 显示结果低 16 位，两个数码管显示结果低 8 位。
