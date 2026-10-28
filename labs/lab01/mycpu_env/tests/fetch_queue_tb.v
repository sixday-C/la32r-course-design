`timescale 1ns/1ps
`include "mycpu_head.v"
module fetch_queue_tb;
reg clk = 0;
always #5 clk = ~clk;
reg reset = 1;
reg flush = 0;
reg [31:0] flush_pc = 0;
reg ds_allowin = 0;
reg [`BR_BUS_WD-1:0] br_bus = 0;
wire fs_to_ds_valid;
wire [`FS_TO_DS_BUS_WD-1:0] fs_to_ds_bus;
wire inst_req;
wire [31:0] inst_addr;
reg inst_data_ok = 0;
reg [31:0] inst_rdata = 0;
IF_stage #(.FETCH_QUEUE_DEPTH(4)) dut(
    .clk(clk), .reset(reset), .flush(flush), .flush_pc(flush_pc),
    .ds_allowin(ds_allowin), .br_bus(br_bus),
    .fs_to_ds_valid(fs_to_ds_valid), .fs_to_ds_bus(fs_to_ds_bus),
    .inst_req(inst_req), .inst_addr(inst_addr),
    .inst_addr_ok(1'b1), .inst_data_ok(inst_data_ok),
    .inst_rdata(inst_rdata)
);
task request_and_reply;
    input [31:0] pc;
    input [31:0] instruction;
    begin
        #1;
        if (!inst_req || inst_addr !== pc)
            $fatal(1, "fetch request mismatch got=%h expected=%h", inst_addr, pc);
        @(negedge clk);
        inst_rdata = instruction;
        inst_data_ok = 1;
        @(negedge clk);
        inst_data_ok = 0;
    end
endtask
initial begin
    repeat (2) @(negedge clk);
    reset = 0;
    request_and_reply(32'h1c000000, 32'h11111111);
    request_and_reply(32'h1c000004, 32'h22222222);
    #1;
    if (dut.queued.count != 2 || fs_to_ds_bus[101:70] !== 32'h11111111)
        $fatal(1, "queue did not retain two instructions");

    // ID 发现分支预测错误：队列中旧路径的指令都要丢掉。
    br_bus = {1'b1, 1'b1, 1'b1,
              32'h1c000000, 32'h1c000040, 6'b0};
    @(negedge clk);
    br_bus = 0;
    if (fs_to_ds_valid) $fatal(1, "branch redirect kept wrong-path queue");

    #1;
    if (!inst_req || inst_addr !== 32'h1c000040)
        $fatal(1, "branch target not requested");
    @(negedge clk); // 目标请求已接受，但还没有响应。
    flush = 1;
    flush_pc = 32'h1c000080;
    @(negedge clk);
    flush = 0;
    inst_rdata = 32'hdeadbeef;
    inst_data_ok = 1;
    @(negedge clk);
    inst_data_ok = 0;
    if (fs_to_ds_valid) $fatal(1, "late response after exception was used");

    request_and_reply(32'h1c000080, 32'h33333333);
    #1;
    if (!fs_to_ds_valid || fs_to_ds_bus[69:38] !== 32'h1c000080 ||
        fs_to_ds_bus[101:70] !== 32'h33333333)
        $fatal(1, "exception target instruction/PC mismatch");
    $display("FETCH QUEUE REDIRECT PASS");
    $finish;
end
endmodule
