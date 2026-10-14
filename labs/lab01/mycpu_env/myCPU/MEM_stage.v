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
wire [1:0] ms_mem_size;
wire ms_mem_unsigned;
wire [4:0] ms_dest;

assign {
    ms_pc, ms_alu_result, ms_rkd_value,
    ms_res_from_mem, ms_gr_we, ms_mem_we,
    ms_mem_size, ms_mem_unsigned, ms_dest
} = ms_bus_r;

// 同一个 RAM 端口处理 word、byte 和 half。地址低两位决定落在哪个字节。
assign data_sram_en = ms_valid && (ms_mem_we || ms_res_from_mem);
wire [3:0] store_we = ms_mem_size == 2'd1 ?
                      (4'b0001 << ms_alu_result[1:0]) :
                      ms_mem_size == 2'd2 ?
                      (4'b0011 << ms_alu_result[1:0]) : 4'b1111;
assign data_sram_we = {4{ms_valid && ms_mem_we}} & store_we;
assign data_sram_addr = ms_alu_result;
// 写 byte/half 时复制到每条字节通道，由 data_sram_we 选中目标通道。
assign data_sram_wdata = ms_mem_size == 2'd1 ?
                          {4{ms_rkd_value[7:0]}} :
                          ms_mem_size == 2'd2 ?
                          {2{ms_rkd_value[15:0]}} : ms_rkd_value;
assign ms_to_ws_bus = {
    ms_pc, ms_alu_result, ms_res_from_mem, ms_gr_we,
    ms_mem_size, ms_mem_unsigned, ms_dest
};
assign ms_fwd_bus = {
    ms_valid, ms_gr_we, ms_res_from_mem, ms_dest, ms_alu_result
};

endmodule
