`include "mycpu_head.v"
module IF_stage(
    input  wire                        clk,
    input  wire                        reset,
    input  wire                        ds_allowin,
    input  wire [`BR_BUS_WD-1:0]       br_bus,
    output wire                        fs_to_ds_valid,
    output wire [`FS_TO_DS_BUS_WD-1:0] fs_to_ds_bus,
    output wire                        inst_sram_en,
    output wire [3:0]                  inst_sram_we,
    output wire [31:0]                 inst_sram_addr,
    output wire [31:0]                 inst_sram_wdata,
    input  wire [31:0]                 inst_sram_rdata
);

wire br_taken;
wire [31:0] br_target;
assign {br_taken, br_target} = br_bus;

reg [31:0] pc;
reg [31:0] fs_pc;
reg fs_valid;

//IF 阶段不需要等待处理，所以 ready_go 永远为 1
wire fs_ready_go = 1'b1;
//IF 允许被进入的条件是，IF 阶段没有处理的工作 或者 IF 阶段处理完了且 ID 阶段允许进入
wire fs_allowin = !fs_valid || (fs_ready_go && ds_allowin);
//IF 是否有一条准备好的有效指令可以交给 ID
assign fs_to_ds_valid = fs_valid && fs_ready_go;
// IF→ID bus：送到 ID 阶段的指令和 PC
assign fs_to_ds_bus = {inst_sram_rdata, fs_pc};

// pc 更新逻辑，分支跳转时用 br_target 替代顺序地址
always @(posedge clk) begin
    if (reset) begin
        pc <= 32'h1c000000;
    end else if (fs_allowin && ds_allowin) begin
        pc <= br_taken ? br_target : pc + 32'd4;
    end
end
//
always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end else if (br_taken) begin
        fs_valid <= 1'b0; //跳转的时候，IF 阶段的指令无效作废
    end else if (fs_allowin && ds_allowin) begin
        fs_valid <= 1'b1;
        fs_pc <= pc;
    end
end

assign inst_sram_en = fs_allowin && ds_allowin;
assign inst_sram_we = 4'b0;
assign inst_sram_addr = pc; // 取 inst 地址
assign inst_sram_wdata = 32'b0;

endmodule
