    .text
    .globl _start
_start:
    # 保留开关/按键演示，并用物理 UART 回显收到的字节。
    lu12i.w $r12, -0x40501
    ori     $r10, $r12, 0x060    # SWITCH
    ori     $r11, $r12, 0x070    # BTN_KEY
    ori     $r13, $r12, 0x020    # LED
    ori     $r14, $r12, 0x050    # NUM
    ori     $r15, $r12, 0xf10    # UART_DATA
    ori     $r16, $r12, 0xf14    # UART_STATUS

loop:
    ld.w    $r4, $r10, 0
    ld.w    $r5, $r11, 0
    or      $r6, $r4, $r5
    st.w    $r6, $r13, 0
    st.w    $r6, $r14, 0

    # status bit 0 为 RX 有数据；读 DATA 取走字节，再写回完成回显。
    ld.w    $r7, $r16, 0
    andi    $r8, $r7, 1
    beq     $r8, $r0, loop
    ld.w    $r9, $r15, 0
    st.w    $r9, $r15, 0
    b       loop
