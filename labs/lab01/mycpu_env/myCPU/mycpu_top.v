// AXI 顶层。读 ID 0 给取指，读 ID 1 给访存；CPU 每个端口最多一笔未完成请求。
module mycpu_top(
    input  wire        aclk,
    input  wire        aresetn,
    output wire [3:0]  arid,
    output wire [31:0] araddr,
    output wire [7:0]  arlen,
    output wire [2:0]  arsize,
    output wire [1:0]  arburst,
    output wire [1:0]  arlock,
    output wire [3:0]  arcache,
    output wire [2:0]  arprot,
    output wire        arvalid,
    input  wire        arready,
    input  wire [3:0]  rid,
    input  wire [31:0] rdata,
    input  wire [1:0]  rresp,
    input  wire        rlast,
    input  wire        rvalid,
    output wire        rready,
    output wire [3:0]  awid,
    output wire [31:0] awaddr,
    output wire [7:0]  awlen,
    output wire [2:0]  awsize,
    output wire [1:0]  awburst,
    output wire [1:0]  awlock,
    output wire [3:0]  awcache,
    output wire [2:0]  awprot,
    output wire        awvalid,
    input  wire        awready,
    output wire [3:0]  wid,
    output wire [31:0] wdata,
    output wire [3:0]  wstrb,
    output wire        wlast,
    output wire        wvalid,
    input  wire        wready,
    input  wire [3:0]  bid,
    input  wire [1:0]  bresp,
    input  wire        bvalid,
    output wire        bready,
    output wire [31:0] debug_wb_pc,
    output wire [3:0]  debug_wb_rf_we,
    output wire [4:0]  debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
wire inst_req;
wire [31:0] inst_addr;
wire inst_addr_ok;
wire inst_data_ok;
wire data_req;
wire [3:0] data_we;
wire [31:0] data_addr;
wire [31:0] data_wdata;
wire data_addr_ok;
wire data_data_ok;

mycpu_core u_core(
    .clk(aclk), .resetn(aresetn), .hw_int_in(8'b0),
    .inst_req(inst_req), .inst_addr(inst_addr),
    .inst_addr_ok(inst_addr_ok), .inst_data_ok(inst_data_ok),
    .inst_rdata(rdata),
    .data_req(data_req), .data_we(data_we),
    .data_addr(data_addr), .data_wdata(data_wdata),
    .data_addr_ok(data_addr_ok), .data_data_ok(data_data_ok),
    .data_rdata(rdata),
    .debug_wb_pc(debug_wb_pc), .debug_wb_rf_we(debug_wb_rf_we),
    .debug_wb_rf_wnum(debug_wb_rf_wnum),
    .debug_wb_rf_wdata(debug_wb_rf_wdata)
);

wire data_read = data_req && !(|data_we);
wire data_write = data_req && (|data_we);
// 数据读优先；两路读请求在对方未被选中时保持，直到 AR 握手。
assign arvalid = data_read || inst_req;
assign arid = data_read ? 4'd1 : 4'd0;
assign araddr = data_read ? data_addr : inst_addr;
assign arlen = 8'd0;
assign arsize = 3'd2;
assign arburst = 2'b01;
assign arlock = 2'b00;
assign arcache = 4'b0000;
assign arprot = 3'b000;
assign inst_addr_ok = inst_req && !data_read && arready;
assign inst_data_ok = rvalid && rready && rid == 4'd0 && rlast;
assign rready = aresetn && (rid == 4'd0 || rid == 4'd1);

reg write_busy;
reg aw_sent;
reg w_sent;
reg [31:0] write_addr;
reg [31:0] write_data;
reg [3:0] write_strb;
wire write_accept = data_write && !write_busy;
assign data_addr_ok = write_accept || (data_read && arready);
assign data_data_ok = (rvalid && rready && rid == 4'd1 && rlast) ||
                      (bvalid && bready);

assign awid = 4'd1;
assign awaddr = write_addr;
assign awlen = 8'd0;
assign awsize = 3'd2;
assign awburst = 2'b01;
assign awlock = 2'b00;
assign awcache = 4'b0000;
assign awprot = 3'b000;
assign awvalid = write_busy && !aw_sent;
assign wid = 4'd1;
assign wdata = write_data;
assign wstrb = write_strb;
assign wlast = 1'b1;
assign wvalid = write_busy && !w_sent;
assign bready = write_busy && aw_sent && w_sent;

always @(posedge aclk) begin
    if (!aresetn) begin
        write_busy <= 1'b0;
        aw_sent <= 1'b0;
        w_sent <= 1'b0;
        write_addr <= 32'b0;
        write_data <= 32'b0;
        write_strb <= 4'b0;
    end else begin
        if (write_accept) begin
            write_busy <= 1'b1;
            aw_sent <= 1'b0;
            w_sent <= 1'b0;
            write_addr <= data_addr;
            write_data <= data_wdata;
            write_strb <= data_we;
        end
        if (awvalid && awready)
            aw_sent <= 1'b1;
        if (wvalid && wready)
            w_sent <= 1'b1;
        if (bvalid && bready)
            write_busy <= 1'b0;
    end
end
endmodule
