`include "mycpu_head.v"
module MEM_stage(
    input  wire                        clk,
    input  wire                        reset,
    input  wire                        flush,
    input  wire                        es_to_ms_valid,
    input  wire [`ES_TO_MS_BUS_WD-1:0] es_to_ms_bus,
    input  wire                        ws_allowin,
    output wire                        ms_allowin,
    output wire                        ms_to_ws_valid,
    output wire [`MS_TO_WS_BUS_WD-1:0] ms_to_ws_bus,
    output wire [`MS_FWD_BUS_WD-1:0]   ms_fwd_bus,
    output wire                        data_req,
    output wire [3:0]                  data_we,
    output wire [31:0]                 data_addr,
    output wire [31:0]                 data_wdata,
    input  wire                        data_addr_ok,
    input  wire                        data_data_ok,
    input  wire [31:0]                 data_rdata
);

reg ms_valid;
// MEM stage 寄存器：保存 EX→MEM bus 的地址、存数值和写回控制。
reg [`ES_TO_MS_BUS_WD-1:0] ms_bus_r;

reg request_sent;
wire ms_memory_op;
wire ms_ready_go = !ms_memory_op || (request_sent && data_data_ok);
assign ms_allowin = !ms_valid || (ms_ready_go && ws_allowin);
assign ms_to_ws_valid = ms_valid && ms_ready_go;

always @(posedge clk) begin
    if (reset || flush) begin
        ms_valid <= 1'b0;
    end else if (ms_allowin) begin
        ms_valid <= es_to_ms_valid;
    end

    if (es_to_ms_valid && ms_allowin) begin
        ms_bus_r <= es_to_ms_bus;
    end

    if (reset || flush || ms_allowin)
        request_sent <= 1'b0;
    else if (data_req && data_addr_ok)
        request_sent <= 1'b1;
end

wire [31:0] ms_pc;
wire [31:0] ms_alu_result;
wire [31:0] ms_rkd_value;
wire ms_res_from_mem;
wire ms_gr_we;
wire ms_mem_we;
// 下面这些信息是 ID 发来的，与当前在 ID 的指令无关
wire [1:0] ms_mem_size;
wire ms_mem_unsigned;
wire [4:0] ms_dest;
wire [5:0] ms_exc;
wire ms_ertn;
wire [1:0] ms_csr_op;
wire [13:0] ms_csr_num;
wire [31:0] ms_csr_wmask;
wire [31:0] ms_csr_wvalue;
wire [1:0] ms_cnt_op;

assign {
    ms_pc, ms_alu_result, ms_rkd_value,
    ms_res_from_mem, ms_gr_we, ms_mem_we,
    ms_mem_size, ms_mem_unsigned, ms_dest,
    ms_exc, ms_ertn, ms_csr_op, ms_csr_num,
    ms_csr_wmask, ms_csr_wvalue, ms_cnt_op
} = ms_bus_r;

// 同一个 RAM 端口处理 word、byte 和 half。地址低两位决定落在哪个字节。
assign ms_memory_op = ms_valid && !(|ms_exc) &&
                      (ms_mem_we || ms_res_from_mem);
assign data_req = ms_memory_op && !request_sent && !flush;
// 例如 st.b 写地址 ...01，就只拉高第 1 个字节通道：0010。
// st.h 写地址 ...10，则拉高高半字的两个通道：1100。
wire [3:0] store_we = ms_mem_size == 2'd1 ?
                      (4'b0001 << ms_alu_result[1:0]) :
                      ms_mem_size == 2'd2 ?
                      (4'b0011 << ms_alu_result[1:0]) : 4'b1111;
//控制写的字节通道 按位与
assign data_we = {4{data_req && ms_mem_we}} & store_we;
//写入地址
assign data_addr = ms_alu_result;
// RAM 的写数据仍是 32 位。把 byte/half 复制到各通道，写使能只选目标位置
assign data_wdata = ms_mem_size == 2'd1 ?
                          {4{ms_rkd_value[7:0]}} :
                          ms_mem_size == 2'd2 ?
                          {2{ms_rkd_value[15:0]}} : ms_rkd_value;
assign ms_to_ws_bus = {
    ms_pc, ms_alu_result, ms_res_from_mem, ms_gr_we,
    ms_mem_size, ms_mem_unsigned, ms_dest,
    ms_exc, ms_ertn, ms_csr_op, ms_csr_num,
    ms_csr_wmask, ms_csr_wvalue, ms_cnt_op, data_rdata
};
assign ms_fwd_bus = {
    ms_valid, ms_gr_we, ms_csr_op[1],
    (ms_res_from_mem || ms_csr_op != `CSR_NONE || ms_cnt_op != 0),
    ms_dest, ms_alu_result
};

endmodule
