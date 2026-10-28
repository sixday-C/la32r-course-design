`timescale 1ns/1ps
module perf_demo_tb;
localparam integer CLKS_PER_BIT = 217;
reg clk = 0;
always #5 clk = ~clk;
reg resetn = 0;
reg uart_rxd = 1;
wire uart_txd;
wire [15:0] led;
wire [31:0] num_data;
soc_demo_top #(
    .ROM_FILE("labs/lab01/mycpu_env/examples/peripherals/perf_demo.hex"),
    .ROM_WORDS(78), .UART_CLKS_PER_BIT(CLKS_PER_BIT)
) dut(
    .clk(clk), .resetn(resetn), .switch(8'h05), .buttons(16'h0002),
    .uart_rxd(uart_rxd), .uart_txd(uart_txd), .led(led), .num_data(num_data)
);

task send_byte;
    input [7:0] data;
    integer bit_index;
    begin
        @(negedge clk) uart_rxd = 0;
        repeat (CLKS_PER_BIT) @(negedge clk);
        for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
            uart_rxd = data[bit_index];
            repeat (CLKS_PER_BIT) @(negedge clk);
        end
        uart_rxd = 1;
        repeat (CLKS_PER_BIT) @(negedge clk);
    end
endtask

task receive_byte;
    output [7:0] data;
    integer bit_index;
    begin
        wait (uart_txd === 0);
        repeat (CLKS_PER_BIT / 2) @(negedge clk);
        if (uart_txd !== 0) $fatal(1, "TX start bit mismatch");
        for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
            repeat (CLKS_PER_BIT) @(negedge clk);
            data[bit_index] = uart_txd;
        end
        repeat (CLKS_PER_BIT) @(negedge clk);
        if (uart_txd !== 1) $fatal(1, "TX stop bit mismatch");
    end
endtask

reg [7:0] result [0:88];
reg [7:0] labels [0:7];
integer idx;
integer metric;
integer digit;
integer value;
integer nibble;
initial begin
    labels[0] = "C"; labels[1] = "R";
    labels[2] = "I"; labels[3] = "i";
    labels[4] = "D"; labels[5] = "d";
    labels[6] = "B"; labels[7] = "b";
    repeat (5) @(posedge clk);
    @(negedge clk) resetn = 1;
    repeat (2500) @(posedge clk);
    if (led !== 16'h0007 || num_data !== 32'h00000007)
        $fatal(1, "existing peripherals stopped working");
    fork
        send_byte("p");
        begin
            for (idx = 0; idx < 89; idx = idx + 1)
                receive_byte(result[idx]);
        end
    join
    for (metric = 0; metric < 8; metric = metric + 1) begin
        if (result[metric*11] !== labels[metric] ||
            result[metric*11+1] !== "=" ||
            result[metric*11+10] !== " ")
            $fatal(1, "metric %0d label/format mismatch", metric);
        value = 0;
        for (digit = 0; digit < 8; digit = digit + 1) begin
            nibble = result[metric*11+2+digit];
            if (nibble >= "0" && nibble <= "9") nibble = nibble - "0";
            else if (nibble >= "a" && nibble <= "f") nibble = nibble - "a" + 10;
            else $fatal(1, "metric %0d has invalid hex digit", metric);
            value = (value << 4) | nibble;
        end
        $display("%c = %08x", labels[metric], value);
        // 程序清零计数时首行已在 Cache；预取可能让后续 I 缺失为零。
        if (value == 0 && metric != 3)
            $fatal(1, "metric %0d did not count", metric);
    end
    if (result[88] !== 8'h0a) $fatal(1, "missing newline");
    $display("PERF DEMO PASS");
    $finish;
end
initial begin
    repeat (400000) @(posedge clk);
    $fatal(1, "performance UART demo timeout");
end
endmodule
