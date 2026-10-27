// 64 行、每行 16 字节的直接映射指令 Cache。
module icache(
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
    input  wire [31:0] ret_data
);
localparam IDLE = 3'd0;
localparam LOOKUP = 3'd1;
localparam READ_ADDR = 3'd2;
localparam REFILL = 3'd3;
localparam RESP = 3'd4;

reg [2:0] state;
reg [31:0] saved_addr;
reg [31:0] saved_data;
reg [1:0] beat;
reg [127:0] refill_line;
reg [127:0] line_data [0:63];
reg [21:0] line_tag [0:63];
reg [63:0] line_valid;
integer i;

wire [5:0] index = saved_addr[9:4];
wire [21:0] tag = saved_addr[31:10];
wire [1:0] word_index = saved_addr[3:2];
wire hit = line_valid[index] && line_tag[index] == tag;

assign addr_ok = state == IDLE;
assign data_ok = state == RESP;
assign rdata = saved_data;
assign rd_req = state == READ_ADDR;
assign rd_addr = {saved_addr[31:4], 4'b0};

always @(posedge clk) begin
    if (!resetn) begin
        state <= IDLE;
        line_valid <= 64'b0;
        saved_addr <= 32'b0;
        saved_data <= 32'b0;
        beat <= 2'b0;
        refill_line <= 128'b0;
        for (i = 0; i < 64; i = i + 1)
            line_tag[i] <= 22'b0;
    end else begin
        case (state)
            IDLE: if (req) begin
                saved_addr <= addr;
                state <= LOOKUP;
            end
            LOOKUP: begin
                if (hit) begin
                    saved_data <= line_data[index][word_index*32 +: 32];
                    state <= RESP;
                end else begin
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
                    line_data[index] <= {ret_data, refill_line[95:0]};
                    line_tag[index] <= tag;
                    line_valid[index] <= 1'b1;
                    state <= RESP;
                end else begin
                    beat <= beat + 1'b1;
                end
            end
            RESP: state <= IDLE;
            default: state <= IDLE;
        endcase
    end
end
endmodule
