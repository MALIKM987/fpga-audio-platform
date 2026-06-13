module uart_frame_mock_backend #(
    parameter integer MAX_PAYLOAD_LEN = 128,
    parameter integer PAYLOAD_ADDR_WIDTH = 8,
    parameter integer MAX_CHUNK_SAMPLES = 32
) (
    input  wire clk,
    input  wire rst,

    input  wire        packet_valid,
    input  wire [7:0]  packet_cmd,
    input  wire [7:0]  packet_seq,
    input  wire [15:0] packet_payload_len,
    output reg  [PAYLOAD_ADDR_WIDTH-1:0] packet_payload_rd_addr,
    input  wire [7:0]  packet_payload_rd_data,

    output reg        tx_start,
    output reg  [7:0] tx_cmd,
    output reg  [7:0] tx_seq,
    output reg [15:0] tx_payload_len,
    input  wire [PAYLOAD_ADDR_WIDTH-1:0] tx_payload_rd_addr,
    output reg  [7:0] tx_payload_rd_data,
    input  wire        tx_busy,

    output reg ack_pulse,
    output reg error_pulse
);

    localparam [7:0] CMD_PING              = 8'h10;
    localparam [7:0] CMD_SET_GAINS         = 8'h11;
    localparam [7:0] CMD_WRITE_FRAME_CHUNK = 8'h12;
    localparam [7:0] CMD_GET_STATUS        = 8'h15;
    localparam [7:0] CMD_ERROR             = 8'h7F;

    localparam [7:0] RSP_PONG   = 8'h90;
    localparam [7:0] RSP_STATUS = 8'h95;

    localparam [2:0] STATE_IDLE       = 3'd0;
    localparam [2:0] STATE_READ_OFF_L = 3'd1;
    localparam [2:0] STATE_READ_OFF_H = 3'd2;
    localparam [2:0] STATE_READ_COUNT = 3'd3;
    localparam [2:0] STATE_START_RESP = 3'd4;

    reg [2:0] state = STATE_IDLE;
    reg [7:0] cmd_reg = 8'd0;
    reg [7:0] seq_reg = 8'd0;
    reg [15:0] len_reg = 16'd0;
    reg [15:0] offset_reg = 16'd0;
    reg [7:0] count_reg = 8'd0;
    reg [7:0] resp_mem [0:MAX_PAYLOAD_LEN-1];

    always @* begin
        if (tx_payload_rd_addr < MAX_PAYLOAD_LEN) begin
            tx_payload_rd_data = resp_mem[tx_payload_rd_addr];
        end else begin
            tx_payload_rd_data = 8'd0;
        end
    end

    task prepare_status_response;
        input [7:0] seq_value;
        input [7:0] status_value;
        begin
            tx_cmd <= RSP_STATUS;
            tx_seq <= seq_value;
            tx_payload_len <= 16'd1;
            resp_mem[0] <= status_value;
        end
    endtask

    task prepare_error_response;
        input [7:0] seq_value;
        input [7:0] error_value;
        begin
            tx_cmd <= CMD_ERROR;
            tx_seq <= seq_value;
            tx_payload_len <= 16'd1;
            resp_mem[0] <= error_value;
        end
    endtask

    always @(posedge clk) begin
        if (rst) begin
            state <= STATE_IDLE;
            packet_payload_rd_addr <= {PAYLOAD_ADDR_WIDTH{1'b0}};
            tx_start <= 1'b0;
            tx_cmd <= 8'd0;
            tx_seq <= 8'd0;
            tx_payload_len <= 16'd0;
            ack_pulse <= 1'b0;
            error_pulse <= 1'b0;
            cmd_reg <= 8'd0;
            seq_reg <= 8'd0;
            len_reg <= 16'd0;
            offset_reg <= 16'd0;
            count_reg <= 8'd0;
        end else begin
            tx_start <= 1'b0;
            ack_pulse <= 1'b0;
            error_pulse <= 1'b0;

            case (state)
                STATE_IDLE: begin
                    packet_payload_rd_addr <= {PAYLOAD_ADDR_WIDTH{1'b0}};

                    if (packet_valid) begin
                        cmd_reg <= packet_cmd;
                        seq_reg <= packet_seq;
                        len_reg <= packet_payload_len;

                        if (packet_cmd == CMD_PING && packet_payload_len == 16'd0) begin
                            tx_cmd <= RSP_PONG;
                            tx_seq <= packet_seq;
                            tx_payload_len <= 16'd0;
                            ack_pulse <= 1'b1;
                            state <= STATE_START_RESP;
                        end else if (packet_cmd == CMD_GET_STATUS &&
                                     packet_payload_len == 16'd0) begin
                            prepare_status_response(packet_seq, 8'h00);
                            ack_pulse <= 1'b1;
                            state <= STATE_START_RESP;
                        end else if (packet_cmd == CMD_SET_GAINS &&
                                     packet_payload_len == 16'd6) begin
                            prepare_status_response(packet_seq, 8'h00);
                            ack_pulse <= 1'b1;
                            state <= STATE_START_RESP;
                        end else if (packet_cmd == CMD_WRITE_FRAME_CHUNK) begin
                            if (packet_payload_len < 16'd3) begin
                                prepare_error_response(packet_seq, packet_cmd);
                                error_pulse <= 1'b1;
                                state <= STATE_START_RESP;
                            end else begin
                                packet_payload_rd_addr <= {PAYLOAD_ADDR_WIDTH{1'b0}};
                                state <= STATE_READ_OFF_L;
                            end
                        end else begin
                            prepare_error_response(packet_seq, packet_cmd);
                            error_pulse <= 1'b1;
                            state <= STATE_START_RESP;
                        end
                    end
                end

                STATE_READ_OFF_L: begin
                    offset_reg[7:0] <= packet_payload_rd_data;
                    packet_payload_rd_addr <= {{(PAYLOAD_ADDR_WIDTH-1){1'b0}}, 1'b1};
                    state <= STATE_READ_OFF_H;
                end

                STATE_READ_OFF_H: begin
                    offset_reg[15:8] <= packet_payload_rd_data;
                    packet_payload_rd_addr <= {{(PAYLOAD_ADDR_WIDTH-2){1'b0}}, 2'd2};
                    state <= STATE_READ_COUNT;
                end

                STATE_READ_COUNT: begin
                    count_reg <= packet_payload_rd_data;

                    if (packet_payload_rd_data == 8'd0 ||
                        packet_payload_rd_data > MAX_CHUNK_SAMPLES ||
                        packet_payload_len !=
                            (16'd3 + ({8'd0, packet_payload_rd_data} << 1)) ||
                        {offset_reg[15:8], offset_reg[7:0]} +
                            {8'd0, packet_payload_rd_data} > 16'd256) begin
                        prepare_error_response(seq_reg, cmd_reg);
                        error_pulse <= 1'b1;
                    end else begin
                        prepare_status_response(seq_reg, 8'h00);
                        ack_pulse <= 1'b1;
                    end

                    state <= STATE_START_RESP;
                end

                STATE_START_RESP: begin
                    if (!tx_busy) begin
                        tx_start <= 1'b1;
                        state <= STATE_IDLE;
                    end
                end

                default: begin
                    state <= STATE_IDLE;
                end
            endcase
        end
    end

endmodule
