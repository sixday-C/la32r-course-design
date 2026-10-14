`include "mycpu_head.v"
module ID_stage(
    input  wire                        clk,
    input  wire                        reset,
    input  wire                        fs_to_ds_valid,
    input  wire [`FS_TO_DS_BUS_WD-1:0] fs_to_ds_bus,
    input  wire                        es_allowin,
    output wire                        ds_allowin,
    output wire                        ds_to_es_valid,
    output wire [`DS_TO_ES_BUS_WD-1:0] ds_to_es_bus,
    output wire [`BR_BUS_WD-1:0]       br_bus,
    input  wire [`ES_FWD_BUS_WD-1:0]   es_fwd_bus,
    input  wire [`MS_FWD_BUS_WD-1:0]   ms_fwd_bus,
    input  wire [`WS_FWD_BUS_WD-1:0]   ws_fwd_bus,
    input  wire [`WS_TO_RF_BUS_WD-1:0] ws_to_rf_bus
);

// -----------------------------------------------------------------------------
// ID 流水寄存器与握手
// -----------------------------------------------------------------------------
reg ds_valid;
// ID stage 寄存器：保存从 IF→ID bus 接收的指令和对应 PC。
reg [31:0] ds_pc;
reg [31:0] ds_inst;
wire ds_ready_go;
wire br_taken;

assign ds_allowin = !ds_valid || (ds_ready_go && es_allowin);
assign ds_to_es_valid = ds_valid && ds_ready_go;

always @(posedge clk) begin
    if (reset) begin
        ds_valid <= 1'b0;
    end else if (br_taken) begin
        ds_valid <= 1'b0;
    end else if (ds_allowin) begin
        ds_valid <= fs_to_ds_valid;
    end

    if (fs_to_ds_valid && ds_allowin) begin
        {ds_inst, ds_pc} <= fs_to_ds_bus;
    end
end

// -----------------------------------------------------------------------------
// 指令字段与译码
// -----------------------------------------------------------------------------
// 译码必须使用 ds_inst，而不是当前 IF 阶段刚取到的指令。
wire [5:0] op_31_26 = ds_inst[31:26];
wire [3:0] op_25_22 = ds_inst[25:22];
wire [1:0] op_21_20 = ds_inst[21:20];
wire [4:0] op_19_15 = ds_inst[19:15];
wire [4:0] rd = ds_inst[4:0];
wire [4:0] rj = ds_inst[9:5];
wire [4:0] rk = ds_inst[14:10];
wire [11:0] i12 = ds_inst[21:10];
wire [19:0] i20 = ds_inst[24:5];
wire [15:0] i16 = ds_inst[25:10];
wire [25:0] i26 = {ds_inst[9:0], ds_inst[25:10]};
wire [63:0] op_31_26_d;
wire [15:0] op_25_22_d;
wire [3:0] op_21_20_d;
wire [31:0] op_19_15_d;
decoder_6_64 u_dec0(.in(op_31_26), .out(op_31_26_d));
decoder_4_16 u_dec1(.in(op_25_22), .out(op_25_22_d));
decoder_2_4 u_dec2(.in(op_21_20), .out(op_21_20_d));
decoder_5_32 u_dec3(.in(op_19_15), .out(op_19_15_d));
wire inst_add_w;
wire inst_sub_w;
wire inst_slt;
wire inst_sltu;
wire inst_nor;
wire inst_and;
wire inst_or;
wire inst_xor;
wire inst_slli_w;
wire inst_srli_w;
wire inst_srai_w;
wire inst_addi_w;
wire inst_ld_w;
wire inst_st_w;
// 本次增加的访存指令：b 取 1 字节，h 取 2 字节，bu/hu 读出后补零。
wire inst_ld_b;
wire inst_ld_h;
wire inst_ld_bu;
wire inst_ld_hu;
wire inst_st_b;
wire inst_st_h;
wire inst_jirl;
wire inst_b;
wire inst_bl;
wire inst_beq;
wire inst_bne;
wire inst_lu12i_w;
wire inst_slti;
wire inst_sltui;
wire inst_andi;
wire inst_ori;
wire inst_xori;
wire inst_sll_w;
wire inst_srl_w;
wire inst_sra_w;
wire inst_pcaddu12i;
wire inst_blt;
wire inst_bge;
wire inst_bltu;
wire inst_bgeu;

assign inst_add_w = op_31_26_d[6'h00] & op_25_22_d[4'h0]
                  & op_21_20_d[2'h1] & op_19_15_d[5'h00];
assign inst_sub_w = op_31_26_d[6'h00] & op_25_22_d[4'h0]
                  & op_21_20_d[2'h1] & op_19_15_d[5'h02];
assign inst_slt   = op_31_26_d[6'h00] & op_25_22_d[4'h0]
                  & op_21_20_d[2'h1] & op_19_15_d[5'h04];
assign inst_sltu  = op_31_26_d[6'h00] & op_25_22_d[4'h0]
                  & op_21_20_d[2'h1] & op_19_15_d[5'h05];
assign inst_nor   = op_31_26_d[6'h00] & op_25_22_d[4'h0]
                  & op_21_20_d[2'h1] & op_19_15_d[5'h08];
assign inst_and   = op_31_26_d[6'h00] & op_25_22_d[4'h0]
                  & op_21_20_d[2'h1] & op_19_15_d[5'h09];
assign inst_or    = op_31_26_d[6'h00] & op_25_22_d[4'h0]
                  & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
assign inst_xor   = op_31_26_d[6'h00] & op_25_22_d[4'h0]
                  & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1]
                   & op_21_20_d[2'h0] & op_19_15_d[5'h01];
assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1]
                   & op_21_20_d[2'h0] & op_19_15_d[5'h09];
assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1]
                   & op_21_20_d[2'h0] & op_19_15_d[5'h11];
assign inst_addi_w  = op_31_26_d[6'h00] & op_25_22_d[4'ha];
assign inst_ld_w    = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
assign inst_st_w    = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
// 它们和 ld.w/st.w 一样，靠 op_25_22 区分具体的读写宽度。
assign inst_ld_b    = op_31_26_d[6'h0a] & op_25_22_d[4'h0];
assign inst_ld_h    = op_31_26_d[6'h0a] & op_25_22_d[4'h1];
assign inst_ld_bu   = op_31_26_d[6'h0a] & op_25_22_d[4'h8];
assign inst_ld_hu   = op_31_26_d[6'h0a] & op_25_22_d[4'h9];
assign inst_st_b    = op_31_26_d[6'h0a] & op_25_22_d[4'h4];
assign inst_st_h    = op_31_26_d[6'h0a] & op_25_22_d[4'h5];
assign inst_jirl    = op_31_26_d[6'h13];
assign inst_b       = op_31_26_d[6'h14];
assign inst_bl      = op_31_26_d[6'h15];
assign inst_beq     = op_31_26_d[6'h16];
assign inst_bne     = op_31_26_d[6'h17];
assign inst_lu12i_w = op_31_26_d[6'h05] & ~ds_inst[25];

// 下面是这次新增指令的编码。立即数类主要看 op_25_22，
// sll.w/srl.w/sra.w 则和 add.w 一样，还要继续检查低位功能码。
assign inst_slti     = op_31_26_d[6'h00] & op_25_22_d[4'h8];
assign inst_sltui    = op_31_26_d[6'h00] & op_25_22_d[4'h9];
assign inst_andi     = op_31_26_d[6'h00] & op_25_22_d[4'hd];
assign inst_ori      = op_31_26_d[6'h00] & op_25_22_d[4'he];
assign inst_xori     = op_31_26_d[6'h00] & op_25_22_d[4'hf];
assign inst_sll_w    = op_31_26_d[6'h00] & op_25_22_d[4'h0]
                     & op_21_20_d[2'h1] & op_19_15_d[5'h0e];
assign inst_srl_w    = op_31_26_d[6'h00] & op_25_22_d[4'h0]
                     & op_21_20_d[2'h1] & op_19_15_d[5'h0f];
assign inst_sra_w    = op_31_26_d[6'h00] & op_25_22_d[4'h0]
                     & op_21_20_d[2'h1] & op_19_15_d[5'h10];
assign inst_pcaddu12i = op_31_26_d[6'h07] & ~ds_inst[25];
assign inst_blt      = op_31_26_d[6'h18];
assign inst_bge      = op_31_26_d[6'h19];
assign inst_bltu     = op_31_26_d[6'h1a];
assign inst_bgeu     = op_31_26_d[6'h1b];

// -----------------------------------------------------------------------------
// 控制信号、立即数和源寄存器
// -----------------------------------------------------------------------------
wire [11:0] alu_op;
// 所有访存指令都要先算 rj + 偏移量，得到要访问的地址。
assign alu_op[0] = inst_add_w | inst_addi_w | inst_ld_w |
                   inst_st_w | inst_ld_b | inst_ld_h | inst_ld_bu |
                   inst_ld_hu | inst_st_b | inst_st_h |
                   inst_jirl | inst_bl | inst_pcaddu12i;
assign alu_op[1] = inst_sub_w;
assign alu_op[2] = inst_slt | inst_slti;
assign alu_op[3] = inst_sltu | inst_sltui;
assign alu_op[4] = inst_and | inst_andi;
assign alu_op[5] = inst_nor;
assign alu_op[6] = inst_or | inst_ori;
assign alu_op[7] = inst_xor | inst_xori;
assign alu_op[8] = inst_slli_w | inst_sll_w;
assign alu_op[9] = inst_srli_w | inst_srl_w;
assign alu_op[10] = inst_srai_w | inst_sra_w;
assign alu_op[11] = inst_lu12i_w;

// slti/sltui、andi/ori/xori 只换立即数或比较方式，ALU 运算本身可以复用。
// pcaddu12i 要算 PC + 高位立即数，所以走加法，并把 ds_pc 当第一个操作数。
wire need_si20 = inst_lu12i_w | inst_pcaddu12i;
wire need_si26 = inst_b | inst_bl;
wire src2_is_4 = inst_jirl | inst_bl;
wire need_ui12 = inst_andi | inst_ori | inst_xori;
// andi $r4,$r5,0xff 里的 0xff 要补成 0x000000ff；
// slti 的立即数则要保留符号位，例如 0xfff 按 -1 处理。
wire [31:0] imm = src2_is_4 ? 32'd4 :
                  need_si20 ? {i20, 12'b0} :
                  need_ui12 ? {20'b0, i12} :
                              {{20{i12[11]}}, i12};
wire [31:0] br_offs = need_si26 ? {{4{i26[25]}}, i26, 2'b0} :
                                  {{14{i16[15]}}, i16, 2'b0};
wire [31:0] jirl_offs = {{14{i16[15]}}, i16, 2'b0};
// store 的 rd 是要写入内存的数据，不是这条指令的目的寄存器。
wire src_reg_is_rd = inst_beq | inst_bne | inst_blt | inst_bge |
                     inst_bltu | inst_bgeu | inst_st_w | inst_st_b | inst_st_h;

// 当前指令是否真正需要读取第一个源寄存器 rj。
// 例如 sll.w r6,r4,r5 会拿 r4 的值左移，r4 依赖前一条指令时也要前递或阻塞。
// ld.b/st.h 也要读 rj 算地址，不能漏掉相关判断。
wire need_rj = inst_add_w  | inst_sub_w  | inst_slt    | inst_sltu |
               inst_nor    | inst_and    | inst_or     | inst_xor  |
               inst_slli_w | inst_srli_w | inst_srai_w | inst_addi_w |
               inst_ld_w   | inst_st_w   | inst_ld_b   | inst_ld_h |
               inst_ld_bu  | inst_ld_hu  | inst_st_b   | inst_st_h |
               inst_jirl   | inst_beq |
               inst_bne    | inst_slti   | inst_sltui  | inst_andi |
               inst_ori    | inst_xori   | inst_sll_w  | inst_srl_w |
               inst_sra_w  | inst_blt    | inst_bge    | inst_bltu |
               inst_bgeu;

// 当前指令是否真正需要读取第二个源寄存器。store 要读 rd 中待写入的数据。
wire need_rkd = inst_add_w | inst_sub_w | inst_slt  | inst_sltu |
                inst_nor   | inst_and   | inst_or   | inst_xor  |
                inst_st_w  | inst_st_b  | inst_st_h  | inst_beq |
                inst_bne   | inst_sll_w |
                inst_srl_w | inst_sra_w | inst_blt   | inst_bge |
                inst_bltu  | inst_bgeu;

wire src1_is_pc = inst_jirl | inst_bl | inst_pcaddu12i;
// 访存地址用 rj + 符号扩展后的 i12；i12 可以是负偏移。
wire src2_is_imm = inst_slli_w | inst_srli_w | inst_srai_w |
                   inst_addi_w | inst_ld_w   | inst_st_w    |
                   inst_ld_b   | inst_ld_h   | inst_ld_bu   |
                   inst_ld_hu  | inst_st_b   | inst_st_h    |
                   inst_lu12i_w | inst_jirl | inst_bl      |
                   inst_slti   | inst_sltui | inst_andi    |
                   inst_ori    | inst_xori  | inst_pcaddu12i;
wire res_from_mem = inst_ld_w | inst_ld_b | inst_ld_h |
                    inst_ld_bu | inst_ld_hu;
// bl 要写链接地址到寄存器 1，不能和其他分支一起关闭写回，故删去 bl。
wire gr_we = ~(inst_st_w | inst_st_b | inst_st_h |
               inst_beq | inst_bne | inst_blt |
               inst_bge | inst_bltu | inst_bgeu | inst_b);
wire mem_we = inst_st_w | inst_st_b | inst_st_h;
// 00: word，01: byte，10: half；后两级据此选字节使能或读回的数据。
// ld.bu/ld.hu 另带一个标志，提醒 WB 阶段补零而不是补符号位。
wire [1:0] mem_size = (inst_ld_b | inst_ld_bu | inst_st_b) ? 2'd1 :
                      (inst_ld_h | inst_ld_hu | inst_st_h) ? 2'd2 : 2'd0;
wire mem_unsigned = inst_ld_bu | inst_ld_hu;
wire [4:0] dest = inst_bl ? 5'd1 : rd;

// -----------------------------------------------------------------------------
// 寄存器堆与前递
// -----------------------------------------------------------------------------
wire rf_we;
wire [4:0] rf_waddr;
wire [31:0] rf_wdata;
assign {rf_we, rf_waddr, rf_wdata} = ws_to_rf_bus;
wire [4:0] rf_raddr1 = rj;
wire [4:0] rf_raddr2 = src_reg_is_rd ? rd : rk;
wire [31:0] rf_rdata1;
wire [31:0] rf_rdata2;
// 寄存器堆在 ID 读、WB 写；写回信息通过 WS_TO_RF_BUS 送回。
regfile u_regfile (
    .clk    (clk),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we),
    .waddr  (rf_waddr),
    .wdata  (rf_wdata)
);

wire es_valid;
wire es_gr_we;
wire es_res_from_mem;
wire [4:0] es_dest;
wire [31:0] es_result;
assign {es_valid, es_gr_we, es_res_from_mem,
        es_dest, es_result} = es_fwd_bus;

wire ms_valid;
wire ms_gr_we;
wire ms_res_from_mem;
wire [4:0] ms_dest;
wire [31:0] ms_result;
assign {ms_valid, ms_gr_we, ms_res_from_mem,
        ms_dest, ms_result} = ms_fwd_bus;

wire ws_valid;
wire ws_gr_we;
wire [4:0] ws_dest;
wire [31:0] ws_result;
assign {ws_valid, ws_gr_we, ws_dest, ws_result} = ws_fwd_bus;

// forwarding：先判断读寄存器是否命中后续阶段，优先级 EXE > MEM > WB。
// 只有确实需要该源寄存器时才检查相关；0 号寄存器不参与前递。
wire rj_match_es = need_rj && rf_raddr1 != 0 && es_valid &&
                   es_gr_we && es_dest != 0 && rf_raddr1 == es_dest;
wire rj_match_ms = need_rj && rf_raddr1 != 0 && ms_valid &&
                   ms_gr_we && ms_dest != 0 && rf_raddr1 == ms_dest;
wire rj_match_ws = need_rj && rf_raddr1 != 0 && ws_valid &&
                   ws_gr_we && ws_dest != 0 && rf_raddr1 == ws_dest;

wire rkd_match_es = need_rkd && rf_raddr2 != 0 && es_valid &&
                    es_gr_we && es_dest != 0 && rf_raddr2 == es_dest;
wire rkd_match_ms = need_rkd && rf_raddr2 != 0 && ms_valid &&
                    ms_gr_we && ms_dest != 0 && rf_raddr2 == ms_dest;
wire rkd_match_ws = need_rkd && rf_raddr2 != 0 && ws_valid &&
                    ws_gr_we && ws_dest != 0 && rf_raddr2 == ws_dest;

wire [31:0] rj_value =
    rj_match_es && !es_res_from_mem ? es_result :
    !rj_match_es && rj_match_ms && !ms_res_from_mem ? ms_result :
    !rj_match_es && !rj_match_ms && rj_match_ws ? ws_result :
    rf_rdata1;

wire [31:0] rkd_value =
    rkd_match_es && !es_res_from_mem ? es_result :
    !rkd_match_es && rkd_match_ms && !ms_res_from_mem ? ms_result :
    !rkd_match_es && !rkd_match_ms && rkd_match_ws ? ws_result :
    rf_rdata2;

// -----------------------------------------------------------------------------
// RAW 阻塞、分支与输出 bus
// -----------------------------------------------------------------------------
// 原来只要与后续阶段的目的寄存器相同就阻塞；加入前递后，
// EXE/MEM 中的 load 结果尚未从 Block RAM 返回，只有这类无法前递的相关才 stall。
// WB 阶段的 data_sram_rdata 已返回，可直接前递，不需要检查 ms_res_from_mem。
wire rj_raw_conflict =
    (rj_match_es && es_res_from_mem) ||
    (!rj_match_es && rj_match_ms && ms_res_from_mem);
wire rkd_raw_conflict =
    (rkd_match_es && es_res_from_mem) ||
    (!rkd_match_es && rkd_match_ms && ms_res_from_mem);

assign ds_ready_go = !(ds_valid && (rj_raw_conflict || rkd_raw_conflict));

// 分支在 ID 阶段判断；操作数使用前递后的值，相关未解决时暂不跳转。
// blt/bge 把寄存器值当有符号数；bltu/bgeu 把相同的位型当无符号数比较。
assign br_taken =
    ((inst_beq && rj_value == rkd_value) ||
     (inst_bne && rj_value != rkd_value) ||
     (inst_blt && $signed(rj_value) < $signed(rkd_value)) || // 有符号比较
     (inst_bge && $signed(rj_value) >= $signed(rkd_value)) || // 有符号比较
     (inst_bltu && rj_value < rkd_value) || // 无符号比较
     (inst_bgeu && rj_value >= rkd_value) ||  //无符号比较
     inst_jirl || inst_bl || inst_b) && ds_valid && ds_ready_go;

// 相对分支以 ds_pc 为基址；jirl 以 rj_value 为基址。
wire [31:0] br_target =
    (inst_beq || inst_bne || inst_blt || inst_bge ||
     inst_bltu || inst_bgeu || inst_bl || inst_b) ?
    ds_pc + br_offs : rj_value + jirl_offs;

assign br_bus = {br_taken, br_target};
// 宽度和扩展方式跟着指令一起走，不能到 MEM/WB 再看 ID 中的当前指令。
assign ds_to_es_bus = {
    alu_op, src1_is_pc, src2_is_imm,
    rj_value, rkd_value, imm,
    res_from_mem, gr_we, mem_we, mem_size, mem_unsigned, dest, ds_pc
};

endmodule
