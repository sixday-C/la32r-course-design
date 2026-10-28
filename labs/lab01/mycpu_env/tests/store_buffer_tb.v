`timescale 1ns/1ps
module store_buffer_tb;
reg clk = 0;
always #5 clk = ~clk;
reg resetn = 1;
reg cpu_req = 0;
reg [3:0] cpu_we = 0;
reg [31:0] cpu_addr = 0;
reg [31:0] cpu_wdata = 0;
wire cpu_addr_ok, cpu_data_ok, dc_req, empty;
wire [31:0] cpu_rdata, dc_addr, dc_wdata;
wire [3:0] dc_we;
reg dc_addr_ok = 0;
reg dc_data_ok = 0;
reg [31:0] dc_rdata = 0;
store_buffer dut(
    .clk(clk), .resetn(resetn),
    .cpu_req(cpu_req), .cpu_we(cpu_we),
    .cpu_addr(cpu_addr), .cpu_wdata(cpu_wdata),
    .cpu_addr_ok(cpu_addr_ok), .cpu_data_ok(cpu_data_ok),
    .cpu_rdata(cpu_rdata), .dc_req(dc_req), .dc_we(dc_we),
    .dc_addr(dc_addr), .dc_wdata(dc_wdata),
    .dc_addr_ok(dc_addr_ok), .dc_data_ok(dc_data_ok),
    .dc_rdata(dc_rdata), .empty(empty)
);
task enqueue_store;
    input [31:0] addr;
    input [31:0] data;
    begin
        @(negedge clk);
        cpu_req = 1;
        cpu_we = 4'hf;
        cpu_addr = addr;
        cpu_wdata = data;
        #1;
        if (!cpu_addr_ok) $fatal(1, "buffer rejected available slot");
        @(negedge clk);
        cpu_req = 0;
        if (!cpu_data_ok) $fatal(1, "store not acknowledged after enqueue");
    end
endtask
initial begin
    enqueue_store(32'h100, 32'h1234);
    enqueue_store(32'h200, 32'h5678);
    // 普通 load 和 MMIO 都不能越过两笔仍在队列中的写。
    cpu_we = 0;
    cpu_addr = 32'h100;
    cpu_req = 1;
    #1;
    if (cpu_addr_ok || empty) $fatal(1, "load bypassed pending stores");
    cpu_addr = 32'hbfaff020;
    #1;
    if (cpu_addr_ok) $fatal(1, "MMIO bypassed pending stores");
    cpu_req = 0;
    @(negedge clk) resetn = 0;
    repeat (2) @(negedge clk);
    if (empty) $fatal(1, "warm reset discarded accepted stores");
    resetn = 1;
    dc_addr_ok = 1;
    @(negedge clk);
    if (dc_addr !== 32'h100 || dc_wdata !== 32'h1234)
        $fatal(1, "first queued store corrupted");
    dc_addr_ok = 0;
    dc_data_ok = 1;
    @(negedge clk);
    dc_data_ok = 0;
    dc_addr_ok = 1;
    @(negedge clk);
    if (dc_addr !== 32'h200 || dc_wdata !== 32'h5678)
        $fatal(1, "second queued store corrupted");
    dc_addr_ok = 0;
    dc_data_ok = 1;
    @(negedge clk);
    dc_data_ok = 0;
    #1;
    if (!empty) $fatal(1, "queue did not drain");
    $display("STORE BUFFER ORDER AND RESET PASS");
    $finish;
end
endmodule
