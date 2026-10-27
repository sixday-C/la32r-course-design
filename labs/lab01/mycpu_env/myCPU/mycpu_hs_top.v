// 课程握手 SRAM 模板的适配层。CPU 自己完成 byte/half 的对齐与扩展。
module mycpu_hs_top(
    input  wire        clk,
    input  wire        resetn,
    output wire        inst_sram_req,
    output wire        inst_sram_wr,
    output wire [1:0]  inst_sram_size,
    output wire [3:0]  inst_sram_wstrb,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire        inst_sram_addr_ok,
    input  wire        inst_sram_data_ok,
    input  wire [31:0] inst_sram_rdata,
    output wire        data_sram_req,
    output wire        data_sram_wr,
    output wire [1:0]  data_sram_size,
    output wire [3:0]  data_sram_wstrb,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire        data_sram_addr_ok,
    input  wire        data_sram_data_ok,
    input  wire [31:0] data_sram_rdata,
    output wire [31:0] debug_wb_pc,
    output wire [3:0]  debug_wb_rf_we,
    output wire [4:0]  debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
assign inst_sram_wr = 1'b0;
assign inst_sram_size = 2'd2;
assign inst_sram_wstrb = 4'b0;
assign inst_sram_wdata = 32'b0;
assign data_sram_wr = |data_sram_wstrb;
assign data_sram_size = 2'd2;
reg cache_done;
wire cache_req;
always @(posedge clk) begin
    if (!resetn) cache_done <= 1'b0;
    else cache_done <= cache_req;
end
mycpu_core u_core(
    .clk(clk), .resetn(resetn), .hw_int_in(8'b0),
    .inst_req(inst_sram_req), .inst_addr(inst_sram_addr),
    .inst_addr_ok(inst_sram_addr_ok), .inst_data_ok(inst_sram_data_ok),
    .inst_rdata(inst_sram_rdata),
    .data_req(data_sram_req), .data_we(data_sram_wstrb),
    .data_addr(data_sram_addr), .data_wdata(data_sram_wdata),
    .data_addr_ok(data_sram_addr_ok), .data_data_ok(data_sram_data_ok),
    .data_rdata(data_sram_rdata),
    .cache_cmd_req(cache_req), .cache_cmd_code(), .cache_cmd_addr(),
    .cache_cmd_ready(1'b1), .cache_cmd_done(cache_done),
    .debug_wb_pc(debug_wb_pc), .debug_wb_rf_we(debug_wb_rf_we),
    .debug_wb_rf_wnum(debug_wb_rf_wnum),
    .debug_wb_rf_wdata(debug_wb_rf_wdata)
);
endmodule
