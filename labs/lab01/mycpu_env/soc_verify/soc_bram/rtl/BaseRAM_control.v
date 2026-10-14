// 将 CPU 的高有效指令 SRAM 接口转换成板上 BaseRAM 的低有效接口。
// 此模块作为板级适配器使用；现有 soc_lite_top 的 BRAM 仿真不经过这里。
module BaseRAM_control(
    input  wire        clk,
    input  wire        reset,

    // From CPU: active-high enable and byte write enables.
    input  wire        inst_sram_en,
    input  wire [31:0] inst_sram_addr,
    input  wire [31:0] inst_sram_wdata,
    output reg  [31:0] inst_sram_rdata,
    input  wire [3:0]  inst_sram_we,

    // To board BaseRAM: active-low control signals.
    inout  wire [31:0] base_ram_data,
    output wire [19:0] base_ram_addr,
    output wire [3:0]  base_ram_be_n,
    output wire        base_ram_ce_n,
    output wire        base_ram_oe_n,
    output wire        base_ram_we_n
);

wire ram_write = inst_sram_en && (|inst_sram_we);
wire ram_read  = inst_sram_en && !(|inst_sram_we);

// BaseRAM controls are active low. During a read, all four byte lanes are enabled.
assign base_ram_be_n = ram_write ? ~inst_sram_we : 4'b0000;
assign base_ram_ce_n = ~inst_sram_en;
assign base_ram_oe_n = ~ram_read;
assign base_ram_we_n = ~ram_write;

// BaseRAM uses byte addresses; discard the two byte-offset bits.
assign base_ram_addr = inst_sram_addr[21:2];

// The CPU drives the shared data bus only during a selected write.
assign base_ram_data = ram_write ? inst_sram_wdata : 32'bz;

// Capture read data on the rising clock edge, matching the CPU's synchronous RAM interface.
always @(posedge clk) begin
    if (reset) begin
        inst_sram_rdata <= 32'hz;
    end else if (ram_read) begin
        inst_sram_rdata <= base_ram_data;
    end
end

endmodule
