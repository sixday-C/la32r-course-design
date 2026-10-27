// 兼容课程早期的同步 SRAM 工程；CPU 内部使用请求/完成握手。
module mycpu_sram_top(
    input  wire        clk,
    input  wire        resetn,
    input  wire [7:0]  hw_int_in,
    output wire        inst_sram_en,
    output wire [3:0]  inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    output wire        data_sram_en,
    output wire [3:0]  data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,
    output wire [31:0] debug_wb_pc,
    output wire [3:0]  debug_wb_rf_we,
    output wire [4:0]  debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
reg inst_done;
reg data_done;
always @(posedge clk) begin
    if (!resetn) begin
        inst_done <= 1'b0;
        data_done <= 1'b0;
    end else begin
        // RAM 在请求时钟沿读出数据，下一拍向 CPU 报告完成。
        inst_done <= inst_sram_en;
        data_done <= data_sram_en;
    end
end
assign inst_sram_we = 4'b0;
assign inst_sram_wdata = 32'b0;
mycpu_core u_core(
    .clk(clk), .resetn(resetn), .hw_int_in(hw_int_in),
    .inst_req(inst_sram_en), .inst_addr(inst_sram_addr),
    .inst_addr_ok(1'b1), .inst_data_ok(inst_done),
    .inst_rdata(inst_sram_rdata),
    .data_req(data_sram_en), .data_we(data_sram_we),
    .data_addr(data_sram_addr), .data_wdata(data_sram_wdata),
    .data_addr_ok(1'b1), .data_data_ok(data_done),
    .data_rdata(data_sram_rdata),
    .debug_wb_pc(debug_wb_pc), .debug_wb_rf_we(debug_wb_rf_we),
    .debug_wb_rf_wnum(debug_wb_rf_wnum),
    .debug_wb_rf_wdata(debug_wb_rf_wdata)
);
endmodule
