module uart_frame_packet_tx #(
    parameter integer MAX_PAYLOAD_LEN = 128,
    parameter integer PAYLOAD_ADDR_WIDTH = 8
) (
    input  wire clk,
    input  wire rst,

    input  wire       start,
    input  wire [7:0] cmd,
    input  wire [7:0] seq,
    input  wire [15:0] payload_len,

    output reg  [PAYLOAD_ADDR_WIDTH-1:0] payload_rd_addr,
    input  wire [7:0] payload_rd_data,

    input  wire tx_ready,
    output reg  tx_valid,
    output reg  [7:0] tx_data,

    output reg busy,
    output reg done,
    output reg error_length_too_large
);

    localparam [2:0] STATE_IDLE    = 3'd0;
    localparam [2:0] STATE_SOF     = 3'd1;
    localparam [2:0] STATE_CMD     = 3'd2;
    localparam [2:0] STATE_SEQ     = 3'd3;
    localparam [2:0] STATE_LEN_L   = 3'd4;
    localparam [2:0] STATE_LEN_H   = 3'd5;
    localparam [2:0] STATE_PAYLOAD = 3'd6;
    localparam [2:0] STATE_CHK_EOF = 3'd7;

    localparam [7:0] SOF = 8'hA5;
    localparam [7:0] EOF_MARKER = 8'h5A;

    reg [2:0] state = STATE_IDLE;
    reg [7:0] cmd_reg = 8'd0;
    reg [7:0] seq_reg = 8'd0;
    reg [15:0] len_reg = 16'd0;
    reg [15:0] payload_index = 16'd0;
    reg [7:0] checksum_acc = 8'd0;
    reg send_eof = 1'b0;

    always @(posedge clk) begin
        if (rst) begin
            state <= STATE_IDLE;
            cmd_reg <= 8'd0;
            seq_reg <= 8'd0;
            len_reg <= 16'd0;
            payload_index <= 16'd0;
            payload_rd_addr <= {PAYLOAD_ADDR_WIDTH{1'b0}};
            checksum_acc <= 8'd0;
            send_eof <= 1'b0;
            tx_valid <= 1'b0;
            tx_data <= 8'd0;
            busy <= 1'b0;
            done <= 1'b0;
            error_length_too_large <= 1'b0;
        end else begin
            tx_valid <= 1'b0;
            done <= 1'b0;
            error_length_too_large <= 1'b0;

            case (state)
                STATE_IDLE: begin
                    busy <= 1'b0;
                    send_eof <= 1'b0;
                    payload_index <= 16'd0;
                    payload_rd_addr <= {PAYLOAD_ADDR_WIDTH{1'b0}};

                    if (start) begin
                        if (payload_len > MAX_PAYLOAD_LEN) begin
                            error_length_too_large <= 1'b1;
                        end else begin
                            cmd_reg <= cmd;
                            seq_reg <= seq;
                            len_reg <= payload_len;
                            checksum_acc <= 8'd0;
                            busy <= 1'b1;
                            state <= STATE_SOF;
                        end
                    end
                end

                STATE_SOF: begin
                    if (tx_ready) begin
                        tx_valid <= 1'b1;
                        tx_data <= SOF;
                        state <= STATE_CMD;
                    end
                end

                STATE_CMD: begin
                    if (tx_ready) begin
                        tx_valid <= 1'b1;
                        tx_data <= cmd_reg;
                        checksum_acc <= cmd_reg;
                        state <= STATE_SEQ;
                    end
                end

                STATE_SEQ: begin
                    if (tx_ready) begin
                        tx_valid <= 1'b1;
                        tx_data <= seq_reg;
                        checksum_acc <= checksum_acc + seq_reg;
                        state <= STATE_LEN_L;
                    end
                end

                STATE_LEN_L: begin
                    if (tx_ready) begin
                        tx_valid <= 1'b1;
                        tx_data <= len_reg[7:0];
                        checksum_acc <= checksum_acc + len_reg[7:0];
                        state <= STATE_LEN_H;
                    end
                end

                STATE_LEN_H: begin
                    if (tx_ready) begin
                        tx_valid <= 1'b1;
                        tx_data <= len_reg[15:8];
                        checksum_acc <= checksum_acc + len_reg[15:8];
                        payload_index <= 16'd0;
                        payload_rd_addr <= {PAYLOAD_ADDR_WIDTH{1'b0}};

                        if (len_reg == 16'd0) begin
                            state <= STATE_CHK_EOF;
                            send_eof <= 1'b0;
                        end else begin
                            state <= STATE_PAYLOAD;
                        end
                    end
                end

                STATE_PAYLOAD: begin
                    if (tx_ready) begin
                        tx_valid <= 1'b1;
                        tx_data <= payload_rd_data;
                        checksum_acc <= checksum_acc + payload_rd_data;

                        if (payload_index + 16'd1 >= len_reg) begin
                            state <= STATE_CHK_EOF;
                            send_eof <= 1'b0;
                        end else begin
                            payload_index <= payload_index + 16'd1;
                            payload_rd_addr <= payload_index[PAYLOAD_ADDR_WIDTH-1:0] + 1'b1;
                        end
                    end
                end

                STATE_CHK_EOF: begin
                    if (tx_ready) begin
                        tx_valid <= 1'b1;

                        if (!send_eof) begin
                            tx_data <= checksum_acc;
                            send_eof <= 1'b1;
                        end else begin
                            tx_data <= EOF_MARKER;
                            send_eof <= 1'b0;
                            done <= 1'b1;
                            busy <= 1'b0;
                            state <= STATE_IDLE;
                        end
                    end
                end

                default: begin
                    state <= STATE_IDLE;
                    busy <= 1'b0;
                end
            endcase
        end
    end

endmodule
