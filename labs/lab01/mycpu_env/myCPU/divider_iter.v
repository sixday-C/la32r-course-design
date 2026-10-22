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

reg [31:0] dividend_shift;// 被除数的绝对值，除法过程中左移
reg [31:0] divisor_abs; // 除数的绝对值，除法过程中不变
reg [31:0] quotient_shift; // 商，每拍计算一位，最后送出
reg [32:0] remainder_shift;//余数，每次除法都左移，用 33 位存放
reg [5:0] bit_count;// 计数器，记录已经计算了多少位商
reg quotient_negative;// 商的符号，除法开始时计算，最后恢复符号
reg remainder_negative;// 余数的符号，除法开始时计算，最后恢复符号

wire dividend_is_negative = signed_div && dividend[31]; // 被除数是否为负数就看当前是否为有符号运算以及被除数的符号位
wire divisor_is_negative = signed_div && divisor[31]; // 除数是否为负数就看当前是否为有符号运算以及除数的符号位
wire [31:0] dividend_abs = dividend_is_negative ? -dividend : dividend; // 被除数的绝对值
wire [31:0] divisor_magnitude = divisor_is_negative ? -divisor : divisor; // 除数的绝对值



wire [32:0] trial_remainder = {remainder_shift[31:0], dividend_shift[31]};//余数左移一位，加上被除数的下一位，得到现在的余数
wire quotient_bit = trial_remainder >= {1'b0, divisor_abs};//如果余数大于等于除数，则商的当前位为 1，否则为 0
wire [32:0] next_remainder = quotient_bit ? //试算余数是否大于等于除数
    trial_remainder - {1'b0, divisor_abs} : trial_remainder;//计算现在的余数，如果大于等于除数，则余数减去除数，否则保持不变
wire [31:0] next_quotient = {quotient_shift[30:0], quotient_bit};//商左移一位，加上当前计算的商位

always @(posedge clk) begin
    if (reset) begin //复位
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
        done <= 1'b0; //当结果被接收后，done 置为 0，表示除法完成
    end else if (start && !busy && !done) begin //当除法开始时，busy 置为 1，表示除法正在进行
        done <= 1'b0;
        busy <= 1'b1;
        dividend_shift <= dividend_abs; //被除数的绝对值
        divisor_abs <= divisor_magnitude;//除数的绝对值
        quotient_shift <= 32'b0;//商清零
        remainder_shift <= 33'b0;//余数清零
        bit_count <= 6'b0;//计数器清零
        quotient_negative <= dividend_is_negative ^ divisor_is_negative;//商的符号为被除数和除数的符号异或
        remainder_negative <= dividend_is_negative;//余数的符号为被除数的符号
    end else if (busy) begin
        dividend_shift <= {dividend_shift[30:0], 1'b0}; //被除数左移一位
        quotient_shift <= next_quotient;//商左移一位，加上当前计算的商位
        remainder_shift <= next_remainder;//余数左移一位，加上被除数的下一位，得到现在的余数
        bit_count <= bit_count + 6'd1;//计数器加 1

        if (bit_count == 6'd31) begin//最后一轮
            // 有符号除法先算绝对值，再恢复商和余数的符号
            quotient <= quotient_negative ? -next_quotient : next_quotient;
            remainder <= remainder_negative ? -next_remainder[31:0] :
                         next_remainder[31:0];
            busy <= 1'b0;
            done <= 1'b1;
        end
    end
end

endmodule
