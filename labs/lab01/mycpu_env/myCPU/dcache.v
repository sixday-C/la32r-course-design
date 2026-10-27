// 64 行、每行 16 字节的直接映射数据 Cache；写回、写分配。
module dcache #(parameter WAYS = 2)(
    input  wire         clk,
    input  wire         resetn,
    input  wire         req,
    input  wire [3:0]   we,
    input  wire [31:0]  addr,
    input  wire [31:0]  wdata,
    output wire         addr_ok,
    output wire         data_ok,
    output wire [31:0]  rdata,
    output wire         rd_req,
    output wire [31:0]  rd_addr,
    output wire [7:0]   rd_len,
    input  wire         rd_ready,
    input  wire         ret_valid,
    input  wire         ret_last,
    input  wire [31:0]  ret_data,
    output wire         wr_req,
    output wire [31:0]  wr_addr,
    output wire [7:0]   wr_len,
    output wire [127:0] wr_data,
    output wire [15:0]  wr_strb,
    input  wire         wr_ready,
    input  wire         wr_done,
    input  wire         maint_req,
    input  wire [31:0]  maint_addr,
    input  wire [1:0]   maint_code,
    output wire         maint_ready,
    output wire         maint_done
);
localparam IDLE       = 4'd0;
localparam LOOKUP     = 4'd1;
localparam WB_REQ     = 4'd2;
localparam WB_WAIT    = 4'd3;
localparam REFILL_REQ = 4'd4;
localparam REFILL     = 4'd5;
localparam BYPASS_RD  = 4'd6;
localparam BYPASS_R   = 4'd7;
localparam BYPASS_WR  = 4'd8;
localparam BYPASS_W   = 4'd9;
localparam RESP       = 4'd10;

reg [3:0] state;
reg [31:0] saved_addr;
reg [31:0] saved_wdata;
reg [3:0] saved_we;
reg maintenance;
reg [1:0] saved_maint_code;
reg invalidate_after_wb;
reg selected_way;
reg [31:0] saved_rdata;
reg [1:0] beat;
reg [127:0] refill_line;
reg [127:0] line_data [0:127];
reg [21:0] line_tag [0:127];
reg [127:0] line_valid;
reg [127:0] line_dirty;
reg [63:0] replacement_way;
integer i;

wire [5:0] index = saved_addr[9:4];
wire [21:0] tag = saved_addr[31:10];
wire [1:0] word_index = saved_addr[3:2];
wire [6:0] way0_entry = {1'b0, index};
wire [6:0] way1_entry = {1'b1, index};
wire hit0 = line_valid[way0_entry] && line_tag[way0_entry] == tag;
wire hit1 = WAYS == 2 && line_valid[way1_entry] &&
            line_tag[way1_entry] == tag;
wire hit = hit0 || hit1;
wire hit_way = !hit0 && hit1;
wire victim_way = WAYS == 1 ? 1'b0 :
                  !line_valid[way0_entry] ? 1'b0 :
                  !line_valid[way1_entry] ? 1'b1 : replacement_way[index];
wire [6:0] hit_entry = {hit_way, index};
wire [6:0] selected_entry = {selected_way, index};
wire [6:0] indexed_entry = {WAYS == 2 && saved_addr[0], index};
wire [6:0] maint_entry = saved_maint_code == 2 ?
                         hit_entry : indexed_entry;
wire bypass = saved_addr[31:16] == 16'hbfaf;
wire [127:0] completed_line = {ret_data, refill_line[95:0]};

function [127:0] merge_store;
    input [127:0] old_line;
    input [1:0] word_offset;
    input [3:0] byte_we;
    input [31:0] new_data;
    integer lane;
    begin
        merge_store = old_line;
        for (lane = 0; lane < 4; lane = lane + 1)
            if (byte_we[lane])
                merge_store[(word_offset*4 + lane)*8 +: 8] =
                    new_data[lane*8 +: 8];
    end
endfunction

wire hit_response = state == LOOKUP && !maintenance && !bypass && hit;
wire accept_slot = state == IDLE || hit_response || state == RESP;
assign addr_ok = accept_slot && !maint_req;
assign data_ok = hit_response || (state == RESP && !maintenance);
assign maint_ready = accept_slot;
assign maint_done = state == RESP && maintenance;
assign rdata = hit_response ? line_data[hit_entry][word_index*32 +: 32] :
               saved_rdata;
assign rd_req = state == REFILL_REQ || state == BYPASS_RD;
assign rd_addr = state == BYPASS_RD ? saved_addr :
                 {saved_addr[31:4], 4'b0};
assign rd_len = state == BYPASS_RD ? 8'd0 : 8'd3;
assign wr_req = state == WB_REQ || state == BYPASS_WR;
assign wr_addr = state == BYPASS_WR ? saved_addr :
                 {line_tag[selected_entry], index, 4'b0};
assign wr_len = state == BYPASS_WR ? 8'd0 : 8'd3;
assign wr_data = state == BYPASS_WR ? {96'b0, saved_wdata} :
                 line_data[selected_entry];
assign wr_strb = state == BYPASS_WR ? {12'b0, saved_we} : 16'hffff;

always @(posedge clk) begin
    if (!resetn) begin
        state <= IDLE;
        saved_addr <= 32'b0;
        saved_wdata <= 32'b0;
        saved_we <= 4'b0;
        maintenance <= 1'b0;
        saved_maint_code <= 2'b0;
        invalidate_after_wb <= 1'b0;
        selected_way <= 1'b0;
        saved_rdata <= 32'b0;
        beat <= 2'b0;
        refill_line <= 128'b0;
        line_valid <= 128'b0;
        line_dirty <= 128'b0;
        replacement_way <= 64'b0;
        for (i = 0; i < 128; i = i + 1)
            line_tag[i] <= 22'b0;
    end else begin
        case (state)
            IDLE: if (maint_req) begin
                saved_addr <= maint_addr;
                saved_maint_code <= maint_code;
                maintenance <= 1'b1;
                state <= LOOKUP;
            end else if (req) begin
                saved_addr <= addr;
                saved_we <= we;
                saved_wdata <= wdata;
                maintenance <= 1'b0;
                state <= LOOKUP;
            end
            LOOKUP: begin
                if (maintenance) begin
                    // 0: Store Tag；1: 索引无效并写回；2: 命中无效并写回。
                    if (saved_maint_code == 0) begin
                        line_tag[indexed_entry] <= 22'b0;
                        line_valid[indexed_entry] <= 1'b0;
                        line_dirty[indexed_entry] <= 1'b0;
                        state <= RESP;
                    end else if ((saved_maint_code == 1 &&
                                  line_valid[indexed_entry]) ||
                                 (saved_maint_code == 2 && hit)) begin
                        selected_way <= maint_entry[6];
                        if (line_dirty[maint_entry]) begin
                            invalidate_after_wb <= 1'b1;
                            state <= WB_REQ;
                        end else begin
                            line_valid[maint_entry] <= 1'b0;
                            state <= RESP;
                        end
                    end else begin
                        state <= RESP;
                    end
                end else if (bypass) begin
                    state <= (|saved_we) ? BYPASS_WR : BYPASS_RD;
                end else if (hit) begin
                    replacement_way[index] <= !hit_way;
                    if (|saved_we) begin
                        line_data[hit_entry] <= merge_store(
                            line_data[hit_entry], word_index,
                            saved_we, saved_wdata);
                        line_dirty[hit_entry] <= 1'b1;
                    end
                    // 命中结果与下一条请求可在同一个时钟沿交接。
                    if (maint_req) begin
                        saved_addr <= maint_addr;
                        saved_maint_code <= maint_code;
                        maintenance <= 1'b1;
                        state <= LOOKUP;
                    end else if (req) begin
                        saved_addr <= addr;
                        saved_we <= we;
                        saved_wdata <= wdata;
                        maintenance <= 1'b0;
                        state <= LOOKUP;
                    end else begin
                        state <= IDLE;
                    end
                end else begin
                    selected_way <= victim_way;
                    if (line_valid[{victim_way, index}] &&
                        line_dirty[{victim_way, index}]) begin
                        invalidate_after_wb <= 1'b0;
                        state <= WB_REQ;
                    end else begin
                        state <= REFILL_REQ;
                    end
                end
            end
            WB_REQ: if (wr_ready) state <= WB_WAIT;
            WB_WAIT: if (wr_done) begin
                line_dirty[selected_entry] <= 1'b0;
                if (invalidate_after_wb) begin
                    line_valid[selected_entry] <= 1'b0;
                    state <= RESP;
                end else begin
                    state <= REFILL_REQ;
                end
            end
            REFILL_REQ: if (rd_ready) begin
                beat <= 2'b0;
                state <= REFILL;
            end
            REFILL: if (ret_valid) begin
                refill_line[beat*32 +: 32] <= ret_data;
                if (ret_last) begin
                    line_data[selected_entry] <= merge_store(
                        completed_line, word_index, saved_we, saved_wdata);
                    line_tag[selected_entry] <= tag;
                    line_valid[selected_entry] <= 1'b1;
                    line_dirty[selected_entry] <= |saved_we;
                    replacement_way[index] <= !selected_way;
                    saved_rdata <= completed_line[word_index*32 +: 32];
                    state <= RESP;
                end else begin
                    beat <= beat + 1'b1;
                end
            end
            BYPASS_RD: if (rd_ready) state <= BYPASS_R;
            BYPASS_R: if (ret_valid && ret_last) begin
                saved_rdata <= ret_data;
                state <= RESP;
            end
            BYPASS_WR: if (wr_ready) state <= BYPASS_W;
            BYPASS_W: if (wr_done) state <= RESP;
            RESP: begin
                if (maint_req) begin
                    saved_addr <= maint_addr;
                    saved_maint_code <= maint_code;
                    maintenance <= 1'b1;
                    state <= LOOKUP;
                end else if (req) begin
                    saved_addr <= addr;
                    saved_we <= we;
                    saved_wdata <= wdata;
                    maintenance <= 1'b0;
                    state <= LOOKUP;
                end else begin
                    state <= IDLE;
                end
            end
            default: state <= IDLE;
        endcase
    end
end
endmodule
