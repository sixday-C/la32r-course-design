`ifndef MYCPU_HEAD_V
`define MYCPU_HEAD_V
`define BR_BUS_WD          33
`define FS_TO_DS_BUS_WD    65
// ID→EX 另外带 3 位乘除操作编号；访存宽度和扩展方式占 3 位。
`define DS_TO_ES_BUS_WD   187
`define ES_TO_MS_BUS_WD   202
`define MS_TO_WS_BUS_WD   196
`define WS_TO_RF_BUS_WD    38
`define ES_FWD_BUS_WD      41
`define MS_FWD_BUS_WD      41
`define WS_FWD_BUS_WD      40

`define CSR_NONE           2'd0
`define CSR_RD             2'd1
`define CSR_WR             2'd2
`define CSR_XCHG           2'd3

// 异常信息随指令走到 WB，按位记录，避免在前面流水级改 CSR。
`define EXC_INT            0
`define EXC_ADEF           1
`define EXC_ALE            2
`define EXC_SYS            3
`define EXC_BRK            4
`define EXC_INE            5

`define CSR_CRMD           14'h0000
`define CSR_PRMD           14'h0001
`define CSR_ECFG           14'h0004
`define CSR_ESTAT          14'h0005
`define CSR_ERA            14'h0006
`define CSR_BADV           14'h0007
`define CSR_EENTRY         14'h000c
`define CSR_SAVE0          14'h0030
`define CSR_SAVE1          14'h0031
`define CSR_SAVE2          14'h0032
`define CSR_SAVE3          14'h0033
`define CSR_TID            14'h0040
`define CSR_TCFG           14'h0041
`define CSR_TVAL           14'h0042
`define CSR_TICLR          14'h0044

// ID 交给 EXE 的乘除法操作编号；不使用乘除法时为 NONE。
`define MD_NONE            3'd0
`define MD_MUL_W           3'd1
`define MD_MULH_W          3'd2
`define MD_MULH_WU         3'd3
`define MD_DIV_W           3'd4
`define MD_MOD_W           3'd5
`define MD_DIV_WU          3'd6
`define MD_MOD_WU          3'd7
`endif
