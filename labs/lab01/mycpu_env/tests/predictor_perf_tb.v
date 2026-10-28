`timescale 1ns/1ps
module predictor_perf_tb;
reg clk = 0;
always #5 clk = ~clk;
reg resetn = 0;
wire [15:0] old_led, new_led;
wire [31:0] old_num, new_num;
wire old_tx, new_tx;
reg [31:0] cycles = 0;
reg [31:0] old_done = 0;
reg [31:0] new_done = 0;
reg [31:0] old_misses = 0;
reg [31:0] new_misses = 0;

soc_demo_top #(
    .ROM_FILE("labs/lab01/mycpu_env/tests/bench_predictor.hex"),
    .ROM_WORDS(15), .PREDICTOR_MODE(0)
) baseline(
    .clk(clk), .resetn(resetn), .switch(8'b0), .buttons(16'b0),
    .uart_rxd(1'b1), .uart_txd(old_tx),
    .led(old_led), .num_data(old_num)
);
soc_demo_top #(
    .ROM_FILE("labs/lab01/mycpu_env/tests/bench_predictor.hex"),
    .ROM_WORDS(15), .PREDICTOR_MODE(1)
) improved(
    .clk(clk), .resetn(resetn), .switch(8'b0), .buttons(16'b0),
    .uart_rxd(1'b1), .uart_txd(new_tx),
    .led(new_led), .num_data(new_num)
);

always @(posedge clk) begin
    if (resetn) cycles <= cycles + 1'b1;
    if (old_done == 0 && old_led == 16'h55) begin
        old_done <= cycles;
        old_misses <= baseline.u_perf.branch_misses;
    end
    if (new_done == 0 && new_led == 16'h55) begin
        new_done <= cycles;
        new_misses <= improved.u_perf.branch_misses;
    end
    if (old_done != 0 && new_done != 0) begin
        if (old_num !== 100 || new_num !== 100)
            $fatal(1, "alternating branch result mismatch");
        $display("PREDICTOR: local cycles=%0d misses=%0d, gshare cycles=%0d misses=%0d",
                 old_done, old_misses, new_done, new_misses);
        if (new_misses >= old_misses || new_done >= old_done)
            $fatal(1, "global history predictor did not improve correlated branch workload");
        $display("PREDICTOR PERF PASS");
        $finish;
    end
    if (cycles > 8000) $fatal(1, "predictor benchmark timeout");
end
initial begin
    repeat (5) @(posedge clk);
    @(negedge clk) resetn = 1;
end
endmodule
