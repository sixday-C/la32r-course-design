// SoC 自定义性能寄存器：0xfe00 控制，0xfe04～0xfe20 依次为八个计数。
module perf_monitor(
    input  wire        clk,
    input  wire        resetn,
    input  wire [6:0]  events,
    input  wire        control_write,
    input  wire [31:0] control_wdata,
    input  wire [3:0]  read_index,
    output reg  [31:0] read_data
);
reg frozen;
reg [31:0] cycles;
reg [31:0] retired;
reg [31:0] ic_hits;
reg [31:0] ic_misses;
reg [31:0] dc_hits;
reg [31:0] dc_misses;
reg [31:0] branch_correct;
reg [31:0] branch_misses;

always @(posedge clk) begin
    if (!resetn) begin
        frozen <= 1'b0;
        cycles <= 0;
        retired <= 0;
        ic_hits <= 0;
        ic_misses <= 0;
        dc_hits <= 0;
        dc_misses <= 0;
        branch_correct <= 0;
        branch_misses <= 0;
    end else if (control_write && control_wdata[0]) begin
        // 写 1 清零并重新开始；写 2 冻结快照；写 0 继续计数。
        frozen <= control_wdata[1];
        cycles <= 0;
        retired <= 0;
        ic_hits <= 0;
        ic_misses <= 0;
        dc_hits <= 0;
        dc_misses <= 0;
        branch_correct <= 0;
        branch_misses <= 0;
    end else begin
        if (control_write)
            frozen <= control_wdata[1];
        if (!frozen && !control_write) begin
            cycles <= cycles + 1'b1;
            if (events[0]) retired <= retired + 1'b1;
            if (events[1]) ic_hits <= ic_hits + 1'b1;
            if (events[2]) ic_misses <= ic_misses + 1'b1;
            if (events[3]) dc_hits <= dc_hits + 1'b1;
            if (events[4]) dc_misses <= dc_misses + 1'b1;
            if (events[5] && !events[6])
                branch_correct <= branch_correct + 1'b1;
            if (events[6]) branch_misses <= branch_misses + 1'b1;
        end
    end
end

always @(*) begin
    case (read_index)
        4'd0: read_data = {30'b0, frozen, 1'b0};
        4'd1: read_data = cycles;
        4'd2: read_data = retired;
        4'd3: read_data = ic_hits;
        4'd4: read_data = ic_misses;
        4'd5: read_data = dc_hits;
        4'd6: read_data = dc_misses;
        4'd7: read_data = branch_correct;
        4'd8: read_data = branch_misses;
        default: read_data = 32'b0;
    endcase
end
endmodule
