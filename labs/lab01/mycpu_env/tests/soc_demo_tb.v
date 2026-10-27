`timescale 1ns/1ps
module soc_demo_tb;
reg clk = 0;
always #5 clk = ~clk;
reg resetn = 0;
reg [7:0] switch = 8'h03;
reg [15:0] buttons = 16'h0010;
wire [15:0] led;
wire [31:0] num_data;
soc_demo_top dut(
    .clk(clk), .resetn(resetn),
    .switch(switch), .buttons(buttons),
    .uart_rxd(1'b1), .uart_txd(),
    .led(led), .num_data(num_data)
);
initial begin
    repeat (5) @(posedge clk);
    @(negedge clk) resetn = 1;
    wait (led == 16'h13 && num_data == 32'h13);
    @(negedge clk);
    switch = 8'h0a;
    buttons = 16'h0020;
    wait (led == 16'h2a && num_data == 32'h2a);
    $display("SOC PERIPHERAL DEMO PASS");
    $finish;
end
initial begin
    repeat (1500) @(posedge clk);
    $fatal(1, "SoC demo timeout led=%h num=%h", led, num_data);
end
endmodule
