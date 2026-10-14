`ifndef MYCPU_HEAD_V
`define MYCPU_HEAD_V
`define BR_BUS_WD          33
`define FS_TO_DS_BUS_WD    64
// 三条流水 bus 各多带 3 位：2 位访问宽度、1 位是否零扩展。
`define DS_TO_ES_BUS_WD   153
`define ES_TO_MS_BUS_WD   107
`define MS_TO_WS_BUS_WD    74
`define WS_TO_RF_BUS_WD    38
`define ES_FWD_BUS_WD      40
`define MS_FWD_BUS_WD      40
`define WS_FWD_BUS_WD      39
`endif
