    .text
    .globl _start
_start:
    lu12i.w $r12, -0x40501
    ori     $r13, $r12, 0x020
    addi.w  $r4, $r0, 0
    .rept 180
    addi.w  $r4, $r4, 1
    .endr
    st.w    $r4, $r13, 0
done:
    b       done
