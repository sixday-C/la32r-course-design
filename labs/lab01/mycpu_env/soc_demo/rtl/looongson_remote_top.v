// 远程板卡的精简入口：50 MHz 分频为 25 MHz，开关/LED 为低电平有效。
module looongson_remote_top(
    input  wire        clk_50M,
    input  wire        reset_btn,
    input  wire [31:0] dip_sw,
    input  wire [3:0]  touch_btn,
    output wire [15:0] leds,
    output wire [7:0]  dpy0,
    output wire [7:0]  dpy1,
    output wire        txd,
    input  wire        rxd
);
reg clk_25M = 1'b0;
always @(posedge clk_50M) begin
    clk_25M <= !clk_25M;
end

wire [15:0] local_led;
wire [31:0] local_num;
soc_demo_top #(
    .ROM_FILE("labs/lab01/mycpu_env/examples/peripherals/uart_echo.hex"),
    .ROM_WORDS(18)
) u_soc(
    .clk(clk_25M),
    .resetn(!reset_btn),
    .switch(~dip_sw[7:0]),
    .buttons({12'b0, touch_btn}),
    .uart_rxd(rxd),
    .uart_txd(txd),
    .led(local_led),
    .num_data(local_num)
);
assign leds = ~local_led;
function [7:0] seg7;
    input [3:0] digit;
    reg [6:0] segments;
    begin
        case (digit)
            4'h0: segments = 7'b1000000;
            4'h1: segments = 7'b1110110;
            4'h2: segments = 7'b0100001;
            4'h3: segments = 7'b0100100;
            4'h4: segments = 7'b0010110;
            4'h5: segments = 7'b0001100;
            4'h6: segments = 7'b0001000;
            4'h7: segments = 7'b1100110;
            4'h8: segments = 7'b0000000;
            4'h9: segments = 7'b0000110;
            4'ha: segments = 7'b0000010;
            4'hb: segments = 7'b0011000;
            4'hc: segments = 7'b1001001;
            4'hd: segments = 7'b0110000;
            4'he: segments = 7'b0001001;
            default: segments = 7'b0001011;
        endcase
        seg7 = {~segments, 1'b0};
    end
endfunction
assign dpy0 = seg7(local_num[3:0]);
assign dpy1 = seg7(local_num[7:4]);
endmodule
