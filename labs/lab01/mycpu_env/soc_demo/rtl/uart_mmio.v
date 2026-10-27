// 8N1 UART，CPU 侧通过数据寄存器读写，状态寄存器由 SoC 组合。
module uart_mmio #(
    parameter integer CLKS_PER_BIT = 217
)(
    input  wire       clk,
    input  wire       resetn,
    input  wire       rx,
    output reg        tx,
    input  wire       tx_write,
    input  wire [7:0] tx_data,
    output wire       tx_ready,
    input  wire       rx_read,
    output reg  [7:0] rx_data,
    output reg        rx_valid
);
localparam [1:0] TX_IDLE = 2'd0, TX_START = 2'd1,
                 TX_DATA = 2'd2, TX_STOP = 2'd3;
reg [1:0] tx_state;
assign tx_ready = tx_state == TX_IDLE;
reg [15:0] tx_count;
reg [2:0] tx_bit;
reg [7:0] tx_shift;

reg rx_meta, rx_sync;
always @(posedge clk) begin
    rx_meta <= rx;
    rx_sync <= rx_meta;
end

localparam [2:0] RX_IDLE = 3'd0, RX_START = 3'd1,
                 RX_DATA = 3'd2, RX_STOP = 3'd3;
reg [2:0] rx_state;
reg [15:0] rx_count;
reg [2:0] rx_bit;
reg [7:0] rx_shift;

always @(posedge clk) begin
    if (!resetn) begin
        tx_state <= TX_IDLE;
        tx_count <= 0;
        tx_bit <= 0;
        tx_shift <= 0;
        tx <= 1'b1;
        rx_state <= RX_IDLE;
        rx_count <= 0;
        rx_bit <= 0;
        rx_shift <= 0;
        rx_data <= 0;
        rx_valid <= 1'b0;
    end else begin
        case (tx_state)
            TX_IDLE: begin
                tx <= 1'b1;
                if (tx_write) begin
                    tx_shift <= tx_data;
                    tx_count <= 0;
                    tx_state <= TX_START;
                    tx <= 1'b0;
                end
            end
            TX_START: if (tx_count == CLKS_PER_BIT - 1) begin
                tx_count <= 0;
                tx_bit <= 0;
                tx_state <= TX_DATA;
                tx <= tx_shift[0];
            end else tx_count <= tx_count + 1'b1;
            TX_DATA: if (tx_count == CLKS_PER_BIT - 1) begin
                tx_count <= 0;
                if (tx_bit == 3'd7) begin
                    tx_state <= TX_STOP;
                    tx <= 1'b1;
                end else begin
                    tx_bit <= tx_bit + 1'b1;
                    tx_shift <= {1'b0, tx_shift[7:1]};
                    tx <= tx_shift[1];
                end
            end else tx_count <= tx_count + 1'b1;
            TX_STOP: if (tx_count == CLKS_PER_BIT - 1) begin
                tx_count <= 0;
                tx_state <= TX_IDLE;
                tx <= 1'b1;
            end else tx_count <= tx_count + 1'b1;
            default: tx_state <= TX_IDLE;
        endcase

        if (rx_read) rx_valid <= 1'b0;
        case (rx_state)
            RX_IDLE: if (!rx_sync) begin
                rx_count <= (CLKS_PER_BIT - 1) / 2;
                rx_state <= RX_START;
            end
            RX_START: if (rx_count == 0) begin
                if (!rx_sync) begin
                    rx_count <= CLKS_PER_BIT - 1;
                    rx_bit <= 0;
                    rx_state <= RX_DATA;
                end else rx_state <= RX_IDLE;
            end else rx_count <= rx_count - 1'b1;
            RX_DATA: if (rx_count == 0) begin
                rx_shift[rx_bit] <= rx_sync;
                rx_count <= CLKS_PER_BIT - 1;
                if (rx_bit == 3'd7) rx_state <= RX_STOP;
                else rx_bit <= rx_bit + 1'b1;
            end else rx_count <= rx_count - 1'b1;
            RX_STOP: if (rx_count == 0) begin
                if (rx_sync) begin
                    rx_data <= rx_shift;
                    rx_valid <= 1'b1;
                end
                rx_state <= RX_IDLE;
            end else rx_count <= rx_count - 1'b1;
            default: rx_state <= RX_IDLE;
        endcase
    end
end
endmodule
