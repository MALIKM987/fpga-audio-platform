module uart_frame_packet_rx #(
    parameter integer MAX_PAYLOAD_LEN = 128,
    parameter integer PAYLOAD_ADDR_WIDTH = 8
) (
    input  wire clk,
    input  wire rst,

    input  wire       rx_valid,
    input  wire [7:0] rx_data,

    output reg        packet_valid,
    output reg  [7:0] cmd,
    output reg  [7:0] seq,
    output reg [15:0] payload_len,

    input  wire [PAYLOAD_ADDR_WIDTH-1:0] payload_rd_addr,
    output reg  [7:0] payload_rd_data,

    output reg error_bad_checksum,
    output reg error_bad_eof,
    output reg error_length_too_large,
    output reg error_malformed
);

    localparam [2:0] STATE_IDLE    = 3'd0;
    localparam [2:0] STATE_CMD     = 3'd1;
    localparam [2:0] STATE_SEQ     = 3'd2;
    localparam [2:0] STATE_LEN_L   = 3'd3;
    localparam [2:0] STATE_LEN_H   = 3'd4;
    localparam [2:0] STATE_PAYLOAD = 3'd5;
    localparam [2:0] STATE_CHK     = 3'd6;
    localparam [2:0] STATE_EOF     = 3'd7;

    localparam [7:0] SOF = 8'hA5;
    localparam [7:0] EOF_MARKER = 8'h5A;

    reg [2:0] state = STATE_IDLE;
    reg [15:0] write_index = 16'd0;
    reg [7:0] checksum_acc = 8'd0;
    reg checksum_ok = 1'b0;
    reg [7:0] payload_mem [0:MAX_PAYLOAD_LEN-1];

    always @* begin
        if (payload_rd_addr < MAX_PAYLOAD_LEN) begin
            payload_rd_data = payload_mem[payload_rd_addr];
        end else begin
            payload_rd_data = 8'd0;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            state <= STATE_IDLE;
            packet_valid <= 1'b0;
            cmd <= 8'd0;
            seq <= 8'd0;
            payload_len <= 16'd0;
            write_index <= 16'd0;
            checksum_acc <= 8'd0;
            checksum_ok <= 1'b0;
            error_bad_checksum <= 1'b0;
            error_bad_eof <= 1'b0;
            error_length_too_large <= 1'b0;
            error_malformed <= 1'b0;
        end else begin
            packet_valid <= 1'b0;
            error_bad_checksum <= 1'b0;
            error_bad_eof <= 1'b0;
            error_length_too_large <= 1'b0;
            error_malformed <= 1'b0;

            if (rx_valid) begin
                case (state)
                    STATE_IDLE: begin
                        if (rx_data == SOF) begin
                            state <= STATE_CMD;
                            checksum_acc <= 8'd0;
                            checksum_ok <= 1'b0;
                            write_index <= 16'd0;
                            payload_len <= 16'd0;
                        end else begin
                            error_malformed <= 1'b1;
                        end
                    end

                    STATE_CMD: begin
                        cmd <= rx_data;
                        checksum_acc <= rx_data;
                        state <= STATE_SEQ;
                    end

                    STATE_SEQ: begin
                        seq <= rx_data;
                        checksum_acc <= checksum_acc + rx_data;
                        state <= STATE_LEN_L;
                    end

                    STATE_LEN_L: begin
                        payload_len[7:0] <= rx_data;
                        checksum_acc <= checksum_acc + rx_data;
                        state <= STATE_LEN_H;
                    end

                    STATE_LEN_H: begin
                        payload_len[15:8] <= rx_data;
                        checksum_acc <= checksum_acc + rx_data;
                        write_index <= 16'd0;

                        if ({rx_data, payload_len[7:0]} > MAX_PAYLOAD_LEN) begin
                            error_length_too_large <= 1'b1;
                            state <= STATE_IDLE;
                        end else if ({rx_data, payload_len[7:0]} == 16'd0) begin
                            state <= STATE_CHK;
                        end else begin
                            state <= STATE_PAYLOAD;
                        end
                    end

                    STATE_PAYLOAD: begin
                        if (write_index < MAX_PAYLOAD_LEN) begin
                            payload_mem[write_index] <= rx_data;
                        end

                        checksum_acc <= checksum_acc + rx_data;

                        if (write_index + 16'd1 >= payload_len) begin
                            state <= STATE_CHK;
                        end

                        write_index <= write_index + 16'd1;
                    end

                    STATE_CHK: begin
                        checksum_ok <= (checksum_acc == rx_data);
                        state <= STATE_EOF;
                    end

                    STATE_EOF: begin
                        if (rx_data != EOF_MARKER) begin
                            error_bad_eof <= 1'b1;
                        end else if (!checksum_ok) begin
                            error_bad_checksum <= 1'b1;
                        end else begin
                            packet_valid <= 1'b1;
                        end

                        state <= STATE_IDLE;
                    end

                    default: begin
                        error_malformed <= 1'b1;
                        state <= STATE_IDLE;
                    end
                endcase
            end
        end
    end

endmodule
