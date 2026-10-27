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
wire [31:0] inst_rdata;
wire ic_rd_req;
wire [31:0] ic_rd_addr;
wire ic_rd_ready;
wire data_req;
wire [3:0] data_we;
wire [31:0] data_addr;
wire [31:0] data_wdata;
wire data_addr_ok;
wire data_data_ok;
wire [31:0] data_rdata;
wire dc_rd_req;
wire [31:0] dc_rd_addr;
wire [7:0] dc_rd_len;
wire dc_rd_ready;
wire dc_wr_req;
wire [31:0] dc_wr_addr;
wire [7:0] dc_wr_len;
wire [127:0] dc_wr_data;
wire [15:0] dc_wr_strb;
wire dc_wr_ready;
wire dc_wr_done;

mycpu_core u_core(
    .clk(aclk), .resetn(aresetn), .hw_int_in(8'b0),
    .inst_req(inst_req), .inst_addr(inst_addr),
    .inst_addr_ok(inst_addr_ok), .inst_data_ok(inst_data_ok),
    .inst_rdata(inst_rdata),
    .data_req(data_req), .data_we(data_we),
    .data_addr(data_addr), .data_wdata(data_wdata),
    .data_addr_ok(data_addr_ok), .data_data_ok(data_data_ok),
    .data_rdata(data_rdata),
    .debug_wb_pc(debug_wb_pc), .debug_wb_rf_we(debug_wb_rf_we),
    .debug_wb_rf_wnum(debug_wb_rf_wnum),
    .debug_wb_rf_wdata(debug_wb_rf_wdata)
);

icache u_icache(
    .clk(aclk), .resetn(aresetn),
    .req(inst_req), .addr(inst_addr),
    .addr_ok(inst_addr_ok), .data_ok(inst_data_ok), .rdata(inst_rdata),
    .rd_req(ic_rd_req), .rd_addr(ic_rd_addr),
    .rd_ready(ic_rd_ready),
    .ret_valid(rvalid && rready && rid == 4'd0),
    .ret_last(rlast), .ret_data(rdata)
);

dcache u_dcache(
    .clk(aclk), .resetn(aresetn),
    .req(data_req), .we(data_we), .addr(data_addr), .wdata(data_wdata),
    .addr_ok(data_addr_ok), .data_ok(data_data_ok), .rdata(data_rdata),
    .rd_req(dc_rd_req), .rd_addr(dc_rd_addr), .rd_len(dc_rd_len),
    .rd_ready(dc_rd_ready),
    .ret_valid(rvalid && rready && rid == 4'd1),
    .ret_last(rlast), .ret_data(rdata),
    .wr_req(dc_wr_req), .wr_addr(dc_wr_addr), .wr_len(dc_wr_len),
    .wr_data(dc_wr_data), .wr_strb(dc_wr_strb),
    .wr_ready(dc_wr_ready), .wr_done(dc_wr_done)
);

// 数据读优先；I-Cache 缺失时请求一整行（4 个 32 位 beat）。
assign arvalid = dc_rd_req || ic_rd_req;
assign arid = dc_rd_req ? 4'd1 : 4'd0;
assign araddr = dc_rd_req ? dc_rd_addr : ic_rd_addr;
assign arlen = dc_rd_req ? dc_rd_len : 8'd3;
assign arsize = 3'd2;
assign arburst = 2'b01;
assign arlock = 2'b00;
assign arcache = 4'b0000;
assign arprot = 3'b000;
assign ic_rd_ready = ic_rd_req && !dc_rd_req && arready;
assign dc_rd_ready = dc_rd_req && arready;
assign rready = aresetn && (rid == 4'd0 || rid == 4'd1);

reg write_busy;
reg aw_sent;
reg [31:0] write_addr;
reg [127:0] write_data;
reg [15:0] write_strb;
reg [7:0] write_len;
reg [7:0] write_beat;
reg w_sent;
wire write_accept = dc_wr_req && !write_busy;
assign dc_wr_ready = !write_busy;
assign dc_wr_done = bvalid && bready;

assign awid = 4'd1;
assign awaddr = write_addr;
assign awlen = write_len;
assign awsize = 3'd2;
assign awburst = 2'b01;
assign awlock = 2'b00;
assign awcache = 4'b0000;
assign awprot = 3'b000;
assign awvalid = write_busy && !aw_sent;
assign wid = 4'd1;
assign wdata = write_data[write_beat*32 +: 32];
assign wstrb = write_strb[write_beat*4 +: 4];
assign wlast = write_beat == write_len;
assign wvalid = write_busy && !w_sent;
assign bready = write_busy && aw_sent && w_sent;

always @(posedge aclk) begin
    if (!aresetn) begin
        write_busy <= 1'b0;
        aw_sent <= 1'b0;
        w_sent <= 1'b0;
        write_addr <= 32'b0;
        write_data <= 128'b0;
        write_strb <= 16'b0;
        write_len <= 8'b0;
        write_beat <= 8'b0;
    end else begin
        if (write_accept) begin
            write_busy <= 1'b1;
            aw_sent <= 1'b0;
            w_sent <= 1'b0;
            write_addr <= dc_wr_addr;
            write_data <= dc_wr_data;
            write_strb <= dc_wr_strb;
            write_len <= dc_wr_len;
            write_beat <= 8'b0;
        end
        if (awvalid && awready)
            aw_sent <= 1'b1;
        if (wvalid && wready) begin
            if (wlast) w_sent <= 1'b1;
            else write_beat <= write_beat + 1'b1;
        end
        if (bvalid && bready)
            write_busy <= 1'b0;
    end
end
endmodule
