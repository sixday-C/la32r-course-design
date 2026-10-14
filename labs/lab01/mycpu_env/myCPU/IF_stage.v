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

// IF stage 寄存器：pc 是下次访问指令 RAM 的地址，fs_pc 是本次返回指令的地址。
reg [31:0] pc;
reg [31:0] fs_pc;
reg fs_valid;

wire fs_ready_go = 1'b1;
wire fs_allowin = !fs_valid || (fs_ready_go && ds_allowin);

assign fs_to_ds_valid = fs_valid && fs_ready_go;
assign fs_to_ds_bus = {inst_sram_rdata, fs_pc};

// 取 inst 的 pc 地址；分支跳转时用 br_target 替代顺序地址。
always @(posedge clk) begin
    if (reset) begin
        pc <= 32'h1c000000;
    end else if (fs_allowin && ds_allowin) begin
        pc <= br_taken ? br_target : pc + 32'd4;
    end
end

always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end else if (br_taken) begin
        fs_valid <= 1'b0;
    end else if (fs_allowin && ds_allowin) begin
        fs_valid <= 1'b1;
        fs_pc <= pc;
    end
end

// 指令 RAM 为同步读取：inst_sram_rdata 对应上一个上升沿送入的地址 fs_pc。
// 因此这里直接送入 IF→ID bus，不再对指令额外寄存一次。
// 为 1 时才能访问指令 sram。
assign inst_sram_en = fs_allowin && ds_allowin;
assign inst_sram_we = 4'b0;
assign inst_sram_addr = pc; // 取 inst 地址
assign inst_sram_wdata = 32'b0;

endmodule
