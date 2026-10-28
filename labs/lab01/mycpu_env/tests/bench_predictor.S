    .text
    .globl _start
_start:
    lu12i.w $r12, -0x40501
    ori     $r13, $r12, 0x020
    ori     $r14, $r12, 0x050
    addi.w  $r1, $r0, 0
    addi.w  $r2, $r0, 200
    addi.w  $r3, $r0, 0
loop:
    xori    $r1, $r1, 1
    beq     $r1, $r0, skip
    addi.w  $r3, $r3, 1
skip:
    addi.w  $r2, $r2, -1
    bne     $r2, $r0, loop
    st.w    $r3, $r14, 0
    addi.w  $r4, $r0, 0x55
    st.w    $r4, $r13, 0
done:
    b       done
