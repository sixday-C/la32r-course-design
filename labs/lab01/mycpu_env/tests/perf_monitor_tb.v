`timescale 1ns/1ps
module perf_monitor_tb;
reg clk = 0;
always #5 clk = ~clk;
reg resetn = 0;
reg [6:0] events = 0;
reg control_write = 0;
reg [31:0] control_wdata = 0;
reg [3:0] read_index = 0;
wire [31:0] read_data;
perf_monitor dut(
    .clk(clk), .resetn(resetn), .events(events),
    .control_write(control_write), .control_wdata(control_wdata),
    .read_index(read_index), .read_data(read_data)
);
task check;
    input [3:0] index;
    input [31:0] expected;
    begin
        read_index = index;
        #1;
        if (read_data !== expected)
            $fatal(1, "index %0d: got %0d, expected %0d", index,
                   read_data, expected);
    end
endtask
initial begin
    repeat (2) @(negedge clk);
    resetn = 1;
    events = 7'b1111111;
    repeat (3) @(negedge clk);
    control_write = 1;
    control_wdata = 2;
    @(negedge clk);
    control_write = 0;
    check(1, 3); check(2, 3); check(3, 3); check(4, 3);
    check(5, 3); check(6, 3); check(7, 0); check(8, 3);
    repeat (4) @(negedge clk);
    check(0, 2); check(1, 3); check(2, 3);

    control_write = 1;
    control_wdata = 1;
    @(negedge clk);
    control_write = 0;
    check(0, 0); check(1, 0); check(2, 0);
    events = 7'b0100001; // 完成指令，且一次预测正确的分支
    @(negedge clk);
    check(1, 1); check(2, 1); check(7, 1); check(8, 0);
    $display("PERF MONITOR PASS");
    $finish;
end
endmodule
