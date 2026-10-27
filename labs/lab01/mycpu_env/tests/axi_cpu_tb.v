`timescale 1ns/1ps
module axi_cpu_tb;
reg clk = 0;
always #5 clk = ~clk;
reg resetn = 0;
reg [7:0] cycle = 0;
always @(posedge clk) cycle <= cycle + 1'b1;
initial begin
    repeat (5) @(posedge clk);
    resetn = 1;
end

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
wire [3:0] wstrb;
wire wvalid;
wire wready;
reg bvalid = 0;
wire bready;
wire [31:0] debug_wb_pc;
wire [3:0] debug_wb_rf_we;
wire [4:0] debug_wb_rf_wnum;
wire [31:0] debug_wb_rf_wdata;

mycpu_top cpu(
    .aclk(clk), .aresetn(resetn),
    .arid(arid), .araddr(araddr), .arlen(arlen),
    .arvalid(arvalid), .arready(arready),
    .rid(rid), .rdata(rdata), .rresp(2'b0), .rlast(rlast),
    .rvalid(rvalid), .rready(rready),
    .awaddr(awaddr), .awvalid(awvalid), .awready(awready),
    .wdata(wdata), .wstrb(wstrb), .wvalid(wvalid), .wready(wready),
    .bid(4'd1), .bresp(2'b0), .bvalid(bvalid), .bready(bready),
    .debug_wb_pc(debug_wb_pc), .debug_wb_rf_we(debug_wb_rf_we),
    .debug_wb_rf_wnum(debug_wb_rf_wnum), .debug_wb_rf_wdata(debug_wb_rf_wdata)
);

reg [31:0] imem [0:15];
reg [31:0] dmem [0:15];
initial begin
    // addi.w r1,r0,5; st.w r1,r0,0; ld.w r2,r0,0; addi.w r3,r2,1
    imem[0] = 32'h02801401;
    imem[1] = 32'h29800001;
    imem[2] = 32'h28800002;
    imem[3] = 32'h02800443;
    // b +8 跳过下一条；取指响应有等待，错误路径不能写 r4。
    imem[4] = 32'h50000800;
    imem[5] = 32'h02818c04;
    imem[6] = 32'h02801c05;
    imem[7] = 32'h0281fc06;
    imem[8] = 32'h29000406;
    imem[9] = 32'h2a000407;
    dmem[0] = 32'b0;
end

reg read_pending = 0;
reg [2:0] read_wait = 0;
reg [3:0] read_id;
reg [31:0] read_addr;
reg [7:0] read_len;
reg [7:0] read_beat;
integer inst_line_reads = 0;
assign arready = !read_pending && cycle[0];
always @(posedge clk) begin
    if (!resetn) begin
        read_pending <= 0;
        rvalid <= 0;
    end else begin
        if (arvalid && arready) begin
            read_pending <= 1;
            read_wait <= 3;
            read_id <= arid;
            read_addr <= araddr;
            read_len <= arlen;
            read_beat <= 0;
            if (arid == 0) begin
                if (arlen != 3 || |araddr[3:0])
                    $fatal(1, "I-Cache must request aligned 4-beat line");
                inst_line_reads <= inst_line_reads + 1;
            end else if (arlen != 0) begin
                $fatal(1, "uncached data request must be one beat");
            end
        end
        if (read_pending && !rvalid) begin
            if (read_wait != 0) read_wait <= read_wait - 1'b1;
            else begin
                rid <= read_id;
                rdata <= read_addr[28] ?
                    imem[read_addr[5:2] + read_beat] :
                    dmem[read_addr[5:2] + read_beat];
                rlast <= read_beat == read_len;
                rvalid <= 1;
            end
        end
        if (rvalid && rready) begin
            rvalid <= 0;
            if (rlast) read_pending <= 0;
            else begin
                read_beat <= read_beat + 1'b1;
                read_wait <= 1;
            end
        end
    end
end

reg aw_seen = 0;
reg w_seen = 0;
reg [31:0] saved_awaddr;
reg [31:0] saved_wdata;
reg [3:0] saved_wstrb;
assign awready = !aw_seen && cycle[0];
assign wready = !w_seen && cycle[1];
integer lane;
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
            saved_wstrb <= wstrb;
            w_seen <= 1;
        end
        if (aw_seen && w_seen && !bvalid) begin
            for (lane = 0; lane < 4; lane = lane + 1)
                if (saved_wstrb[lane])
                    dmem[saved_awaddr[5:2]][lane*8 +: 8] <=
                        saved_wdata[lane*8 +: 8];
            bvalid <= 1;
        end
        if (bvalid && bready) begin
            bvalid <= 0;
            aw_seen <= 0;
            w_seen <= 0;
        end
    end
end

reg seen_r1 = 0;
reg seen_r2 = 0;
reg seen_r3 = 0;
reg seen_r5 = 0;
always @(posedge clk) begin
    if (resetn && |debug_wb_rf_we) begin
        if (debug_wb_rf_wnum == 1) begin
            if (debug_wb_rf_wdata !== 5) $fatal(1, "r1 mismatch");
            seen_r1 <= 1;
        end
        if (debug_wb_rf_wnum == 2) begin
            if (debug_wb_rf_wdata !== 5 || dmem[0] !== 5)
                $fatal(1, "load mismatch");
            seen_r2 <= 1;
        end
        if (debug_wb_rf_wnum == 3) begin
            if (!seen_r1 || !seen_r2 || debug_wb_rf_wdata !== 6)
                $fatal(1, "dependent add mismatch");
            seen_r3 <= 1;
        end
        if (debug_wb_rf_wnum == 4)
            $fatal(1, "wrong-path instruction committed");
        if (debug_wb_rf_wnum == 5) begin
            if (!seen_r3 || debug_wb_rf_wdata !== 7)
                $fatal(1, "branch target mismatch");
            seen_r5 <= 1;
        end
        if (debug_wb_rf_wnum == 7) begin
            if (!seen_r5 || debug_wb_rf_wdata !== 127 ||
                dmem[0] !== 32'h00007f05 || inst_line_reads != 3)
                $fatal(1, "byte store/load mismatch");
            $display("AXI CPU PASS");
            $finish;
        end
    end
end
initial begin
    repeat (500) @(posedge clk);
    $fatal(1, "AXI CPU timeout");
end
endmodule
