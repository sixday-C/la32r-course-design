`include "mycpu_head.v"
module IF_stage #(
    parameter FETCH_QUEUE_DEPTH = 1,
    parameter PREDICTOR_MODE = 0
)(
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
wire predict_hit;
generate if (FETCH_QUEUE_DEPTH == 1) begin: legacy

wire br_update;
wire br_taken;
wire br_redirect;
wire [31:0] br_pc;
wire [31:0] br_next_pc;
wire [5:0] br_pred_index;
assign {br_update, br_taken, br_redirect, br_pc,
        br_next_pc, br_pred_index} = br_bus;

reg [31:0] next_pc;
reg [31:0] pending_pc;
reg [31:0] pending_pred_next;
reg [5:0] pending_pred_index;
reg pending;
reg discard_pending;
reg fs_valid;
reg fs_adef;
reg [31:0] fs_pc;
reg [31:0] fs_inst;
reg [31:0] fs_pred_next;
reg [5:0] fs_pred_index;

// 64 项 BTB，每项一只两位饱和计数器；只记录实际跳转过的地址。
reg [63:0] btb_valid;
reg [23:0] btb_tag [0:63];
reg [31:0] btb_target [0:63];
reg [1:0] bht [0:63];
reg [5:0] global_history;
integer i;
wire [5:0] btb_index = next_pc[7:2];
wire [5:0] predict_index = PREDICTOR_MODE ?
                           btb_index ^ global_history : btb_index;
assign predict_hit = btb_valid[btb_index] &&
                   btb_tag[btb_index] == next_pc[31:8] &&
                   bht[predict_index][1];
wire [31:0] predicted_next = predict_hit ? btb_target[btb_index] :
                             next_pc + 32'd4;
wire [5:0] update_index = br_pc[7:2];
wire [5:0] update_direction = PREDICTOR_MODE ?
                              br_pred_index : update_index;
wire update_hit = btb_valid[update_index] &&
                  btb_tag[update_index] == br_pc[31:8];

assign fs_to_ds_valid = fs_valid;
assign fs_to_ds_bus = {fs_adef, fs_inst, fs_pc,
                       fs_pred_next, fs_pred_index};
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
        fs_pred_index <= 0;
        pending_pred_index <= 0;
        global_history <= 0;
        btb_valid <= 64'b0;
        for (i = 0; i < 64; i = i + 1)
            bht[i] <= 2'b00;
    end else begin
        if (br_update) begin
            global_history <= {global_history[4:0], br_taken};
            if (br_taken) begin
                btb_valid[update_index] <= 1'b1;
                btb_tag[update_index] <= br_pc[31:8];
                btb_target[update_index] <= br_next_pc;
                bht[update_direction] <= !update_hit ? 2'b10 :
                    bht[update_direction] == 2'b11 ? 2'b11 :
                    bht[update_direction] + 1'b1;
            end else if (update_hit && bht[update_direction] != 2'b00) begin
                bht[update_direction] <= bht[update_direction] - 1'b1;
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
                fs_pred_index <= pending_pred_index;
            end
        end

        if (inst_req && inst_addr_ok) begin
            pending <= 1'b1;
            pending_pc <= next_pc;
            pending_pred_next <= predicted_next;
            pending_pred_index <= predict_index;
            next_pc <= predicted_next;
        end
        if (!pending && !fs_valid && |next_pc[1:0] &&
            !flush && !br_redirect) begin
            fs_valid <= 1'b1;
            fs_adef <= 1'b1;
            fs_pc <= next_pc;
            fs_inst <= 32'b0;
            fs_pred_next <= next_pc + 32'd4;
            fs_pred_index <= predict_index;
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
end else begin: queued
wire br_update;
wire br_taken;
wire br_redirect;
wire [31:0] br_pc;
wire [31:0] br_next_pc;
wire [5:0] br_pred_index;
assign {br_update, br_taken, br_redirect, br_pc,
        br_next_pc, br_pred_index} = br_bus;

reg [31:0] next_pc;
reg [31:0] pending_pc;
reg [31:0] pending_pred_next;
reg [5:0] pending_pred_index;
reg pending;
reg discard_pending;
reg [2:0] count;
reg [1:0] head;
reg [1:0] tail;
reg [31:0] q_pc [0:3];
reg [31:0] q_inst [0:3];
reg [31:0] q_pred_next [0:3];
reg [5:0] q_pred_index [0:3];
reg q_adef [0:3];

reg [63:0] btb_valid;
reg [23:0] btb_tag [0:63];
reg [31:0] btb_target [0:63];
reg [1:0] bht [0:63];
reg [5:0] global_history;
integer i;
wire [5:0] btb_index = next_pc[7:2];
wire [5:0] predict_index = PREDICTOR_MODE ?
                           btb_index ^ global_history : btb_index;
assign predict_hit = btb_valid[btb_index] &&
                   btb_tag[btb_index] == next_pc[31:8] &&
                   bht[predict_index][1];
wire [31:0] predicted_next = predict_hit ? btb_target[btb_index] :
                             next_pc + 32'd4;
wire [5:0] update_index = br_pc[7:2];
wire [5:0] update_direction = PREDICTOR_MODE ?
                              br_pred_index : update_index;
wire update_hit = btb_valid[update_index] &&
                  btb_tag[update_index] == br_pc[31:8];
wire pop = count != 0 && ds_allowin;
wire push_response = pending && inst_data_ok &&
                     !discard_pending && !flush && !br_redirect;
wire push_adef = !pending && count < FETCH_QUEUE_DEPTH &&
                 |next_pc[1:0] && !flush && !br_redirect;
wire push = push_response || push_adef;

assign fs_to_ds_valid = count != 0;
assign fs_to_ds_bus = {q_adef[head], q_inst[head],
                       q_pc[head], q_pred_next[head],
                       q_pred_index[head]};
assign inst_req = !reset && !flush && !br_redirect &&
                  !pending && count < FETCH_QUEUE_DEPTH &&
                  !(|next_pc[1:0]);
assign inst_addr = next_pc;

always @(posedge clk) begin
    if (reset) begin
        next_pc <= 32'h1c000000;
        pending_pc <= 0;
        pending_pred_next <= 0;
        pending_pred_index <= 0;
        pending <= 0;
        discard_pending <= 0;
        count <= 0;
        head <= 0;
        tail <= 0;
        btb_valid <= 0;
        global_history <= 0;
        for (i = 0; i < 64; i = i + 1)
            bht[i] <= 0;
    end else begin
        if (br_update) begin
            global_history <= {global_history[4:0], br_taken};
            if (br_taken) begin
                btb_valid[update_index] <= 1'b1;
                btb_tag[update_index] <= br_pc[31:8];
                btb_target[update_index] <= br_next_pc;
                bht[update_direction] <= !update_hit ? 2'b10 :
                    bht[update_direction] == 2'b11 ? 2'b11 :
                    bht[update_direction] + 1'b1;
            end else if (update_hit && bht[update_direction] != 2'b00) begin
                bht[update_direction] <= bht[update_direction] - 1'b1;
            end
        end

        if (pending && inst_data_ok) begin
            pending <= 0;
            discard_pending <= 0;
        end
        if (inst_req && inst_addr_ok) begin
            pending <= 1;
            pending_pc <= next_pc;
            pending_pred_next <= predicted_next;
            pending_pred_index <= predict_index;
            next_pc <= predicted_next;
        end
        if (push_adef)
            next_pc <= next_pc + 32'd4;

        if (push) begin
            q_adef[tail] <= push_adef;
            q_inst[tail] <= push_adef ? 32'b0 : inst_rdata;
            q_pc[tail] <= push_adef ? next_pc : pending_pc;
            q_pred_next[tail] <= push_adef ? next_pc + 32'd4 :
                                 pending_pred_next;
            q_pred_index[tail] <= push_adef ? predict_index :
                                  pending_pred_index;
            tail <= tail + 1'b1;
        end
        if (pop) head <= head + 1'b1;
        case ({push, pop})
            2'b10: count <= count + 1'b1;
            2'b01: count <= count - 1'b1;
            default: count <= count;
        endcase

        if (br_redirect || flush) begin
            next_pc <= flush ? flush_pc : br_next_pc;
            count <= 0;
            head <= 0;
            tail <= 0;
            if (pending && !inst_data_ok)
                discard_pending <= 1;
        end
    end
end
end endgenerate
endmodule
