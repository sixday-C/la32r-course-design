    .text
    .globl _start
_start:
    # SoC 现有寄存器都在 0xbfaf_fxxx。
    lu12i.w $r12, -0x40501
    ori     $r10, $r12, 0x060    # SWITCH
    ori     $r11, $r12, 0x070    # BTN_KEY
    ori     $r13, $r12, 0x020    # LED
    ori     $r14, $r12, 0x050    # NUM

loop:
    ld.w    $r4, $r10, 0
    ld.w    $r5, $r11, 0
    or      $r6, $r4, $r5
    st.w    $r6, $r13, 0
    st.w    $r6, $r14, 0
    b       loop
