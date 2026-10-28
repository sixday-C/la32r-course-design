// 演示用 SoC：AXI CPU、片上 RAM 和课程 confreg 的外设地址布局。
module soc_demo_top #(
    parameter ROM_FILE = "labs/lab01/mycpu_env/examples/peripherals/peripheral_demo.hex",
    parameter ROM_WORDS = 11,
    parameter integer UART_CLKS_PER_BIT = 217
)(
    input  wire        clk,
    input  wire        resetn,
    input  wire [7:0]  switch,
    input  wire [15:0] buttons,
    input  wire        uart_rxd,
    output wire        uart_txd,
    output reg  [15:0] led,
    output reg  [31:0] num_data
);
wire [3:0] arid;
wire [31:0] araddr;
wire [7:0] arlen;
wire arvalid;
wire arready;
wire [3:0] rid;
wire [31:0] rdata;
wire rlast;
wire rvalid;
wire rready;
wire [3:0] awid;
wire [31:0] awaddr;
wire [7:0] awlen;
wire awvalid;
wire awready;
wire [31:0] wdata;
wire [3:0] wstrb;
wire wlast;
wire wvalid;
wire wready;
wire [3:0] bid;
wire bvalid;
wire bready;
wire [6:0] perf_events;

mycpu_top u_cpu(
    .aclk(clk), .aresetn(resetn),
    .arid(arid), .araddr(araddr), .arlen(arlen),
    .arsize(), .arburst(), .arlock(), .arcache(), .arprot(),
    .arvalid(arvalid), .arready(arready),
    .rid(rid), .rdata(rdata), .rresp(2'b0), .rlast(rlast),
    .rvalid(rvalid), .rready(rready),
    .awid(awid), .awaddr(awaddr), .awlen(awlen),
    .awsize(), .awburst(), .awlock(), .awcache(), .awprot(),
    .awvalid(awvalid), .awready(awready),
    .wid(), .wdata(wdata), .wstrb(wstrb), .wlast(wlast),
    .wvalid(wvalid), .wready(wready),
    .bid(bid), .bresp(2'b0), .bvalid(bvalid), .bready(bready),
    .debug_wb_pc(), .debug_wb_rf_we(),
    .debug_wb_rf_wnum(), .debug_wb_rf_wdata(),
    .perf_events(perf_events)
);

reg [31:0] inst_rom [0:255];
reg [31:0] data_ram [0:1023];
integer i;
initial begin
    // 指令 ROM 只由程序文件初始化；先整表清零会让综合结果丢掉程序。
    for (i = 0; i < 1024; i = i + 1) data_ram[i] = 32'b0;
    $readmemh(ROM_FILE, inst_rom, 0, ROM_WORDS - 1);
end

reg write_busy;
reg [3:0] write_id;
reg [31:0] write_addr;
reg [7:0] write_len;
reg [7:0] write_beat;
reg write_response;
wire [31:0] current_write_addr = write_addr + {22'b0, write_beat, 2'b0};

reg read_busy;
reg [3:0] read_id;
reg [31:0] read_addr;
reg [7:0] read_len;
reg [7:0] read_beat;
assign arready = !read_busy;
assign rid = read_id;
assign rvalid = read_busy;
assign rlast = read_beat == read_len;
wire [31:0] current_read_addr = read_addr + {22'b0, read_beat, 2'b0};
wire [7:0] uart_rx_data;
wire uart_rx_valid;
wire uart_tx_ready;
wire uart_read_fire = rvalid && rready && read_id != 0 &&
                      current_read_addr[31:16] == 16'hbfaf &&
                      current_read_addr[15:0] == 16'hff10;
wire uart_write_fire = wvalid && wready &&
                       current_write_addr[31:16] == 16'hbfaf &&
                       current_write_addr[15:0] == 16'hff10;
wire perf_control_write = wvalid && wready && wstrb[0] &&
                          current_write_addr == 32'hbfaffe00;
wire [31:0] perf_rdata;
perf_monitor u_perf(
    .clk(clk), .resetn(resetn), .events(perf_events),
    .control_write(perf_control_write), .control_wdata(wdata),
    .read_index(current_read_addr[5:2]), .read_data(perf_rdata)
);
uart_mmio #(.CLKS_PER_BIT(UART_CLKS_PER_BIT)) u_uart(
    .clk(clk), .resetn(resetn), .rx(uart_rxd), .tx(uart_txd),
    .tx_write(uart_write_fire), .tx_data(wdata[7:0]), .tx_ready(uart_tx_ready),
    .rx_read(uart_read_fire), .rx_data(uart_rx_data), .rx_valid(uart_rx_valid)
);
// 程序文件只覆盖实际指令；越过程序末尾时返回 0（非法指令）。
assign rdata = read_id == 0 ?
               current_read_addr[9:2] < ROM_WORDS ?
               inst_rom[current_read_addr[9:2]] : 32'b0 :
               current_read_addr[31:16] == 16'hbfaf ?
               current_read_addr[15:6] == 10'h3f8 ? perf_rdata :
               current_read_addr[15:0] == 16'hf020 ? {16'b0, led} :
               current_read_addr[15:0] == 16'hf050 ? num_data :
               current_read_addr[15:0] == 16'hf060 ? {24'b0, switch} :
               current_read_addr[15:0] == 16'hf070 ? {16'b0, buttons} :
               current_read_addr[15:0] == 16'hff10 ? {24'b0, uart_rx_data} :
               current_read_addr[15:0] == 16'hff14 ? {30'b0, uart_tx_ready, uart_rx_valid} :
               32'b0 : data_ram[current_read_addr[11:2]];
always @(posedge clk) begin
    if (!resetn) begin
        read_busy <= 1'b0;
        read_id <= 4'b0;
        read_addr <= 32'b0;
        read_len <= 8'b0;
        read_beat <= 8'b0;
    end else begin
        if (arvalid && arready) begin
            read_busy <= 1'b1;
            read_id <= arid;
            read_addr <= araddr;
            read_len <= arlen;
            read_beat <= 8'b0;
        end
        if (rvalid && rready) begin
            if (rlast) read_busy <= 1'b0;
            else read_beat <= read_beat + 1'b1;
        end
    end
end

assign awready = !write_busy && !write_response;
wire uart_data_write = current_write_addr[31:16] == 16'hbfaf &&
                       current_write_addr[15:0] == 16'hff10;
assign wready = write_busy && (!uart_data_write || uart_tx_ready);
assign bid = write_id;
assign bvalid = write_response;
integer lane;
always @(posedge clk) begin
    if (!resetn) begin
        write_busy <= 1'b0;
        write_response <= 1'b0;
        write_id <= 4'b0;
        write_addr <= 32'b0;
        write_len <= 8'b0;
        write_beat <= 8'b0;
        led <= 16'b0;
        num_data <= 32'b0;
    end else begin
        if (awvalid && awready) begin
            write_busy <= 1'b1;
            write_id <= awid;
            write_addr <= awaddr;
            write_len <= awlen;
            write_beat <= 8'b0;
        end
        if (wvalid && wready) begin
            if (current_write_addr[31:16] == 16'hbfaf) begin
                if (current_write_addr[15:0] == 16'hf020)
                    led <= wdata[15:0];
                if (current_write_addr[15:0] == 16'hf050)
                    num_data <= wdata;
            end else begin
                for (lane = 0; lane < 4; lane = lane + 1)
                    if (wstrb[lane])
                        data_ram[current_write_addr[11:2]][lane*8 +: 8] <=
                            wdata[lane*8 +: 8];
            end
            if (wlast) begin
                write_busy <= 1'b0;
                write_response <= 1'b1;
            end else begin
                write_beat <= write_beat + 1'b1;
            end
        end
        if (bvalid && bready)
            write_response <= 1'b0;
    end
end
endmodule
