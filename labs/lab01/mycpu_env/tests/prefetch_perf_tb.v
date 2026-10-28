`timescale 1ns/1ps
module prefetch_perf_tb;
reg clk = 0;
always #5 clk = ~clk;
reg resetn = 0;
wire [15:0] old_led, new_led;
wire [31:0] old_num, new_num;
wire old_tx, new_tx;
reg [31:0] cycles = 0;
reg [31:0] old_done = 0;
reg [31:0] new_done = 0;

soc_demo_top #(
    .ROM_FILE("labs/lab01/mycpu_env/tests/bench_prefetch.hex"),
    .ROM_WORDS(185), .ICACHE_PREFETCH(0)
) baseline(
    .clk(clk), .resetn(resetn), .switch(8'b0), .buttons(16'b0),
    .uart_rxd(1'b1), .uart_txd(old_tx),
    .led(old_led), .num_data(old_num)
);
soc_demo_top #(
    .ROM_FILE("labs/lab01/mycpu_env/tests/bench_prefetch.hex"),
    .ROM_WORDS(185), .ICACHE_PREFETCH(1)
) improved(
    .clk(clk), .resetn(resetn), .switch(8'b0), .buttons(16'b0),
    .uart_rxd(1'b1), .uart_txd(new_tx),
    .led(new_led), .num_data(new_num)
);

always @(posedge clk) begin
    if (resetn) cycles <= cycles + 1'b1;
    if (old_done == 0 && old_led == 180) old_done <= cycles;
    if (new_done == 0 && new_led == 180) new_done <= cycles;
    if (old_done != 0 && new_done != 0) begin
        $display("PREFETCH cycles: baseline=%0d prefetched=%0d", old_done, new_done);
        if (new_done >= old_done)
            $fatal(1, "I-Cache prefetch did not help sequential fetch");
        $display("PREFETCH PERF PASS");
        $finish;
    end
    if (cycles > 4000) $fatal(1, "prefetch benchmark timeout");
end
initial begin
    repeat (5) @(posedge clk);
    @(negedge clk) resetn = 1;
end
endmodule
