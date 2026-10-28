    .text
    .globl _start
_start:
    lu12i.w $r12, -0x40501
    ori     $r13, $r12, 0x020
    ori     $r14, $r12, 0x050
    addi.w  $r4, $r0, 0x55
    addi.w  $r5, $r0, 0
    ori     $r7, $r0, 0x800
    st.w    $r4, $r0, 0
    .rept 32
    addi.w  $r5, $r5, 1
    .endr
    st.w    $r4, $r0, 1024
    .rept 32
    addi.w  $r5, $r5, 1
    .endr
    st.w    $r4, $r7, 0
    .rept 32
    addi.w  $r5, $r5, 1
    .endr
    // 外设写要等前面的普通 RAM 写排空；数码管检查计算结果。
    st.w    $r5, $r14, 0
    st.w    $r4, $r13, 0
done:
    b       done
