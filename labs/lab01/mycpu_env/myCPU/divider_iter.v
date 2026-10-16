// 每拍计算一位商。EXE 发出 start 后，done 会一直保持到结果被接收。
module divider_iter(
    input  wire        clk,
    input  wire        reset,
    input  wire        start,
    input  wire        consume,
    input  wire        signed_div,
    input  wire [31:0] dividend,
    input  wire [31:0] divisor,
    output reg         busy,
    output reg         done,
    output reg  [31:0] quotient,
    output reg  [31:0] remainder
);

reg [31:0] dividend_shift;
reg [31:0] divisor_abs;
reg [31:0] quotient_shift;
reg [32:0] remainder_shift;
reg [5:0] bit_count;
reg quotient_negative;
reg remainder_negative;

wire dividend_is_negative = signed_div && dividend[31];
wire divisor_is_negative = signed_div && divisor[31];
wire [31:0] dividend_abs = dividend_is_negative ? -dividend : dividend;
wire [31:0] divisor_magnitude = divisor_is_negative ? -divisor : divisor;

// 把被除数的下一位移进余数；够减就把当前商位记为 1。
wire [32:0] trial_remainder = {remainder_shift[31:0], dividend_shift[31]};
wire quotient_bit = trial_remainder >= {1'b0, divisor_abs};
wire [32:0] next_remainder = quotient_bit ?
    trial_remainder - {1'b0, divisor_abs} : trial_remainder;
wire [31:0] next_quotient = {quotient_shift[30:0], quotient_bit};

always @(posedge clk) begin
    if (reset) begin
        busy <= 1'b0;
        done <= 1'b0;
        quotient <= 32'b0;
        remainder <= 32'b0;
        dividend_shift <= 32'b0;
        divisor_abs <= 32'b0;
        quotient_shift <= 32'b0;
        remainder_shift <= 33'b0;
        bit_count <= 6'b0;
        quotient_negative <= 1'b0;
        remainder_negative <= 1'b0;
    end else if (consume) begin
        done <= 1'b0;
    end else if (start && !busy && !done) begin
        busy <= 1'b1;
        dividend_shift <= dividend_abs;
        divisor_abs <= divisor_magnitude;
        quotient_shift <= 32'b0;
        remainder_shift <= 33'b0;
        bit_count <= 6'b0;
        quotient_negative <= dividend_is_negative ^ divisor_is_negative;
        remainder_negative <= dividend_is_negative;
    end else if (busy) begin
        dividend_shift <= {dividend_shift[30:0], 1'b0};
        quotient_shift <= next_quotient;
        remainder_shift <= next_remainder;
        bit_count <= bit_count + 6'd1;

        if (bit_count == 6'd31) begin
            // 有符号除法先算绝对值，再恢复商和余数的符号。
            quotient <= quotient_negative ? -next_quotient : next_quotient;
            remainder <= remainder_negative ? -next_remainder[31:0] :
                         next_remainder[31:0];
            busy <= 1'b0;
            done <= 1'b1;
        end
    end
end

endmodule
