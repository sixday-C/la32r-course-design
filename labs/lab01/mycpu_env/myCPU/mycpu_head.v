`ifndef MYCPU_HEAD_V
`define MYCPU_HEAD_V
`define BR_BUS_WD          33
`define FS_TO_DS_BUS_WD    64
// ID→EX 另外带 3 位乘除操作编号；访存宽度和扩展方式占 3 位。
`define DS_TO_ES_BUS_WD   156
`define ES_TO_MS_BUS_WD   107
`define MS_TO_WS_BUS_WD    74
`define WS_TO_RF_BUS_WD    38
`define ES_FWD_BUS_WD      40
`define MS_FWD_BUS_WD      40
`define WS_FWD_BUS_WD      39

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
