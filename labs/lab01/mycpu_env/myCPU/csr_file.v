`include "mycpu_head.v"
module csr_file(
    input  wire        clk,
    input  wire        reset,
    input  wire        csr_re,
    input  wire [13:0] csr_num,
    output reg  [31:0] csr_rvalue,
    input  wire        csr_we,
    input  wire [31:0] csr_wmask,
    input  wire [31:0] csr_wvalue,
    input  wire        wb_ex,
    input  wire [5:0]  wb_ecode,
    input  wire [8:0]  wb_esubcode,
    input  wire [31:0] wb_pc,
    input  wire        ertn_flush,
    output wire [31:0] ex_entry,
    output wire [31:0] ertn_entry
);

function [31:0] masked_write;
    input [31:0] old_value;
    input [31:0] mask;
    input [31:0] value;
    begin
        masked_write = (old_value & ~mask) | (value & mask);
    end
endfunction

reg [1:0] crmd_plv;
reg       crmd_ie;
reg [1:0] prmd_pplv;
reg       prmd_pie;
reg [1:0] estat_is_sw;
reg [5:0] estat_ecode;
reg [8:0] estat_esubcode;
reg [31:0] era;
reg [25:0] eentry_va;
reg [31:0] save0;
reg [31:0] save1;
reg [31:0] save2;
reg [31:0] save3;

// 暂时只用直接地址翻译，因此 CRMD.DA 固定为 1，PG/DATF/DATM 固定为 0。
wire [31:0] crmd_value = 32'h00000008 | {29'b0, crmd_ie, crmd_plv};
wire [31:0] prmd_value = {29'b0, prmd_pie, prmd_pplv};
wire [31:0] estat_value = {1'b0, estat_esubcode, estat_ecode,
                           3'b0, 13'b0 | {11'b0, estat_is_sw}};
wire [31:0] eentry_value = {eentry_va, 6'b0};
wire [31:0] crmd_next = masked_write(crmd_value, csr_wmask, csr_wvalue);
wire [31:0] prmd_next = masked_write(prmd_value, csr_wmask, csr_wvalue);

assign ex_entry = eentry_value;
assign ertn_entry = era;

always @(*) begin
    csr_rvalue = 32'b0;
    if (csr_re) begin
        case (csr_num)
            `CSR_CRMD:   csr_rvalue = crmd_value;
            `CSR_PRMD:   csr_rvalue = prmd_value;
            `CSR_ESTAT:  csr_rvalue = estat_value;
            `CSR_ERA:    csr_rvalue = era;
            `CSR_EENTRY: csr_rvalue = eentry_value;
            `CSR_SAVE0:  csr_rvalue = save0;
            `CSR_SAVE1:  csr_rvalue = save1;
            `CSR_SAVE2:  csr_rvalue = save2;
            `CSR_SAVE3:  csr_rvalue = save3;
            default:     csr_rvalue = 32'b0;
        endcase
    end
end

always @(posedge clk) begin
    if (reset) begin
        crmd_plv <= 2'b0;
        crmd_ie <= 1'b0;
        prmd_pplv <= 2'b0;
        prmd_pie <= 1'b0;
        estat_is_sw <= 2'b0;
        estat_ecode <= 6'b0;
        estat_esubcode <= 9'b0;
        era <= 32'b0;
        eentry_va <= 26'b0;
        save0 <= 32'b0;
        save1 <= 32'b0;
        save2 <= 32'b0;
        save3 <= 32'b0;
    end else begin
        // 异常先保存原来的特权级和中断使能；ertn 再把它们恢复。
        if (wb_ex) begin
            prmd_pplv <= crmd_plv;
            prmd_pie <= crmd_ie;
            crmd_plv <= 2'b0;
            crmd_ie <= 1'b0;
            estat_ecode <= wb_ecode;
            estat_esubcode <= wb_esubcode;
            era <= wb_pc;
        end else if (ertn_flush) begin
            crmd_plv <= prmd_pplv;
            crmd_ie <= prmd_pie;
        end else if (csr_we) begin
            case (csr_num)
                `CSR_CRMD: begin
                    crmd_plv <= crmd_next[1:0];
                    crmd_ie <= crmd_next[2];
                end
                `CSR_PRMD: begin
                    prmd_pplv <= prmd_next[1:0];
                    prmd_pie <= prmd_next[2];
                end
                `CSR_ESTAT: estat_is_sw <= masked_write(estat_value,
                                                       csr_wmask, csr_wvalue);
                `CSR_ERA: era <= masked_write(era, csr_wmask, csr_wvalue);
                `CSR_EENTRY: eentry_va <= masked_write(eentry_value,
                                                       csr_wmask, csr_wvalue) >> 6;
                `CSR_SAVE0: save0 <= masked_write(save0, csr_wmask, csr_wvalue);
                `CSR_SAVE1: save1 <= masked_write(save1, csr_wmask, csr_wvalue);
                `CSR_SAVE2: save2 <= masked_write(save2, csr_wmask, csr_wvalue);
                `CSR_SAVE3: save3 <= masked_write(save3, csr_wmask, csr_wvalue);
                default: ;
            endcase
        end
    end
end

endmodule
