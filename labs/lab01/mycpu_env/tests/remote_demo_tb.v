`timescale 1ns/1ps
module remote_demo_tb;
reg clk_50M = 0;
always #10 clk_50M = ~clk_50M;
reg reset_btn = 0;
reg [31:0] dip_sw = 32'hfc;
reg [3:0] touch_btn = 0;
wire [15:0] leds;
wire [7:0] dpy0;
wire [7:0] dpy1;
wire txd;
looongson_remote_top dut(
    .clk_50M(clk_50M), .reset_btn(reset_btn),
    .dip_sw(dip_sw), .touch_btn(touch_btn),
    .leds(leds), .dpy0(dpy0), .dpy1(dpy1),
    .txd(txd), .rxd(1'b1)
);
initial begin
    // 不按复位键，也应在 bit 加载后从程序入口启动。
    wait (leds == ~16'h0003 && dut.local_num == 32'h3);
    @(negedge clk_50M);
    if (dpy0 !== 8'hb6 || dpy1 !== 8'h7e)
        $fatal(1, "display mismatch %h %h", dpy0, dpy1);
    @(negedge clk_50M) touch_btn = 4'h4;
    wait (leds == ~16'h0007 && dut.local_num == 32'h7);
    @(negedge clk_50M);
    if (dpy0 !== 8'h32) $fatal(1, "button display mismatch %h", dpy0);
    $display("REMOTE BOARD DEMO PASS");
    $finish;
end
initial begin
    repeat (3000) @(posedge clk_50M);
    $fatal(1, "remote board demo timeout leds=%h num=%h switch=%h",
           leds, dut.local_num, dut.u_soc.switch);
end
endmodule
