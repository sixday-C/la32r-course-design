// 64 行、每行 16 字节的直接映射指令 Cache。
module icache #(parameter WAYS = 2)(
    input  wire        clk,
    input  wire        resetn,
    input  wire        req,
    input  wire [31:0] addr,
    output wire        addr_ok,
    output wire        data_ok,
    output wire [31:0] rdata,
    output wire        rd_req,
    output wire [31:0] rd_addr,
    input  wire        rd_ready,
    input  wire        ret_valid,
    input  wire        ret_last,
    input  wire [31:0] ret_data,
    input  wire        maint_req,
    input  wire [31:0] maint_addr,
    input  wire [1:0]  maint_code,
    output wire        maint_ready,
    output wire        maint_done
);
localparam IDLE = 3'd0;
localparam LOOKUP = 3'd1;
localparam READ_ADDR = 3'd2;
localparam REFILL = 3'd3;
localparam RESP = 3'd4;
localparam MAINT = 3'd5;
localparam MAINT_RESP = 3'd6;

reg [2:0] state;
reg [31:0] saved_addr;
reg [31:0] saved_data;
reg [1:0] saved_maint_code;
reg [1:0] beat;
reg [127:0] refill_line;
reg [127:0] line_data [0:127];
reg [21:0] line_tag [0:127];
reg [127:0] line_valid;
reg [63:0] replacement_way;
reg selected_way;
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

assign addr_ok = state == IDLE && !maint_req;
assign data_ok = state == RESP;
assign maint_ready = state == IDLE;
assign maint_done = state == MAINT_RESP;
assign rdata = saved_data;
assign rd_req = state == READ_ADDR;
assign rd_addr = {saved_addr[31:4], 4'b0};

always @(posedge clk) begin
    if (!resetn) begin
        state <= IDLE;
        line_valid <= 128'b0;
        replacement_way <= 64'b0;
        selected_way <= 1'b0;
        saved_addr <= 32'b0;
        saved_data <= 32'b0;
        saved_maint_code <= 2'b0;
        beat <= 2'b0;
        refill_line <= 128'b0;
        for (i = 0; i < 128; i = i + 1)
            line_tag[i] <= 22'b0;
    end else begin
        case (state)
            IDLE: if (maint_req) begin
                saved_addr <= maint_addr;
                saved_maint_code <= maint_code;
                state <= MAINT;
            end else if (req) begin
                saved_addr <= addr;
                state <= LOOKUP;
            end
            LOOKUP: begin
                if (hit) begin
                    saved_data <= line_data[hit_entry][word_index*32 +: 32];
                    replacement_way[index] <= !hit_way;
                    state <= RESP;
                end else begin
                    selected_way <= victim_way;
                    state <= READ_ADDR;
                end
            end
            READ_ADDR: if (rd_ready) begin
                beat <= 2'b0;
                state <= REFILL;
            end
            REFILL: if (ret_valid) begin
                refill_line[beat*32 +: 32] <= ret_data;
                if (beat == word_index)
                    saved_data <= ret_data;
                if (ret_last) begin
                    // 最后一个 beat 同拍写入，避免使用尚未更新的 refill_line。
                    line_data[selected_entry] <= {ret_data, refill_line[95:0]};
                    line_tag[selected_entry] <= tag;
                    line_valid[selected_entry] <= 1'b1;
                    replacement_way[index] <= !selected_way;
                    state <= RESP;
                end else begin
                    beat <= beat + 1'b1;
                end
            end
            RESP: state <= IDLE;
            MAINT: begin
                // 0: Store Tag；1: 索引无效；2: 命中无效。
                if (saved_maint_code == 0) begin
                    line_valid[indexed_entry] <= 1'b0;
                    line_tag[indexed_entry] <= 22'b0;
                end else if (saved_maint_code == 1 ||
                             (saved_maint_code == 2 && hit)) begin
                    line_valid[saved_maint_code == 2 ?
                               hit_entry : indexed_entry] <= 1'b0;
                end
                state <= MAINT_RESP;
            end
            MAINT_RESP: state <= IDLE;
            default: state <= IDLE;
        endcase
    end
end
endmodule
