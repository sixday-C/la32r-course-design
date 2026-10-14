`include "mycpu_head.v"
module WB_stage(
    input  wire                        clk,
    input  wire                        reset,
    input  wire                        ms_to_ws_valid,
    input  wire [`MS_TO_WS_BUS_WD-1:0] ms_to_ws_bus,
    output wire                        ws_allowin,
    output wire [`WS_TO_RF_BUS_WD-1:0] ws_to_rf_bus,
    output wire [`WS_FWD_BUS_WD-1:0]   ws_fwd_bus,
    input  wire [31:0]                 data_sram_rdata,
    output wire [31:0]                 debug_wb_pc,
    output wire [3:0]                  debug_wb_rf_we,
    output wire [4:0]                  debug_wb_rf_wnum,
    output wire [31:0]                 debug_wb_rf_wdata
);

reg ws_valid;
// WB stage 寄存器：保存 MEM→WB bus；同步 RAM 的读数据在此阶段返回。
reg [`MS_TO_WS_BUS_WD-1:0] ws_bus_r;

wire ws_ready_go = 1'b1;
assign ws_allowin = !ws_valid || ws_ready_go;

always @(posedge clk) begin
    if (reset) begin
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
wire [1:0] ws_mem_size;
wire ws_mem_unsigned;
wire [4:0] ws_dest;

assign {
    ws_pc, ws_alu_result, ws_res_from_mem, ws_gr_we,
    ws_mem_size, ws_mem_unsigned, ws_dest
} = ws_bus_r;

// RAM 返回整字；按原地址挑出 byte/half，再决定符号扩展还是零扩展。
wire [31:0] shifted_rdata = data_sram_rdata >> {ws_alu_result[1:0], 3'b000};
wire [31:0] load_result =
    ws_mem_size == 2'd1 ?
        {{24{shifted_rdata[7] && !ws_mem_unsigned}}, shifted_rdata[7:0]} :
    ws_mem_size == 2'd2 ?
        {{16{shifted_rdata[15] && !ws_mem_unsigned}}, shifted_rdata[15:0]} :
        data_sram_rdata;
wire [31:0] final_result =
    ws_res_from_mem ? load_result : ws_alu_result;
wire rf_we = ws_valid && ws_gr_we;

// 写回寄存器堆，并给 ID 阶段提供最终结果的前递。
assign ws_to_rf_bus = {rf_we, ws_dest, final_result};
assign ws_fwd_bus = {ws_valid, ws_gr_we, ws_dest, final_result};

// debug info generate
assign debug_wb_pc = ws_pc;
assign debug_wb_rf_we = {4{rf_we}};
assign debug_wb_rf_wnum = ws_dest;
assign debug_wb_rf_wdata = final_result;

endmodule
