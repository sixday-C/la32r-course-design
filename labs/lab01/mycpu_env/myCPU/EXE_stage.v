`include "mycpu_head.v"
module EXE_stage(
    input  wire                        clk,
    input  wire                        reset,
    input  wire                        ds_to_es_valid,
    input  wire [`DS_TO_ES_BUS_WD-1:0] ds_to_es_bus,
    input  wire                        ms_allowin,
    output wire                        es_allowin,
    output wire                        es_to_ms_valid,
    output wire [`ES_TO_MS_BUS_WD-1:0] es_to_ms_bus,
    output wire [`ES_FWD_BUS_WD-1:0]   es_fwd_bus
);

reg es_valid;
// EX stage 寄存器：接收 ID→EX bus，保存运算控制和操作数。
reg [`DS_TO_ES_BUS_WD-1:0] es_bus_r;

wire es_ready_go = 1'b1;
assign es_allowin = !es_valid || (es_ready_go && ms_allowin);
assign es_to_ms_valid = es_valid && es_ready_go;

always @(posedge clk) begin
    if (reset) begin
        es_valid <= 1'b0;
    end else if (es_allowin) begin
        es_valid <= ds_to_es_valid;
    end

    if (ds_to_es_valid && es_allowin) begin
        es_bus_r <= ds_to_es_bus;
    end
end

wire [11:0] es_alu_op;
wire es_src1_is_pc;
wire es_src2_is_imm;
wire [31:0] es_rj_value;
wire [31:0] es_rkd_value;
wire [31:0] es_imm;
wire es_res_from_mem;
wire es_gr_we;
wire es_mem_we;
wire [1:0] es_mem_size;
wire es_mem_unsigned;
wire [4:0] es_dest;
wire [31:0] es_pc;

assign {
    es_alu_op, es_src1_is_pc, es_src2_is_imm,
    es_rj_value, es_rkd_value, es_imm,
    es_res_from_mem, es_gr_we, es_mem_we,
    es_mem_size, es_mem_unsigned, es_dest, es_pc
} = es_bus_r;

wire [31:0] alu_result;
// EX stage：选择 ALU 两个操作数并计算，结果可前递给 ID。
alu u_alu (
    .alu_op     (es_alu_op),
    .alu_src1   (es_src1_is_pc ? es_pc : es_rj_value),
    .alu_src2   (es_src2_is_imm ? es_imm : es_rkd_value),
    .alu_result (alu_result)
);

assign es_to_ms_bus = {
    es_pc, alu_result, es_rkd_value,
    es_res_from_mem, es_gr_we, es_mem_we,
    es_mem_size, es_mem_unsigned, es_dest
};
assign es_fwd_bus = {
    es_valid, es_gr_we, es_res_from_mem, es_dest, alu_result
};

endmodule
