`timescale 1ns/1ps
module peripheral_demo_tb;
reg clk = 0;
always #5 clk = ~clk;
reg resetn = 0;
wire [3:0] arid;
wire [31:0] araddr;
wire [7:0] arlen;
wire arvalid;
wire arready;
reg [3:0] rid = 0;
reg [31:0] rdata = 0;
reg rvalid = 0;
reg rlast = 0;
wire rready;
wire [31:0] awaddr;
wire awvalid;
wire awready;
wire [31:0] wdata;
wire wvalid;
wire wready;
reg bvalid = 0;
wire bready;
reg [7:0] switches = 8'h03;
reg [15:0] buttons = 16'h0010;
reg [31:0] led = 0;
reg [31:0] num = 0;
reg [31:0] imem [0:15];
integer i;
initial begin
    for (i = 0; i < 16; i = i + 1) imem[i] = 0;
    $readmemh("labs/lab01/mycpu_env/examples/peripherals/peripheral_demo.hex",
              imem, 0, 10);
    repeat (5) @(posedge clk);
    @(negedge clk) resetn = 1;
    wait (led == 32'h13 && num == 32'h13);
    @(negedge clk);
    switches = 8'h0a;
    buttons = 16'h0020;
    wait (led == 32'h2a && num == 32'h2a);
    $display("PERIPHERAL ASSEMBLY PASS");
    $finish;
end
initial begin
    repeat (1500) @(posedge clk);
    $fatal(1, "peripheral assembly timeout led=%h num=%h", led, num);
end

mycpu_top cpu(
    .aclk(clk), .aresetn(resetn),
    .arid(arid), .araddr(araddr), .arlen(arlen),
    .arvalid(arvalid), .arready(arready),
    .rid(rid), .rdata(rdata), .rresp(2'b0), .rlast(rlast),
    .rvalid(rvalid), .rready(rready),
    .awaddr(awaddr), .awvalid(awvalid), .awready(awready),
    .wdata(wdata), .wstrb(), .wlast(),
    .wvalid(wvalid), .wready(wready),
    .bid(4'd1), .bresp(2'b0), .bvalid(bvalid), .bready(bready),
    .debug_wb_pc(), .debug_wb_rf_we(),
    .debug_wb_rf_wnum(), .debug_wb_rf_wdata()
);

reg read_pending = 0;
reg [3:0] read_id = 0;
reg [31:0] read_addr = 0;
reg [7:0] read_len = 0;
reg [7:0] read_beat = 0;
assign arready = !read_pending;
always @(posedge clk) begin
    if (!resetn) begin
        read_pending <= 0;
        rvalid <= 0;
    end else begin
        if (arvalid && arready) begin
            read_pending <= 1;
            read_id <= arid;
            read_addr <= araddr;
            read_len <= arlen;
            read_beat <= 0;
        end
        if (read_pending && !rvalid) begin
            rid <= read_id;
            rlast <= read_beat == read_len;
            if (read_id == 0)
                rdata <= imem[read_addr[5:2] + read_beat];
            else if (read_addr == 32'hbfaf_f060)
                rdata <= {24'b0, switches};
            else if (read_addr == 32'hbfaf_f070)
                rdata <= {16'b0, buttons};
            else
                $fatal(1, "unexpected data read %h", read_addr);
            rvalid <= 1;
        end
        if (rvalid && rready) begin
            rvalid <= 0;
            if (rlast) read_pending <= 0;
            else read_beat <= read_beat + 1'b1;
        end
    end
end

reg aw_seen = 0;
reg w_seen = 0;
reg [31:0] saved_awaddr;
reg [31:0] saved_wdata;
assign awready = !aw_seen;
assign wready = !w_seen;
always @(posedge clk) begin
    if (!resetn) begin
        aw_seen <= 0;
        w_seen <= 0;
        bvalid <= 0;
    end else begin
        if (awvalid && awready) begin
            saved_awaddr <= awaddr;
            aw_seen <= 1;
        end
        if (wvalid && wready) begin
            saved_wdata <= wdata;
            w_seen <= 1;
        end
        if (aw_seen && w_seen && !bvalid) begin
            if (saved_awaddr == 32'hbfaf_f020) led <= saved_wdata;
            else if (saved_awaddr == 32'hbfaf_f050) num <= saved_wdata;
            else $fatal(1, "unexpected data write %h", saved_awaddr);
            bvalid <= 1;
        end
        if (bvalid && bready) begin
            bvalid <= 0;
            aw_seen <= 0;
            w_seen <= 0;
        end
    end
end
endmodule
