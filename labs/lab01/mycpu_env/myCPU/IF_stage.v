`include "mycpu_head.v"
module IF_stage(
    input  wire                        clk,
    input  wire                        reset,
    input  wire                        flush,
    input  wire [31:0]                 flush_pc,
    input  wire                        ds_allowin,
    input  wire [`BR_BUS_WD-1:0]       br_bus,
    output wire                        fs_to_ds_valid,
    output wire [`FS_TO_DS_BUS_WD-1:0] fs_to_ds_bus,
    output wire                        inst_req,
    output wire [31:0]                 inst_addr,
    input  wire                        inst_addr_ok,
    input  wire                        inst_data_ok,
    input  wire [31:0]                 inst_rdata
);

wire br_update;
wire br_taken;
wire br_redirect;
wire [31:0] br_pc;
wire [31:0] br_next_pc;
assign {br_update, br_taken, br_redirect, br_pc, br_next_pc} = br_bus;

reg [31:0] next_pc;
reg [31:0] pending_pc;
reg [31:0] pending_pred_next;
reg pending;
reg discard_pending;
reg fs_valid;
reg fs_adef;
reg [31:0] fs_pc;
reg [31:0] fs_inst;
reg [31:0] fs_pred_next;

// 64 项 BTB，每项一只两位饱和计数器；只记录实际跳转过的地址。
reg [63:0] btb_valid;
reg [23:0] btb_tag [0:63];
reg [31:0] btb_target [0:63];
reg [1:0] bht [0:63];
integer i;
wire [5:0] predict_index = next_pc[7:2];
wire predict_hit = btb_valid[predict_index] &&
                   btb_tag[predict_index] == next_pc[31:8] &&
                   bht[predict_index][1];
wire [31:0] predicted_next = predict_hit ? btb_target[predict_index] :
                             next_pc + 32'd4;
wire [5:0] update_index = br_pc[7:2];
wire update_hit = btb_valid[update_index] &&
                  btb_tag[update_index] == br_pc[31:8];

assign fs_to_ds_valid = fs_valid;
assign fs_to_ds_bus = {fs_adef, fs_inst, fs_pc, fs_pred_next};
assign inst_req = !reset && !flush && !br_redirect &&
                  !pending && !fs_valid && !(|next_pc[1:0]);
assign inst_addr = next_pc;

// 一次只发一笔取指。跳转后旧请求仍要等响应，但结果必须丢弃。
always @(posedge clk) begin
    if (reset) begin
        next_pc <= 32'h1c000000;
        pending <= 1'b0;
        discard_pending <= 1'b0;
        fs_valid <= 1'b0;
        fs_adef <= 1'b0;
        fs_pc <= 32'b0;
        fs_inst <= 32'b0;
        pending_pc <= 32'b0;
        pending_pred_next <= 32'b0;
        fs_pred_next <= 32'b0;
        btb_valid <= 64'b0;
        for (i = 0; i < 64; i = i + 1)
            bht[i] <= 2'b00;
    end else begin
        if (br_update) begin
            if (br_taken) begin
                btb_valid[update_index] <= 1'b1;
                btb_tag[update_index] <= br_pc[31:8];
                btb_target[update_index] <= br_next_pc;
                bht[update_index] <= !update_hit ? 2'b10 :
                    bht[update_index] == 2'b11 ? 2'b11 :
                    bht[update_index] + 1'b1;
            end else if (update_hit && bht[update_index] != 2'b00) begin
                bht[update_index] <= bht[update_index] - 1'b1;
            end
        end

        if (fs_valid && ds_allowin)
            fs_valid <= 1'b0;

        if (pending && inst_data_ok) begin
            pending <= 1'b0;
            discard_pending <= 1'b0;
            if (!discard_pending && !flush && !br_redirect) begin
                fs_valid <= 1'b1;
                fs_adef <= 1'b0;
                fs_pc <= pending_pc;
                fs_inst <= inst_rdata;
                fs_pred_next <= pending_pred_next;
            end
        end

        if (inst_req && inst_addr_ok) begin
            pending <= 1'b1;
            pending_pc <= next_pc;
            pending_pred_next <= predicted_next;
            next_pc <= predicted_next;
        end
        if (!pending && !fs_valid && |next_pc[1:0] &&
            !flush && !br_redirect) begin
            fs_valid <= 1'b1;
            fs_adef <= 1'b1;
            fs_pc <= next_pc;
            fs_inst <= 32'b0;
            fs_pred_next <= next_pc + 32'd4;
            next_pc <= next_pc + 32'd4;
        end

        if (br_redirect || flush) begin
            next_pc <= flush ? flush_pc : br_next_pc;
            fs_valid <= 1'b0;
            if (pending && !inst_data_ok)
                discard_pending <= 1'b1;
        end
    end
end
endmodule
