// 演示用 SoC：AXI CPU、片上 RAM 和课程 confreg 的外设地址布局。
module soc_demo_top #(
    parameter ROM_FILE = "labs/lab01/mycpu_env/examples/peripherals/peripheral_demo.hex"
)(
    input  wire        clk,
    input  wire        resetn,
    input  wire [7:0]  switch,
    input  wire [15:0] buttons,
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
    .debug_wb_rf_wnum(), .debug_wb_rf_wdata()
);

reg [31:0] inst_rom [0:255];
reg [31:0] data_ram [0:1023];
integer i;
initial begin
    for (i = 0; i < 256; i = i + 1) inst_rom[i] = 32'b0;
    for (i = 0; i < 1024; i = i + 1) data_ram[i] = 32'b0;
    $readmemh(ROM_FILE, inst_rom, 0, 10);
end

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
assign rdata = read_id == 0 ? inst_rom[current_read_addr[9:2]] :
               current_read_addr[31:16] == 16'hbfaf ?
               current_read_addr[15:0] == 16'hf020 ? {16'b0, led} :
               current_read_addr[15:0] == 16'hf050 ? num_data :
               current_read_addr[15:0] == 16'hf060 ? {24'b0, switch} :
               current_read_addr[15:0] == 16'hf070 ? {16'b0, buttons} :
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

reg write_busy;
reg [3:0] write_id;
reg [31:0] write_addr;
reg [7:0] write_len;
reg [7:0] write_beat;
reg write_response;
assign awready = !write_busy && !write_response;
assign wready = write_busy;
assign bid = write_id;
assign bvalid = write_response;
wire [31:0] current_write_addr = write_addr + {22'b0, write_beat, 2'b0};
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
