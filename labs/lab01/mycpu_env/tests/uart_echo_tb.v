`timescale 1ns/1ps
module uart_echo_tb;
reg clk = 0;
always #5 clk = ~clk;
reg resetn = 0;
reg uart_rxd = 1;
wire uart_txd;
wire [15:0] led;
wire [31:0] num_data;
soc_demo_top #(
    .ROM_FILE("labs/lab01/mycpu_env/examples/peripherals/uart_echo.hex"),
    .ROM_WORDS(18), .UART_CLKS_PER_BIT(8)
) dut(
    .clk(clk), .resetn(resetn), .switch(8'b0), .buttons(16'b0),
    .uart_rxd(uart_rxd), .uart_txd(uart_txd), .led(led), .num_data(num_data)
);

task send_byte;
    input [7:0] data;
    integer bit_index;
    begin
        @(negedge clk) uart_rxd = 1'b0;
        repeat (8) @(negedge clk);
        for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
            uart_rxd = data[bit_index];
            repeat (8) @(negedge clk);
        end
        uart_rxd = 1'b1;
        repeat (8) @(negedge clk);
    end
endtask

task receive_byte;
    output [7:0] data;
    integer bit_index;
    begin
        wait (uart_txd === 1'b0);
        repeat (4) @(negedge clk);
        if (uart_txd !== 1'b0) $fatal(1, "TX start bit mismatch");
        for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
            repeat (8) @(negedge clk);
            data[bit_index] = uart_txd;
        end
        repeat (8) @(negedge clk);
        if (uart_txd !== 1'b1) $fatal(1, "TX stop bit mismatch");
    end
endtask

reg [7:0] echoed;
initial begin
    repeat (5) @(posedge clk);
    @(negedge clk) resetn = 1;
    fork
        send_byte(8'ha5);
        receive_byte(echoed);
    join
    if (echoed !== 8'ha5) $fatal(1, "UART echo mismatch: got %02x", echoed);
    $display("UART ECHO PASS: %02x", echoed);
    $finish;
end
initial begin
    repeat (20000) @(posedge clk);
    $fatal(1, "UART echo timeout, rx_valid=%b tx=%b", dut.u_uart.rx_valid, uart_txd);
end
endmodule
