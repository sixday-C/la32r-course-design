`include "mycpu_head.v"
module EXE_stage(
    input  wire                        clk,
    input  wire                        reset,
    input  wire                        flush,
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

wire es_ready_go;
assign es_allowin = !es_valid || (es_ready_go && ms_allowin);
assign es_to_ms_valid = es_valid && es_ready_go;

always @(posedge clk) begin
    if (reset || flush) begin
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
// 地址在 EXE 算好；访问宽度和扩展方式原样带到后面两级。
wire [1:0] es_mem_size;
wire es_mem_unsigned;
wire [2:0] es_md_op;
wire [4:0] es_dest;
wire [31:0] es_pc;
wire [5:0] es_exc;
wire es_ertn;
wire [1:0] es_csr_op;
wire [13:0] es_csr_num;
wire [1:0] es_cnt_op;

assign {
    es_alu_op, es_src1_is_pc, es_src2_is_imm,
    es_rj_value, es_rkd_value, es_imm,
    es_res_from_mem, es_gr_we, es_mem_we,
    es_mem_size, es_mem_unsigned, es_md_op, es_dest, es_pc,
    es_exc, es_ertn, es_csr_op, es_csr_num, es_cnt_op
} = es_bus_r;

wire [31:0] alu_result;
// EX stage：选择 ALU 两个操作数并计算，结果可前递给 ID。
alu u_alu (
    .alu_op     (es_alu_op),
    .alu_src1   (es_src1_is_pc ? es_pc : es_rj_value),
    .alu_src2   (es_src2_is_imm ? es_imm : es_rkd_value),
    .alu_result (alu_result)
);

wire es_is_div = es_md_op == `MD_DIV_W || es_md_op == `MD_MOD_W ||
                 es_md_op == `MD_DIV_WU || es_md_op == `MD_MOD_WU;
wire es_div_signed = es_md_op == `MD_DIV_W || es_md_op == `MD_MOD_W;
wire es_div_remainder = es_md_op == `MD_MOD_W || es_md_op == `MD_MOD_WU;

// 低 32 位可直接取乘积低位；mulh.w 与 mulh.wu 的高位不同。
wire signed [63:0] signed_product =
    $signed(es_rj_value) * $signed(es_rkd_value);
wire [63:0] unsigned_product = es_rj_value * es_rkd_value;

wire div_busy;
wire div_done;
wire [31:0] div_quotient;
wire [31:0] div_remainder;
// 一条除法进入 EXE 后只启动一次；结果在被 MEM 接收前一直保持。
wire div_start = es_valid && es_is_div && !div_busy && !div_done;
wire div_consume = es_valid && es_is_div && div_done && ms_allowin;
divider_iter u_divider (
    .clk        (clk),
    .reset      (reset || flush),
    .start      (div_start),
    .consume    (div_consume),
    .signed_div (es_div_signed),
    .dividend   (es_rj_value),
    .divisor    (es_rkd_value),
    .busy       (div_busy),
    .done       (div_done),
    .quotient   (div_quotient),
    .remainder  (div_remainder)
);

// 除法未完成时 EXE 保持当前指令，ID/IF 也会随 allowin 停下来。
assign es_ready_go = !es_is_div || div_done;
wire [31:0] es_result =
    es_md_op == `MD_MUL_W   ? signed_product[31:0] :
    es_md_op == `MD_MULH_W  ? signed_product[63:32] :
    es_md_op == `MD_MULH_WU ? unsigned_product[63:32] :
    es_is_div              ? (es_div_remainder ? div_remainder : div_quotient) :
                             alu_result;

// 半字需要 bit0=0，整字需要 bit[1:0]=0；出错时后级不能访问 RAM。
wire es_mem_access = es_res_from_mem || es_mem_we;
wire es_ale = es_mem_access &&
              ((es_mem_size == 2'd2 && es_result[0]) ||
               (es_mem_size == 2'd0 && |es_result[1:0]));
wire [5:0] es_exc_out = es_exc | {3'b0, es_ale, 2'b0};
assign es_to_ms_bus = {
    es_pc, es_result, es_rkd_value,
    es_res_from_mem, es_gr_we, es_mem_we,
    es_mem_size, es_mem_unsigned, es_dest,
    es_exc_out, es_ertn, es_csr_op, es_csr_num,
    (es_csr_op == `CSR_WR ? 32'hffffffff : es_rj_value),
    es_rkd_value, es_cnt_op
};
assign es_fwd_bus = {
    es_valid, es_gr_we, es_csr_op[1],
    (es_res_from_mem || (es_is_div && !div_done) ||
     es_csr_op != `CSR_NONE || es_cnt_op != 0),
    es_dest, es_result
};
//es_result_pending=es_res_from_mem || (es_is_div && !div_done); 当前指令是 load，或除法尚未算完时，该位为 1

endmodule
