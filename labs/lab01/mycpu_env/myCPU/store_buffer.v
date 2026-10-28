// 两项普通内存写队列。load、MMIO、cache 维护都等较早的 store 排空。
module store_buffer #(
    parameter ENABLE = 1
)(
    input  wire        clk,
    input  wire        resetn,
    input  wire        cpu_req,
    input  wire [3:0]  cpu_we,
    input  wire [31:0] cpu_addr,
    input  wire [31:0] cpu_wdata,
    output wire        cpu_addr_ok,
    output wire        cpu_data_ok,
    output wire [31:0] cpu_rdata,
    output wire        dc_req,
    output wire [3:0]  dc_we,
    output wire [31:0] dc_addr,
    output wire [31:0] dc_wdata,
    input  wire        dc_addr_ok,
    input  wire        dc_data_ok,
    input  wire [31:0] dc_rdata,
    output wire        empty
);
generate if (!ENABLE) begin: direct
    assign cpu_addr_ok = dc_addr_ok;
    assign cpu_data_ok = dc_data_ok;
    assign cpu_rdata = dc_rdata;
    assign dc_req = cpu_req;
    assign dc_we = cpu_we;
    assign dc_addr = cpu_addr;
    assign dc_wdata = cpu_wdata;
    assign empty = 1'b1;
end else begin: buffered
    reg [31:0] addr_q [0:1];
    reg [31:0] data_q [0:1];
    reg [3:0] we_q [0:1];
    reg head = 0;
    reg tail = 0;
    reg [1:0] count = 0;
    reg drain_sent = 0;
    reg ack_pending = 0;
    wire ordinary_store = (|cpu_we) && cpu_addr[31:16] != 16'hbfaf;
    wire draining = count != 0;
    wire enqueue = resetn && cpu_req && ordinary_store && count != 2;
    wire dequeue = resetn && draining && drain_sent && dc_data_ok;

    assign empty = !draining && !drain_sent;
    assign cpu_addr_ok = ordinary_store ? count != 2 : empty && dc_addr_ok;
    // 入队后的下一拍再应答，匹配 MEM 阶段的 request_sent 时序。
    assign cpu_data_ok = ack_pending || (empty && dc_data_ok);
    assign cpu_rdata = dc_rdata;
    assign dc_req = resetn && (draining ? !drain_sent :
                              cpu_req && !ordinary_store);
    assign dc_we = draining ? we_q[head] : cpu_we;
    assign dc_addr = draining ? addr_q[head] : cpu_addr;
    assign dc_wdata = draining ? data_q[head] : cpu_wdata;

    // 暖复位保留已确认的普通 RAM 写；未完成的 D-Cache 请求在复位后重发。
    // 队列只装普通 RAM，重复写入相同字节不会产生 MMIO 副作用。
    always @(posedge clk) begin
        if (!resetn) begin
            drain_sent <= 1'b0;
            ack_pending <= 1'b0;
        end else begin
            ack_pending <= enqueue;
            if (enqueue) begin
                addr_q[tail] <= cpu_addr;
                data_q[tail] <= cpu_wdata;
                we_q[tail] <= cpu_we;
                tail <= !tail;
            end
            if (draining && !drain_sent && dc_req && dc_addr_ok)
                drain_sent <= 1'b1;
            if (dequeue) begin
                head <= !head;
                drain_sent <= 1'b0;
            end
            case ({enqueue, dequeue})
                2'b10: count <= count + 1'b1;
                2'b01: count <= count - 1'b1;
                default: count <= count;
            endcase
        end
    end
end endgenerate
endmodule
