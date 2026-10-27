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

wire br_taken;
wire [31:0] br_target;
assign {br_taken, br_target} = br_bus;

reg [31:0] next_pc;
reg [31:0] pending_pc;
reg pending;
reg discard_pending;
reg fs_valid;
reg fs_adef;
reg [31:0] fs_pc;
reg [31:0] fs_inst;

assign fs_to_ds_valid = fs_valid;
assign fs_to_ds_bus = {fs_adef, fs_inst, fs_pc};
assign inst_req = !reset && !flush && !br_taken &&
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
    end else begin
        if (fs_valid && ds_allowin)
            fs_valid <= 1'b0;

        if (pending && inst_data_ok) begin
            pending <= 1'b0;
            discard_pending <= 1'b0;
            if (!discard_pending && !flush && !br_taken) begin
                fs_valid <= 1'b1;
                fs_adef <= 1'b0;
                fs_pc <= pending_pc;
                fs_inst <= inst_rdata;
            end
        end

        if (inst_req && inst_addr_ok) begin
            pending <= 1'b1;
            pending_pc <= next_pc;
            next_pc <= next_pc + 32'd4;
        end
        if (!pending && !fs_valid && |next_pc[1:0] &&
            !flush && !br_taken) begin
            fs_valid <= 1'b1;
            fs_adef <= 1'b1;
            fs_pc <= next_pc;
            fs_inst <= 32'b0;
            next_pc <= next_pc + 32'd4;
        end

        if (br_taken || flush) begin
            next_pc <= flush ? flush_pc : br_target;
            fs_valid <= 1'b0;
            if (pending && !inst_data_ok)
                discard_pending <= 1'b1;
        end
    end
end
endmodule
