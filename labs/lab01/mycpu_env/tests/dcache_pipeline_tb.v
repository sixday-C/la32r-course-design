`timescale 1ns/1ps
module dcache_pipeline_tb;
reg clk = 0;
always #5 clk = ~clk;
reg resetn = 0;
reg req = 0;
reg [3:0] we = 0;
reg [31:0] addr = 0;
reg [31:0] wdata = 0;
wire addr_ok;
wire data_ok;
wire [31:0] rdata;
wire rd_req;
wire [31:0] rd_addr;
wire [7:0] rd_len;
wire wr_req;
reg ret_valid = 0;
reg ret_last = 0;
reg [31:0] ret_data = 0;
reg returning = 0;
reg [1:0] beat = 0;
reg wait_cycle = 0;
reg [31:0] line_addr = 0;
integer misses = 0;

dcache #(.WAYS(2)) dut(
    .clk(clk), .resetn(resetn),
    .req(req), .we(we), .addr(addr), .wdata(wdata),
    .addr_ok(addr_ok), .data_ok(data_ok), .rdata(rdata),
    .rd_req(rd_req), .rd_addr(rd_addr), .rd_len(rd_len),
    .rd_ready(1'b1), .ret_valid(ret_valid), .ret_last(ret_last),
    .ret_data(ret_data),
    .wr_req(wr_req), .wr_addr(), .wr_len(), .wr_data(), .wr_strb(),
    .wr_ready(1'b1), .wr_done(1'b0),
    .maint_req(1'b0), .maint_addr(32'b0), .maint_code(2'b0),
    .maint_ready(), .maint_done()
);

always @(posedge clk) begin
    if (!resetn) begin
        returning <= 0;
        ret_valid <= 0;
    end else begin
        ret_valid <= 0;
        if (wr_req) $fatal(1, "unexpected writeback");
        if (rd_req) begin
            if (rd_len != 3) $fatal(1, "wrong refill length");
            returning <= 1;
            line_addr <= rd_addr;
            beat <= 0;
            wait_cycle <= 1;
            misses <= misses + 1;
        end else if (returning) begin
            if (wait_cycle) wait_cycle <= 0;
            else begin
                ret_valid <= 1;
                ret_last <= beat == 3;
                ret_data <= (line_addr[10] ? 32'h200 : 32'h100) + beat;
                wait_cycle <= 1;
                if (beat == 3) returning <= 0;
                else beat <= beat + 1'b1;
            end
        end
    end
end

task load_word;
    input [31:0] address;
    input [31:0] expected;
    begin
        @(negedge clk);
        req = 1;
        we = 0;
        addr = address;
        @(posedge clk);
        while (!addr_ok) @(posedge clk);
        @(negedge clk) req = 0;
        @(posedge clk);
        while (!data_ok) @(posedge clk);
        if (rdata !== expected)
            $fatal(1, "load %h got %h expected %h", address, rdata, expected);
    end
endtask

integer word_no;
initial begin
    repeat (4) @(posedge clk);
    @(negedge clk) resetn = 1;
    load_word(32'h0, 32'h100);
    @(negedge clk);
    req = 1;
    addr = 0;
    @(posedge clk);
    if (!addr_ok) $fatal(1, "first D-Cache hit rejected");
    for (word_no = 0; word_no < 4; word_no = word_no + 1) begin
        @(negedge clk);
        if (word_no < 3) addr = (word_no + 1)*4;
        else req = 0;
        @(posedge clk);
        if (!data_ok || rdata !== 32'h100 + word_no)
            $fatal(1, "D-Cache hit throughput failure at word %0d", word_no);
        if (word_no < 3 && !addr_ok)
            $fatal(1, "next D-Cache hit was not accepted");
    end
    load_word(32'h400, 32'h200);
    if (misses != 2) $fatal(1, "miss count %0d", misses);
    $display("D-CACHE PIPELINE PASS");
    $finish;
end
initial begin
    repeat (300) @(posedge clk);
    $fatal(1, "D-Cache timeout");
end
endmodule
