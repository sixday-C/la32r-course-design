`timescale 1ns/1ps
module axi_cpu_tb #(parameter WAYS = 1, parameter STORE_BUFFER = 1);
reg clk = 0;
always #5 clk = ~clk;
reg resetn = 0;
reg [31:0] cycle = 0;
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
wire [7:0] awlen;
wire awvalid;
wire awready;
wire [31:0] wdata;
wire [3:0] wstrb;
wire wlast;
wire wvalid;
wire wready;
reg bvalid = 0;
wire bready;
wire [31:0] debug_wb_pc;
wire [3:0] debug_wb_rf_we;
wire [4:0] debug_wb_rf_wnum;
wire [31:0] debug_wb_rf_wdata;

mycpu_top #(.CACHE_WAYS(WAYS), .STORE_BUFFER(STORE_BUFFER)) cpu(
    .aclk(clk), .aresetn(resetn),
    .arid(arid), .araddr(araddr), .arlen(arlen),
    .arvalid(arvalid), .arready(arready),
    .rid(rid), .rdata(rdata), .rresp(2'b0), .rlast(rlast),
    .rvalid(rvalid), .rready(rready),
    .awaddr(awaddr), .awlen(awlen),
    .awvalid(awvalid), .awready(awready),
    .wdata(wdata), .wstrb(wstrb), .wlast(wlast),
    .wvalid(wvalid), .wready(wready),
    .bid(4'd1), .bresp(2'b0), .bvalid(bvalid), .bready(bready),
    .debug_wb_pc(debug_wb_pc), .debug_wb_rf_we(debug_wb_rf_we),
    .debug_wb_rf_wnum(debug_wb_rf_wnum), .debug_wb_rf_wdata(debug_wb_rf_wdata)
);

reg [31:0] imem [0:31];
reg [31:0] dmem [0:527];
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
    imem[10] = 32'h02900008;
    imem[11] = 32'h28800109;
    // LED 寄存器地址 0xbfaf_f020；MMIO 必须绕过 D-Cache。
    imem[12] = 32'h157f5fea;
    imem[13] = 32'h0380814a;
    imem[14] = 32'h29800145;
    imem[15] = 32'h2880014b;
    imem[16] = 32'h29800105;
    imem[17] = 32'h06000509;
    imem[18] = 32'h2880010c;
    imem[19] = 32'h29800109;
    imem[20] = 32'h06000111;
    imem[21] = 32'h2880010e;
    imem[22] = 32'h0290010d;
    imem[23] = 32'h288001af;
    imem[24] = 32'h02800c10;
    imem[25] = 32'h02bffe10;
    imem[26] = 32'h5ffffe00;
    imem[27] = 32'h02802411;
    dmem[0] = 32'b0;
    dmem[1] = 32'b0;
    dmem[2] = 32'b0;
    dmem[3] = 32'b0;
    dmem[256] = 32'h1234;
    dmem[257] = 32'b0;
    dmem[258] = 32'b0;
    dmem[259] = 32'b0;
    dmem[512] = 32'habc;
    dmem[513] = 32'b0;
    dmem[514] = 32'b0;
    dmem[515] = 32'b0;
end

reg read_pending = 0;
reg [2:0] read_wait = 0;
reg [3:0] read_id;
reg [31:0] read_addr;
reg [7:0] read_len;
reg [7:0] read_beat;
integer inst_line_reads = 0;
reg [31:0] led_reg = 0;
integer mmio_writes = 0;
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
            end else if (arlen != 0 && arlen != 3) begin
                $fatal(1, "invalid data burst length");
            end
        end
        if (read_pending && !rvalid) begin
            if (read_wait != 0) read_wait <= read_wait - 1'b1;
            else begin
                rid <= read_id;
                rdata <= read_id == 0 ?
                    imem[read_addr[6:2] + read_beat] :
                    read_addr == 32'hbfaf_f020 ? led_reg :
                    dmem[read_addr[11:2] + read_beat];
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
reg [7:0] saved_awlen;
reg [31:0] saved_wdata [0:3];
reg [3:0] saved_wstrb [0:3];
reg [2:0] write_beats = 0;
assign awready = !aw_seen && cycle[0];
assign wready = !w_seen && cycle[1];
integer lane;
integer word_idx;
always @(posedge clk) begin
    if (!resetn) begin
        aw_seen <= 0;
        w_seen <= 0;
        bvalid <= 0;
    end else begin
        if (awvalid && awready) begin
            saved_awaddr <= awaddr;
            saved_awlen <= awlen;
            aw_seen <= 1;
        end
        if (wvalid && wready) begin
            saved_wdata[write_beats] <= wdata;
            saved_wstrb[write_beats] <= wstrb;
            write_beats <= write_beats + 1'b1;
            if (wlast) w_seen <= 1;
        end
        if (aw_seen && w_seen && !bvalid) begin
            if (write_beats != saved_awlen + 1)
                $fatal(1, "write beat count mismatch");
            if (saved_awaddr == 32'hbfaf_f020) begin
                if (saved_awlen != 0) $fatal(1, "MMIO write was cached");
                mmio_writes <= mmio_writes + 1;
                for (lane = 0; lane < 4; lane = lane + 1)
                    if (saved_wstrb[0][lane])
                        led_reg[lane*8 +: 8] <=
                            saved_wdata[0][lane*8 +: 8];
            end else for (word_idx = 0; word_idx < 4; word_idx = word_idx + 1)
                if (word_idx <= saved_awlen)
                    for (lane = 0; lane < 4; lane = lane + 1)
                        if (saved_wstrb[word_idx][lane])
                            dmem[saved_awaddr[11:2] + word_idx][lane*8 +: 8] <=
                                saved_wdata[word_idx][lane*8 +: 8];
            bvalid <= 1;
        end
        if (bvalid && bready) begin
            bvalid <= 0;
            aw_seen <= 0;
            w_seen <= 0;
            write_beats <= 0;
        end
    end
end

reg seen_r1 = 0;
reg seen_r2 = 0;
reg seen_r3 = 0;
reg seen_r5 = 0;
reg seen_r7 = 0;
integer branch_redirects = 0;
integer predicted_branches = 0;
always @(posedge clk) begin
    if (resetn && cpu.u_core.u_id.br_redirect &&
        cpu.u_core.u_id.ds_pc == 32'h1c000068)
        branch_redirects <= branch_redirects + 1;
    if (resetn && cpu.u_core.inst_req && cpu.u_core.inst_addr_ok &&
        cpu.u_core.inst_addr == 32'h1c000068 &&
        cpu.u_core.u_if.predict_hit)
        predicted_branches <= predicted_branches + 1;
end
always @(posedge clk) begin
    if (resetn && |debug_wb_rf_we) begin
        if (debug_wb_rf_wnum == 1) begin
            if (debug_wb_rf_wdata !== 5) $fatal(1, "r1 mismatch");
            seen_r1 <= 1;
        end
        if (debug_wb_rf_wnum == 2) begin
            if (debug_wb_rf_wdata !== 5)
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
                inst_line_reads < 3)
                $fatal(1, "byte store/load mismatch read=%h lines=%0d",
                       debug_wb_rf_wdata, inst_line_reads);
            seen_r7 <= 1;
        end
        if (debug_wb_rf_wnum == 9) begin
            if (!seen_r7 || debug_wb_rf_wdata !== 32'h1234 ||
                (WAYS == 1 && dmem[0] !== 32'h00007f05) ||
                (WAYS == 2 && dmem[0] !== 32'b0))
                $fatal(1, "dirty eviction mismatch");
        end
        if (debug_wb_rf_wnum == 11) begin
            if (debug_wb_rf_wdata !== 7 || led_reg !== 7 ||
                mmio_writes != 1 || inst_line_reads < 4)
                $fatal(1, "MMIO bypass mismatch read=%h led=%h writes=%0d lines=%0d",
                       debug_wb_rf_wdata, led_reg, mmio_writes,
                       inst_line_reads);
        end
        if (debug_wb_rf_wnum == 12) begin
            if (debug_wb_rf_wdata !== 7 || dmem[256] !== 7)
                $fatal(1, "index CACOP did not write back");
        end
        if (debug_wb_rf_wnum == 14) begin
            if (debug_wb_rf_wdata !== 32'h1234 ||
                dmem[256] !== 32'h1234)
                $fatal(1, "hit CACOP did not write back");
        end
        if (debug_wb_rf_wnum == 15) begin
            if (debug_wb_rf_wdata !== 32'habc ||
                dmem[0] !== 32'h00007f05)
                $fatal(1, "two-way dirty replacement mismatch");
        end
        if (debug_wb_rf_wnum == 17) begin
            if (debug_wb_rf_wdata !== 9 ||
                branch_redirects != 2 || predicted_branches < 1)
                $fatal(1, "branch prediction mismatch: redirects=%0d predicted=%0d",
                       branch_redirects, predicted_branches);
            $display("AXI CPU, CACHE AND PREDICTOR PASS (ways=%0d, store_buffer=%0d, cycles=%0d)",
                     WAYS, STORE_BUFFER, cycle);
            $finish;
        end
    end
end
initial begin
    repeat (500) @(posedge clk);
    $fatal(1, "AXI CPU timeout");
end
endmodule
