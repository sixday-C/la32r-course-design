`include "mycpu_head.v"
module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
    input  wire [7:0]  hw_int_in,

    // inst sram interface
    output wire        inst_sram_en,
    output wire [3:0]  inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,

    // data sram interface
    output wire        data_sram_en,
    output wire [3:0]  data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,

    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [3:0]  debug_wb_rf_we,
    output wire [4:0]  debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);

reg reset;
always @(posedge clk) begin
    reset <= ~resetn;
end

wire fs_to_ds_valid;
wire ds_to_es_valid;
wire es_to_ms_valid;
wire ms_to_ws_valid;

wire ds_allowin;
wire es_allowin;
wire ms_allowin;
wire ws_allowin;

wire [`BR_BUS_WD-1:0]       br_bus;
wire [`FS_TO_DS_BUS_WD-1:0] fs_to_ds_bus;
wire [`DS_TO_ES_BUS_WD-1:0] ds_to_es_bus;
wire [`ES_TO_MS_BUS_WD-1:0] es_to_ms_bus;
wire [`MS_TO_WS_BUS_WD-1:0] ms_to_ws_bus;
wire [`WS_TO_RF_BUS_WD-1:0] ws_to_rf_bus;
wire [`ES_FWD_BUS_WD-1:0]   es_fwd_bus;
wire [`MS_FWD_BUS_WD-1:0]   ms_fwd_bus;
wire [`WS_FWD_BUS_WD-1:0]   ws_fwd_bus;
wire wb_flush;
wire wb_ex;
wire wb_ertn;
wire [5:0] wb_ecode;
wire [8:0] wb_esubcode;
wire [31:0] wb_badv;
wire [31:0] ex_entry;
wire [31:0] ertn_entry;
wire [31:0] csr_rvalue;
wire csr_re;
wire [13:0] csr_num;
wire csr_we;
wire [31:0] csr_wmask;
wire [31:0] csr_wvalue;
wire has_int;
wire [63:0] counter_value;
wire [31:0] tid_value;

// 五级流水级通过 bus 传递数据；顶层只负责连线。
IF_stage u_if (
    .clk             (clk),
    .reset           (reset),
    .flush           (wb_flush),
    .flush_pc        (wb_ex ? ex_entry : ertn_entry),
    .ds_allowin      (ds_allowin),
    .br_bus          (br_bus),
    .fs_to_ds_valid  (fs_to_ds_valid),
    .fs_to_ds_bus    (fs_to_ds_bus),
    .inst_sram_en    (inst_sram_en),
    .inst_sram_we    (inst_sram_we),
    .inst_sram_addr  (inst_sram_addr),
    .inst_sram_wdata (inst_sram_wdata),
    .inst_sram_rdata (inst_sram_rdata)
);

ID_stage u_id (
    .clk             (clk),
    .reset           (reset),
    .flush           (wb_flush),
    .has_int         (has_int),
    .fs_to_ds_valid  (fs_to_ds_valid),
    .fs_to_ds_bus    (fs_to_ds_bus),
    .ds_allowin      (ds_allowin),
    .es_allowin      (es_allowin),
    .ds_to_es_valid  (ds_to_es_valid),
    .ds_to_es_bus    (ds_to_es_bus),
    .br_bus          (br_bus),
    .es_fwd_bus      (es_fwd_bus),
    .ms_fwd_bus      (ms_fwd_bus),
    .ws_fwd_bus      (ws_fwd_bus),
    .ws_to_rf_bus    (ws_to_rf_bus)
);

EXE_stage u_exe (
    .clk            (clk),
    .reset          (reset),
    .flush          (wb_flush),
    .ds_to_es_valid (ds_to_es_valid),
    .ds_to_es_bus   (ds_to_es_bus),
    .es_allowin     (es_allowin),
    .ms_allowin     (ms_allowin),
    .es_to_ms_valid (es_to_ms_valid),
    .es_to_ms_bus   (es_to_ms_bus),
    .es_fwd_bus     (es_fwd_bus)
);

MEM_stage u_mem (
    .clk             (clk),
    .reset           (reset),
    .flush           (wb_flush),
    .es_to_ms_valid  (es_to_ms_valid),
    .es_to_ms_bus    (es_to_ms_bus),
    .ms_allowin      (ms_allowin),
    .ws_allowin      (ws_allowin),
    .ms_to_ws_valid  (ms_to_ws_valid),
    .ms_to_ws_bus    (ms_to_ws_bus),
    .ms_fwd_bus      (ms_fwd_bus),
    .data_sram_en    (data_sram_en),
    .data_sram_we    (data_sram_we),
    .data_sram_addr  (data_sram_addr),
    .data_sram_wdata (data_sram_wdata)
);

WB_stage u_wb (
    .clk               (clk),
    .reset             (reset),
    .ms_to_ws_valid    (ms_to_ws_valid),
    .ms_to_ws_bus      (ms_to_ws_bus),
    .ws_allowin        (ws_allowin),
    .ws_to_rf_bus      (ws_to_rf_bus),
    .ws_fwd_bus        (ws_fwd_bus),
    .data_sram_rdata   (data_sram_rdata),
    .csr_rvalue       (csr_rvalue),
    .counter_value    (counter_value),
    .tid_value        (tid_value),
    .csr_re           (csr_re),
    .csr_num          (csr_num),
    .csr_we           (csr_we),
    .csr_wmask        (csr_wmask),
    .csr_wvalue       (csr_wvalue),
    .wb_flush         (wb_flush),
    .wb_ex            (wb_ex),
    .wb_ertn          (wb_ertn),
    .wb_ecode         (wb_ecode),
    .wb_esubcode      (wb_esubcode),
    .wb_badv          (wb_badv),
    .debug_wb_pc       (debug_wb_pc),
    .debug_wb_rf_we    (debug_wb_rf_we),
    .debug_wb_rf_wnum  (debug_wb_rf_wnum),
    .debug_wb_rf_wdata (debug_wb_rf_wdata)
);

csr_file u_csr (
    .clk          (clk),
    .reset        (reset),
    .csr_re       (csr_re),
    .csr_num      (csr_num),
    .csr_rvalue   (csr_rvalue),
    .csr_we       (csr_we),
    .csr_wmask    (csr_wmask),
    .csr_wvalue   (csr_wvalue),
    .wb_ex        (wb_ex),
    .wb_ecode     (wb_ecode),
    .wb_esubcode  (wb_esubcode),
    .wb_pc        (debug_wb_pc),
    .wb_badv      (wb_badv),
    .ertn_flush  (wb_ertn),
    .hw_int_in   (hw_int_in),
    .has_int     (has_int),
    .counter_value(counter_value),
    .tid_value   (tid_value),
    .ex_entry     (ex_entry),
    .ertn_entry   (ertn_entry)
);

endmodule
