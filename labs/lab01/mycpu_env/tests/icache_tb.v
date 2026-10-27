`timescale 1ns/1ps
module icache_tb;
reg clk = 0;
always #5 clk = ~clk;
reg resetn = 0;
reg req = 0;
reg [31:0] addr = 0;
reg maint_req = 0;
reg [31:0] maint_addr = 0;
reg [1:0] maint_code = 0;
wire maint_ready;
wire maint_done;
wire addr_ok;
wire data_ok;
wire [31:0] rdata;
wire rd_req;
wire [31:0] rd_addr;
reg ret_valid = 0;
reg ret_last = 0;
reg [31:0] ret_data = 0;
integer misses = 0;

icache dut(
    .clk(clk), .resetn(resetn), .req(req), .addr(addr),
    .addr_ok(addr_ok), .data_ok(data_ok), .rdata(rdata),
    .rd_req(rd_req), .rd_addr(rd_addr), .rd_ready(1'b1),
    .ret_valid(ret_valid), .ret_last(ret_last), .ret_data(ret_data),
    .maint_req(maint_req), .maint_addr(maint_addr),
    .maint_code(maint_code),
    .maint_ready(maint_ready), .maint_done(maint_done)
);

reg active = 0;
reg [1:0] beat = 0;
reg [31:0] line_addr = 0;
reg wait_cycle = 0;
always @(posedge clk) begin
    if (!resetn) begin
        active <= 0;
        ret_valid <= 0;
        ret_last <= 0;
    end else begin
        ret_valid <= 0;
        if (rd_req) begin
            active <= 1;
            beat <= 0;
            line_addr <= rd_addr;
            wait_cycle <= 1;
            misses <= misses + 1;
        end else if (active) begin
            if (wait_cycle) wait_cycle <= 0;
            else begin
                ret_valid <= 1;
                ret_last <= beat == 3;
                ret_data <= (line_addr[10] ? 32'h200 : 32'h100) + beat;
                wait_cycle <= 1;
                if (beat == 3) active <= 0;
                else beat <= beat + 1'b1;
            end
        end
    end
end

task fetch;
    input [31:0] address;
    input [31:0] expected;
    input integer expected_misses;
    begin
        @(negedge clk);
        addr = address;
        req = 1;
        @(posedge clk);
        while (!addr_ok) @(posedge clk);
        @(negedge clk);
        req = 0;
        @(posedge clk);
        while (!data_ok) @(posedge clk);
        if (rdata !== expected || misses != expected_misses)
            $fatal(1, "cache read %h got %h, misses %0d", address,
                   rdata, misses);
    end
endtask

task maintain;
    input [31:0] address;
    input [1:0] operation;
    begin
        @(negedge clk);
        maint_addr = address;
        maint_code = operation;
        maint_req = 1;
        @(posedge clk);
        while (!maint_ready) @(posedge clk);
        @(negedge clk) maint_req = 0;
        @(posedge clk);
        while (!maint_done) @(posedge clk);
    end
endtask

initial begin
    repeat (4) @(posedge clk);
    @(negedge clk) resetn = 1;
    fetch(32'h1c000000, 32'h100, 1);
    fetch(32'h1c000004, 32'h101, 1);
    fetch(32'h1c000400, 32'h200, 2);
    fetch(32'h1c000000, 32'h100, 3);
    maintain(32'h1c000000, 2);
    fetch(32'h1c000004, 32'h101, 4);
    maintain(32'h1c000400, 1);
    fetch(32'h1c000000, 32'h100, 5);
    maintain(32'h1c000000, 0);
    fetch(32'h1c000000, 32'h100, 6);
    $display("I-CACHE PASS");
    $finish;
end
initial begin
    repeat (300) @(posedge clk);
    $fatal(1, "I-Cache timeout");
end
endmodule
