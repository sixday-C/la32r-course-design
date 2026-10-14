`include "mycpu_head.v"
module MEM_stage(
    input  wire                        clk,
    input  wire                        reset,
    input  wire                        es_to_ms_valid,
    input  wire [`ES_TO_MS_BUS_WD-1:0] es_to_ms_bus,
    input  wire                        ws_allowin,
    output wire                        ms_allowin,
    output wire                        ms_to_ws_valid,
    output wire [`MS_TO_WS_BUS_WD-1:0] ms_to_ws_bus,
    output wire [`MS_FWD_BUS_WD-1:0]   ms_fwd_bus,
    output wire                        data_sram_en,
    output wire [3:0]                  data_sram_we,
    output wire [31:0]                 data_sram_addr,
    output wire [31:0]                 data_sram_wdata
);

reg ms_valid;
// MEM stage 寄存器：保存 EX→MEM bus 的地址、存数值和写回控制。
reg [`ES_TO_MS_BUS_WD-1:0] ms_bus_r;

wire ms_ready_go = 1'b1;
assign ms_allowin = !ms_valid || (ms_ready_go && ws_allowin);
assign ms_to_ws_valid = ms_valid && ms_ready_go;

always @(posedge clk) begin
    if (reset) begin
        ms_valid <= 1'b0;
    end else if (ms_allowin) begin
        ms_valid <= es_to_ms_valid;
    end

    if (es_to_ms_valid && ms_allowin) begin
        ms_bus_r <= es_to_ms_bus;
    end
end

wire [31:0] ms_pc;
wire [31:0] ms_alu_result;
wire [31:0] ms_rkd_value;
wire ms_res_from_mem;
wire ms_gr_we;
wire ms_mem_we;
wire [4:0] ms_dest;

assign {
    ms_pc, ms_alu_result, ms_rkd_value,
    ms_res_from_mem, ms_gr_we, ms_mem_we, ms_dest
} = ms_bus_r;

// MEM stage：只有 ld.w / st.w 访问数据 RAM；st.w 的 4 个字节写使能全为 1。
// 为 1 时才能访问数据 sram。
assign data_sram_en = ms_valid && (ms_mem_we || ms_res_from_mem);
assign data_sram_we = {4{ms_valid && ms_mem_we}};
assign data_sram_addr = ms_alu_result;
assign data_sram_wdata = ms_rkd_value;
assign ms_to_ws_bus = {
    ms_pc, ms_alu_result, ms_res_from_mem, ms_gr_we, ms_dest
};
assign ms_fwd_bus = {
    ms_valid, ms_gr_we, ms_res_from_mem, ms_dest, ms_alu_result
};

endmodule
