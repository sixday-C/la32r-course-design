    .text
    .globl _start
_start:
    # 沿用现有外设演示。发送字符 p 时，打印一次性能计数快照。
    lu12i.w $r12, -0x40501
    ori     $r10, $r12, 0x060    # 开关
    ori     $r11, $r12, 0x070    # 按键
    ori     $r13, $r12, 0x020    # LED
    ori     $r14, $r12, 0x050    # 数码管
    ori     $r15, $r12, 0xf10    # 串口数据
    ori     $r16, $r12, 0xf14    # 串口状态
    ori     $r17, $r12, 0xe00    # 性能监测控制
    addi.w  $r4, $r0, 1
    st.w    $r4, $r17, 0        # 清零后开始计数

loop:
    ld.w    $r4, $r10, 0
    ld.w    $r5, $r11, 0
    or      $r6, $r4, $r5
    st.w    $r6, $r13, 0
    st.w    $r6, $r14, 0

    # 对普通 RAM 做一次读写，让 D-Cache 统计有可观察的命中。
    ld.w    $r5, $r0, 0
    addi.w  $r5, $r5, 1
    st.w    $r5, $r0, 0

    ld.w    $r7, $r16, 0
    andi    $r8, $r7, 1
    beq     $r8, $r0, loop
    ld.w    $r9, $r15, 0
    addi.w  $r8, $r0, 112       # 'p'
    beq     $r9, $r8, print_stats
    st.w    $r9, $r15, 0        # 其他字符照旧回显
    b       loop

print_stats:
    addi.w  $r4, $r0, 2
    st.w    $r4, $r17, 0        # 暂停计数，八次读取属于同一快照

    ld.w    $r5, $r17, 4
    addi.w  $r4, $r0, 67        # C: cycles
    bl      print_metric
    ld.w    $r5, $r17, 8
    addi.w  $r4, $r0, 82        # R: retired instructions
    bl      print_metric
    ld.w    $r5, $r17, 12
    addi.w  $r4, $r0, 73        # I: I-Cache hits
    bl      print_metric
    ld.w    $r5, $r17, 16
    addi.w  $r4, $r0, 105       # i: I-Cache misses
    bl      print_metric
    ld.w    $r5, $r17, 20
    addi.w  $r4, $r0, 68        # D: D-Cache hits
    bl      print_metric
    ld.w    $r5, $r17, 24
    addi.w  $r4, $r0, 100       # d: D-Cache misses
    bl      print_metric
    ld.w    $r5, $r17, 28
    addi.w  $r4, $r0, 66        # B: branch predictions correct
    bl      print_metric
    ld.w    $r5, $r17, 32
    addi.w  $r4, $r0, 98        # b: branch mispredictions
    bl      print_metric
    addi.w  $r4, $r0, 10
    bl      uart_putc
    addi.w  $r4, $r0, 0
    st.w    $r4, $r17, 0        # 恢复计数，不清零
    b       loop

# r4 是字母，r5 是 32 位数；输出如 I=0000002a 后跟空格。
print_metric:
    addi.w  $r23, $r1, 0
    addi.w  $r18, $r5, 0
    bl      uart_putc
    addi.w  $r4, $r0, 61
    bl      uart_putc
    addi.w  $r21, $r0, 28
hex_loop:
    srl.w   $r8, $r18, $r21
    andi    $r8, $r8, 15
    slti    $r9, $r8, 10
    bne     $r9, $r0, hex_digit
    addi.w  $r4, $r8, 87        # a～f
    b       hex_send
hex_digit:
    addi.w  $r4, $r8, 48        # 0～9
hex_send:
    bl      uart_putc
    addi.w  $r21, $r21, -4
    bge     $r21, $r0, hex_loop
    addi.w  $r4, $r0, 32
    bl      uart_putc
    jirl    $r0, $r23, 0

uart_putc:
    st.w    $r4, $r15, 0        # UART 忙时总线会等待
    jirl    $r0, $r1, 0
