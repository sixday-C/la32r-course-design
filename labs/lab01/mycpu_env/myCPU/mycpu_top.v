// AXI 顶层。读 ID 0 给取指，读 ID 1 给访存；CPU 每个端口最多一笔未完成请求。
module mycpu_top #(
    parameter CACHE_WAYS = 2,
    parameter STORE_BUFFER = 1,
    parameter FETCH_QUEUE_DEPTH = 4,
    parameter ICACHE_PREFETCH = 1
)(
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
    output wire [31:0] debug_wb_rf_wdata,
    // SoC 可用这些脉冲统计性能；课程 AXI 引脚不受影响。
    output wire [6:0]  perf_events
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
wire dc_cpu_req;
wire [3:0] dc_cpu_we;
wire [31:0] dc_cpu_addr;
wire [31:0] dc_cpu_wdata;
wire dc_cpu_addr_ok;
wire dc_cpu_data_ok;
wire [31:0] dc_cpu_rdata;
wire stores_drained;
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
wire cache_cmd_req;
wire [4:0] cache_cmd_code;
wire [31:0] cache_cmd_addr;
wire cache_cmd_ready;
wire cache_cmd_done;
wire ic_maint_ready;
wire ic_maint_done;
wire dc_maint_ready;
wire dc_maint_done;
wire cache_cmd_issue = cache_cmd_req && stores_drained;
wire ic_maint_req = cache_cmd_issue && cache_cmd_code[2:0] == 3'd0;
wire dc_maint_req = cache_cmd_issue && cache_cmd_code[2:0] == 3'd1;
reg unsupported_done;
assign cache_cmd_ready = !stores_drained ? 1'b0 :
                         ic_maint_req ? ic_maint_ready :
                         dc_maint_req ? dc_maint_ready : 1'b1;
assign cache_cmd_done = ic_maint_done || dc_maint_done || unsupported_done;
always @(posedge aclk) begin
    if (!aresetn) unsupported_done <= 1'b0;
    else unsupported_done <= cache_cmd_issue &&
         cache_cmd_code[2:0] != 3'd0 && cache_cmd_code[2:0] != 3'd1;
end

mycpu_core #(.FETCH_QUEUE_DEPTH(FETCH_QUEUE_DEPTH)) u_core(
    .clk(aclk), .resetn(aresetn), .hw_int_in(8'b0),
    .inst_req(inst_req), .inst_addr(inst_addr),
    .inst_addr_ok(inst_addr_ok), .inst_data_ok(inst_data_ok),
    .inst_rdata(inst_rdata),
    .data_req(data_req), .data_we(data_we),
    .data_addr(data_addr), .data_wdata(data_wdata),
    .data_addr_ok(data_addr_ok), .data_data_ok(data_data_ok),
    .data_rdata(data_rdata),
    .cache_cmd_req(cache_cmd_req), .cache_cmd_code(cache_cmd_code),
    .cache_cmd_addr(cache_cmd_addr),
    .cache_cmd_ready(cache_cmd_ready), .cache_cmd_done(cache_cmd_done),
    .debug_wb_pc(debug_wb_pc), .debug_wb_rf_we(debug_wb_rf_we),
    .debug_wb_rf_wnum(debug_wb_rf_wnum),
    .debug_wb_rf_wdata(debug_wb_rf_wdata),
    .perf_retire(perf_events[0]),
    .perf_branch(perf_events[5]),
    .perf_branch_miss(perf_events[6])
);

icache #(.WAYS(CACHE_WAYS), .PREFETCH(ICACHE_PREFETCH)) u_icache(
    .clk(aclk), .resetn(aresetn),
    .req(inst_req), .addr(inst_addr),
    .addr_ok(inst_addr_ok), .data_ok(inst_data_ok), .rdata(inst_rdata),
    .rd_req(ic_rd_req), .rd_addr(ic_rd_addr),
    .rd_ready(ic_rd_ready),
    .ret_valid(rvalid && rready && rid == 4'd0),
    .ret_last(rlast), .ret_data(rdata),
    .maint_req(ic_maint_req), .maint_addr(cache_cmd_addr),
    .maint_code(cache_cmd_code[4:3]),
    .maint_ready(ic_maint_ready), .maint_done(ic_maint_done),
    .perf_hit(perf_events[1]), .perf_miss(perf_events[2])
);

store_buffer #(.ENABLE(STORE_BUFFER)) u_store_buffer(
    .clk(aclk), .resetn(aresetn),
    .cpu_req(data_req), .cpu_we(data_we),
    .cpu_addr(data_addr), .cpu_wdata(data_wdata),
    .cpu_addr_ok(data_addr_ok), .cpu_data_ok(data_data_ok),
    .cpu_rdata(data_rdata),
    .dc_req(dc_cpu_req), .dc_we(dc_cpu_we),
    .dc_addr(dc_cpu_addr), .dc_wdata(dc_cpu_wdata),
    .dc_addr_ok(dc_cpu_addr_ok), .dc_data_ok(dc_cpu_data_ok),
    .dc_rdata(dc_cpu_rdata), .empty(stores_drained)
);

dcache #(.WAYS(CACHE_WAYS)) u_dcache(
    .clk(aclk), .resetn(aresetn),
    .req(dc_cpu_req), .we(dc_cpu_we),
    .addr(dc_cpu_addr), .wdata(dc_cpu_wdata),
    .addr_ok(dc_cpu_addr_ok), .data_ok(dc_cpu_data_ok),
    .rdata(dc_cpu_rdata),
    .rd_req(dc_rd_req), .rd_addr(dc_rd_addr), .rd_len(dc_rd_len),
    .rd_ready(dc_rd_ready),
    .ret_valid(rvalid && rready && rid == 4'd1),
    .ret_last(rlast), .ret_data(rdata),
    .wr_req(dc_wr_req), .wr_addr(dc_wr_addr), .wr_len(dc_wr_len),
    .wr_data(dc_wr_data), .wr_strb(dc_wr_strb),
    .wr_ready(dc_wr_ready), .wr_done(dc_wr_done),
    .maint_req(dc_maint_req), .maint_addr(cache_cmd_addr),
    .maint_code(cache_cmd_code[4:3]),
    .maint_ready(dc_maint_ready), .maint_done(dc_maint_done),
    .perf_hit(perf_events[3]), .perf_miss(perf_events[4])
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
