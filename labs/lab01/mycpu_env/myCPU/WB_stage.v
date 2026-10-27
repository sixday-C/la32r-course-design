`include "mycpu_head.v"
module WB_stage(
    input  wire                        clk,
    input  wire                        reset,
    input  wire                        ms_to_ws_valid,
    input  wire [`MS_TO_WS_BUS_WD-1:0] ms_to_ws_bus,
    output wire                        ws_allowin,
    output wire [`WS_TO_RF_BUS_WD-1:0] ws_to_rf_bus,
    output wire [`WS_FWD_BUS_WD-1:0]   ws_fwd_bus,
    input  wire [31:0]                 csr_rvalue,
    input  wire [63:0]                 counter_value,
    input  wire [31:0]                 tid_value,
    output wire                        csr_re,
    output wire [13:0]                 csr_num,
    output wire                        csr_we,
    output wire [31:0]                 csr_wmask,
    output wire [31:0]                 csr_wvalue,
    output wire                        wb_flush,
    output wire                        wb_cache_flush,
    output wire                        wb_ex,
    output wire                        wb_ertn,
    output wire [5:0]                  wb_ecode,
    output wire [8:0]                  wb_esubcode,
    output wire [31:0]                 wb_badv,
    output wire [31:0]                 debug_wb_pc,
    output wire [3:0]                  debug_wb_rf_we,
    output wire [4:0]                  debug_wb_rf_wnum,
    output wire [31:0]                 debug_wb_rf_wdata
);

reg ws_valid;
// WB stage 寄存器：保存 MEM→WB bus，包含本条 load 的返回数据。
reg [`MS_TO_WS_BUS_WD-1:0] ws_bus_r;

wire ws_ready_go = 1'b1;
assign ws_allowin = !ws_valid || ws_ready_go;

always @(posedge clk) begin
    if (reset || wb_flush) begin
        ws_valid <= 1'b0;
    end else if (ws_allowin) begin
        ws_valid <= ms_to_ws_valid;
    end

    if (ms_to_ws_valid && ws_allowin) begin
        ws_bus_r <= ms_to_ws_bus;
    end
end

wire [31:0] ws_pc;
wire [31:0] ws_alu_result;
wire ws_res_from_mem;
wire ws_gr_we;
// 从 MEM 带来的访问宽度和扩展方式，用来解释 RAM 返回的 32 位。
wire [1:0] ws_mem_size;
wire ws_mem_unsigned;
wire [4:0] ws_dest;
wire [5:0] ws_exc;
wire ws_ertn;
wire [1:0] ws_csr_op;
wire [13:0] ws_csr_num;
wire [31:0] ws_csr_wmask;
wire [31:0] ws_csr_wvalue;
wire [1:0] ws_cnt_op;
wire [31:0] ws_mem_rdata;
wire ws_icacop;

assign {
    ws_pc, ws_alu_result, ws_res_from_mem, ws_gr_we,
    ws_mem_size, ws_mem_unsigned, ws_dest,
    ws_exc, ws_ertn, ws_csr_op, ws_csr_num,
    ws_csr_wmask, ws_csr_wvalue, ws_cnt_op, ws_mem_rdata,
    ws_icacop
} = ws_bus_r;

assign wb_ex = ws_valid && |ws_exc;
assign wb_ertn = ws_valid && ws_ertn && !wb_ex;
assign wb_cache_flush = ws_valid && ws_icacop && !wb_ex && !wb_ertn;
assign wb_flush = wb_ex || wb_ertn || wb_cache_flush;
assign wb_ecode = ws_exc[`EXC_INT]  ? 6'h00 :
                  ws_exc[`EXC_ADEF] ? 6'h08 :
                  ws_exc[`EXC_ALE]  ? 6'h09 :
                  ws_exc[`EXC_SYS]  ? 6'h0b :
                  ws_exc[`EXC_BRK]  ? 6'h0c : 6'h0d;
assign wb_esubcode = 9'b0;
assign wb_badv = ws_exc[`EXC_ADEF] ? ws_pc : ws_alu_result;

// CSR 访问统一留到 WB：先读旧值，再在这个时钟沿写入新值。
assign csr_re = ws_valid && ws_csr_op != `CSR_NONE && !wb_flush;
assign csr_num = ws_csr_num;
assign csr_we = ws_valid && ws_csr_op[1] && !wb_flush;
assign csr_wmask = ws_csr_wmask;
assign csr_wvalue = ws_csr_wvalue;

// RAM 返回整字；按原地址挑出 byte/half，再决定符号扩展还是零扩展。
// 例如地址 ...11 读 byte，就把最高字节移到最低 8 位。
wire [31:0] shifted_rdata = ws_mem_rdata >> {ws_alu_result[1:0], 3'b000};
// ld.b 读到 0x80 得 0xffffff80；ld.bu 读到同一个值则得 0x00000080。
wire [31:0] load_result =
    ws_mem_size == 2'd1 ?
        {{24{shifted_rdata[7] && !ws_mem_unsigned}}, shifted_rdata[7:0]} :
    ws_mem_size == 2'd2 ?
        {{16{shifted_rdata[15] && !ws_mem_unsigned}}, shifted_rdata[15:0]} :
        ws_mem_rdata;
wire [31:0] final_result =
    ws_csr_op != `CSR_NONE ? csr_rvalue :
    ws_cnt_op == 2'd1 ? counter_value[31:0] :
    ws_cnt_op == 2'd2 ? counter_value[63:32] :
    ws_cnt_op == 2'd3 ? tid_value :
    ws_res_from_mem ? load_result : ws_alu_result;
wire rf_we = ws_valid && ws_gr_we && !wb_flush;

// 写回寄存器堆，并给 ID 阶段提供最终结果的前递。
assign ws_to_rf_bus = {rf_we, ws_dest, final_result};
assign ws_fwd_bus = {ws_valid, ws_gr_we, ws_csr_op[1], ws_dest, final_result};

// debug info generate
assign debug_wb_pc = ws_pc;
assign debug_wb_rf_we = {4{rf_we}};
assign debug_wb_rf_wnum = ws_dest;
assign debug_wb_rf_wdata = final_result;

endmodule
