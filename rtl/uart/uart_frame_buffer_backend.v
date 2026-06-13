module uart_frame_buffer_backend #(
    parameter integer FRAME_SAMPLES = 256,
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
    output reg error_pulse,

    output reg frame_loaded,
    output reg frame_done,
    output reg [15:0] bass_gain_q2_14,
    output reg [15:0] mid_gain_q2_14,
    output reg [15:0] treble_gain_q2_14,
    output wire [7:0] status_debug,

    input  wire [7:0] debug_sample_rd_addr,
    output reg signed [15:0] debug_input_sample,
    output reg signed [15:0] debug_result_sample,

    input  wire        cpu_wr_en,
    input  wire        cpu_rd_en,
    input  wire [15:0] cpu_addr,
    input  wire [15:0] cpu_wdata,
    output reg  [15:0] cpu_rdata,
    output wire        cpu_ready
);

    localparam [7:0] CMD_PING              = 8'h10;
    localparam [7:0] CMD_SET_GAINS         = 8'h11;
    localparam [7:0] CMD_WRITE_FRAME_CHUNK = 8'h12;
    localparam [7:0] CMD_RUN_FRAME         = 8'h13;
    localparam [7:0] CMD_READ_RESULT_CHUNK = 8'h14;
    localparam [7:0] CMD_GET_STATUS        = 8'h15;
    localparam [7:0] CMD_ERROR             = 8'h7F;

    localparam [7:0] RSP_PONG         = 8'h90;
    localparam [7:0] RSP_RESULT_CHUNK = 8'h94;
    localparam [7:0] RSP_STATUS       = 8'h95;

    localparam [7:0] STATUS_INPUT_LOADED = 8'h01;
    localparam [7:0] STATUS_CPU_BUSY     = 8'h02;
    localparam [7:0] STATUS_DONE         = 8'h04;
    localparam [7:0] STATUS_ERROR        = 8'h08;
    localparam [7:0] STATUS_TIMEOUT      = 8'h10;

    localparam [15:0] FRAME_CONTROL      = 16'hA000;
    localparam [15:0] FRAME_STATUS       = 16'hA001;
    localparam [15:0] FRAME_BASS_GAIN    = 16'hA003;
    localparam [15:0] FRAME_MID_GAIN     = 16'hA004;
    localparam [15:0] FRAME_TREBLE_GAIN  = 16'hA005;
    localparam [15:0] FRAME_INPUT_BASE   = 16'hA100;
    localparam [15:0] FRAME_RESULT_BASE  = 16'hA200;

    localparam [4:0] STATE_IDLE            = 5'd0;
    localparam [4:0] STATE_SET_BASS_L      = 5'd1;
    localparam [4:0] STATE_SET_BASS_H      = 5'd2;
    localparam [4:0] STATE_SET_MID_L       = 5'd3;
    localparam [4:0] STATE_SET_MID_H       = 5'd4;
    localparam [4:0] STATE_SET_TREBLE_L    = 5'd5;
    localparam [4:0] STATE_SET_TREBLE_H    = 5'd6;
    localparam [4:0] STATE_WRITE_OFF_L     = 5'd7;
    localparam [4:0] STATE_WRITE_OFF_H     = 5'd8;
    localparam [4:0] STATE_WRITE_COUNT     = 5'd9;
    localparam [4:0] STATE_WRITE_SAMPLE_L  = 5'd10;
    localparam [4:0] STATE_WRITE_SAMPLE_H  = 5'd11;
    localparam [4:0] STATE_RUN_COPY        = 5'd12;
    localparam [4:0] STATE_READ_OFF_L      = 5'd13;
    localparam [4:0] STATE_READ_OFF_H      = 5'd14;
    localparam [4:0] STATE_READ_COUNT      = 5'd15;
    localparam [4:0] STATE_START_RESP      = 5'd16;

    reg [4:0] state = STATE_IDLE;
    reg [7:0] cmd_reg = 8'd0;
    reg [7:0] seq_reg = 8'd0;
    reg [15:0] len_reg = 16'd0;
    reg [15:0] offset_reg = 16'd0;
    reg [7:0] count_reg = 8'd0;
    reg [7:0] sample_index = 8'd0;
    reg [7:0] copy_index = 8'd0;
    reg [7:0] sample_low_reg = 8'd0;
    reg [7:0] status_reg = 8'd0;
    reg run_request = 1'b0;

    reg [7:0] resp_mem [0:MAX_PAYLOAD_LEN-1];
    reg signed [15:0] input_frame [0:FRAME_SAMPLES-1];
    reg signed [15:0] result_frame [0:FRAME_SAMPLES-1];

    integer reset_index;
    integer resp_index;

    assign status_debug = status_reg;
    assign cpu_ready = 1'b1;

    always @* begin
        if (tx_payload_rd_addr < MAX_PAYLOAD_LEN) begin
            tx_payload_rd_data = resp_mem[tx_payload_rd_addr];
        end else begin
            tx_payload_rd_data = 8'd0;
        end

        if (debug_sample_rd_addr < FRAME_SAMPLES) begin
            debug_input_sample = input_frame[debug_sample_rd_addr];
            debug_result_sample = result_frame[debug_sample_rd_addr];
        end else begin
            debug_input_sample = 16'sd0;
            debug_result_sample = 16'sd0;
        end

        cpu_rdata = 16'd0;

        if (cpu_rd_en) begin
            if (cpu_addr == FRAME_CONTROL) begin
                cpu_rdata = {15'd0, run_request};
            end else if (cpu_addr == FRAME_STATUS) begin
                cpu_rdata = {8'd0, status_reg};
            end else if (cpu_addr == FRAME_BASS_GAIN) begin
                cpu_rdata = bass_gain_q2_14;
            end else if (cpu_addr == FRAME_MID_GAIN) begin
                cpu_rdata = mid_gain_q2_14;
            end else if (cpu_addr == FRAME_TREBLE_GAIN) begin
                cpu_rdata = treble_gain_q2_14;
            end else if (cpu_addr >= FRAME_INPUT_BASE &&
                         cpu_addr < FRAME_INPUT_BASE + FRAME_SAMPLES) begin
                cpu_rdata = input_frame[cpu_addr[7:0]];
            end else if (cpu_addr >= FRAME_RESULT_BASE &&
                         cpu_addr < FRAME_RESULT_BASE + FRAME_SAMPLES) begin
                cpu_rdata = result_frame[cpu_addr[7:0]];
            end
        end
    end

    function [15:0] chunk_payload_len;
        input [7:0] count_value;
        begin
            chunk_payload_len = 16'd3 + ({8'd0, count_value} << 1);
        end
    endfunction

    function range_is_valid;
        input [15:0] offset_value;
        input [7:0] count_value;
        begin
            range_is_valid =
                count_value != 8'd0 &&
                count_value <= MAX_CHUNK_SAMPLES &&
                offset_value + {8'd0, count_value} <= FRAME_SAMPLES;
        end
    endfunction

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
            frame_loaded <= 1'b0;
            frame_done <= 1'b0;
            bass_gain_q2_14 <= 16'd16384;
            mid_gain_q2_14 <= 16'd16384;
            treble_gain_q2_14 <= 16'd16384;
            cmd_reg <= 8'd0;
            seq_reg <= 8'd0;
            len_reg <= 16'd0;
            offset_reg <= 16'd0;
            count_reg <= 8'd0;
            sample_index <= 8'd0;
            copy_index <= 8'd0;
            sample_low_reg <= 8'd0;
            status_reg <= 8'd0;
            run_request <= 1'b0;

            for (reset_index = 0; reset_index < FRAME_SAMPLES;
                 reset_index = reset_index + 1) begin
                input_frame[reset_index] <= 16'sd0;
                result_frame[reset_index] <= 16'sd0;
            end
        end else begin
            tx_start <= 1'b0;
            ack_pulse <= 1'b0;
            error_pulse <= 1'b0;

            if (cpu_wr_en) begin
                if (cpu_addr == FRAME_CONTROL) begin
                    if (cpu_wdata[0]) begin
                        run_request <= 1'b0;
                    end

                    if (cpu_wdata[1]) begin
                        run_request <= 1'b0;
                        status_reg <= 8'd0;
                        frame_loaded <= 1'b0;
                        frame_done <= 1'b0;
                    end
                end else if (cpu_addr == FRAME_STATUS) begin
                    status_reg <= cpu_wdata[7:0];
                    frame_loaded <= cpu_wdata[0];
                    frame_done <= cpu_wdata[2];
                end else if (cpu_addr >= FRAME_RESULT_BASE &&
                             cpu_addr < FRAME_RESULT_BASE + FRAME_SAMPLES) begin
                    result_frame[cpu_addr[7:0]] <= cpu_wdata;
                end
            end

            case (state)
                STATE_IDLE: begin
                    packet_payload_rd_addr <= {PAYLOAD_ADDR_WIDTH{1'b0}};

                    if (packet_valid) begin
                        cmd_reg <= packet_cmd;
                        seq_reg <= packet_seq;
                        len_reg <= packet_payload_len;

                        if (packet_cmd == CMD_PING &&
                            packet_payload_len == 16'd0) begin
                            tx_cmd <= RSP_PONG;
                            tx_seq <= packet_seq;
                            tx_payload_len <= 16'd0;
                            ack_pulse <= 1'b1;
                            state <= STATE_START_RESP;
                        end else if (packet_cmd == CMD_SET_GAINS) begin
                            if (packet_payload_len == 16'd6) begin
                                packet_payload_rd_addr <=
                                    {PAYLOAD_ADDR_WIDTH{1'b0}};
                                state <= STATE_SET_BASS_L;
                            end else begin
                                status_reg <= status_reg | STATUS_ERROR;
                                prepare_error_response(packet_seq, packet_cmd);
                                error_pulse <= 1'b1;
                                state <= STATE_START_RESP;
                            end
                        end else if (packet_cmd == CMD_WRITE_FRAME_CHUNK) begin
                            if (packet_payload_len >= 16'd3) begin
                                packet_payload_rd_addr <=
                                    {PAYLOAD_ADDR_WIDTH{1'b0}};
                                state <= STATE_WRITE_OFF_L;
                            end else begin
                                status_reg <= status_reg | STATUS_ERROR;
                                prepare_error_response(packet_seq, packet_cmd);
                                error_pulse <= 1'b1;
                                state <= STATE_START_RESP;
                            end
                        end else if (packet_cmd == CMD_RUN_FRAME &&
                                     packet_payload_len == 16'd0) begin
                            if ((status_reg & STATUS_INPUT_LOADED) != 8'd0 &&
                                (status_reg & STATUS_CPU_BUSY) == 8'd0) begin
                                run_request <= 1'b1;
                                status_reg <=
                                    (status_reg & STATUS_INPUT_LOADED);
                                frame_done <= 1'b0;
                                prepare_status_response(
                                    packet_seq,
                                    status_reg & STATUS_INPUT_LOADED
                                );
                                ack_pulse <= 1'b1;
                            end else begin
                                status_reg <= status_reg | STATUS_ERROR;
                                prepare_error_response(packet_seq, packet_cmd);
                                error_pulse <= 1'b1;
                            end
                            state <= STATE_START_RESP;
                        end else if (packet_cmd == CMD_READ_RESULT_CHUNK) begin
                            if (packet_payload_len == 16'd3) begin
                                packet_payload_rd_addr <=
                                    {PAYLOAD_ADDR_WIDTH{1'b0}};
                                state <= STATE_READ_OFF_L;
                            end else begin
                                status_reg <= status_reg | STATUS_ERROR;
                                prepare_error_response(packet_seq, packet_cmd);
                                error_pulse <= 1'b1;
                                state <= STATE_START_RESP;
                            end
                        end else if (packet_cmd == CMD_GET_STATUS &&
                                     packet_payload_len == 16'd0) begin
                            prepare_status_response(packet_seq, status_reg);
                            ack_pulse <= 1'b1;
                            state <= STATE_START_RESP;
                        end else begin
                            status_reg <= status_reg | STATUS_ERROR;
                            prepare_error_response(packet_seq, packet_cmd);
                            error_pulse <= 1'b1;
                            state <= STATE_START_RESP;
                        end
                    end
                end

                STATE_SET_BASS_L: begin
                    bass_gain_q2_14[7:0] <= packet_payload_rd_data;
                    packet_payload_rd_addr <=
                        {{(PAYLOAD_ADDR_WIDTH-1){1'b0}}, 1'b1};
                    state <= STATE_SET_BASS_H;
                end

                STATE_SET_BASS_H: begin
                    bass_gain_q2_14[15:8] <= packet_payload_rd_data;
                    packet_payload_rd_addr <=
                        {{(PAYLOAD_ADDR_WIDTH-2){1'b0}}, 2'd2};
                    state <= STATE_SET_MID_L;
                end

                STATE_SET_MID_L: begin
                    mid_gain_q2_14[7:0] <= packet_payload_rd_data;
                    packet_payload_rd_addr <=
                        {{(PAYLOAD_ADDR_WIDTH-2){1'b0}}, 2'd3};
                    state <= STATE_SET_MID_H;
                end

                STATE_SET_MID_H: begin
                    mid_gain_q2_14[15:8] <= packet_payload_rd_data;
                    packet_payload_rd_addr <=
                        {{(PAYLOAD_ADDR_WIDTH-3){1'b0}}, 3'd4};
                    state <= STATE_SET_TREBLE_L;
                end

                STATE_SET_TREBLE_L: begin
                    treble_gain_q2_14[7:0] <= packet_payload_rd_data;
                    packet_payload_rd_addr <=
                        {{(PAYLOAD_ADDR_WIDTH-3){1'b0}}, 3'd5};
                    state <= STATE_SET_TREBLE_H;
                end

                STATE_SET_TREBLE_H: begin
                    treble_gain_q2_14[15:8] <= packet_payload_rd_data;
                    prepare_status_response(seq_reg, status_reg);
                    ack_pulse <= 1'b1;
                    state <= STATE_START_RESP;
                end

                STATE_WRITE_OFF_L: begin
                    offset_reg[7:0] <= packet_payload_rd_data;
                    packet_payload_rd_addr <=
                        {{(PAYLOAD_ADDR_WIDTH-1){1'b0}}, 1'b1};
                    state <= STATE_WRITE_OFF_H;
                end

                STATE_WRITE_OFF_H: begin
                    offset_reg[15:8] <= packet_payload_rd_data;
                    packet_payload_rd_addr <=
                        {{(PAYLOAD_ADDR_WIDTH-2){1'b0}}, 2'd2};
                    state <= STATE_WRITE_COUNT;
                end

                STATE_WRITE_COUNT: begin
                    count_reg <= packet_payload_rd_data;

                    if (packet_payload_len !=
                            chunk_payload_len(packet_payload_rd_data) ||
                        !range_is_valid(offset_reg, packet_payload_rd_data)) begin
                        status_reg <= status_reg | STATUS_ERROR;
                        prepare_error_response(seq_reg, cmd_reg);
                        error_pulse <= 1'b1;
                        state <= STATE_START_RESP;
                    end else begin
                        sample_index <= 8'd0;
                        packet_payload_rd_addr <=
                            {{(PAYLOAD_ADDR_WIDTH-2){1'b0}}, 2'd3};
                        state <= STATE_WRITE_SAMPLE_L;
                    end
                end

                STATE_WRITE_SAMPLE_L: begin
                    sample_low_reg <= packet_payload_rd_data;
                    packet_payload_rd_addr <= packet_payload_rd_addr + 1'b1;
                    state <= STATE_WRITE_SAMPLE_H;
                end

                STATE_WRITE_SAMPLE_H: begin
                    input_frame[offset_reg + {8'd0, sample_index}] <=
                        {packet_payload_rd_data, sample_low_reg};

                    if (sample_index + 8'd1 >= count_reg) begin
                        status_reg <= STATUS_INPUT_LOADED;
                        frame_loaded <= 1'b1;
                        frame_done <= 1'b0;
                        prepare_status_response(seq_reg, STATUS_INPUT_LOADED);
                        ack_pulse <= 1'b1;
                        state <= STATE_START_RESP;
                    end else begin
                        sample_index <= sample_index + 8'd1;
                        packet_payload_rd_addr <=
                            packet_payload_rd_addr + 1'b1;
                        state <= STATE_WRITE_SAMPLE_L;
                    end
                end

                STATE_RUN_COPY: begin
                    state <= STATE_IDLE;
                end

                STATE_READ_OFF_L: begin
                    offset_reg[7:0] <= packet_payload_rd_data;
                    packet_payload_rd_addr <=
                        {{(PAYLOAD_ADDR_WIDTH-1){1'b0}}, 1'b1};
                    state <= STATE_READ_OFF_H;
                end

                STATE_READ_OFF_H: begin
                    offset_reg[15:8] <= packet_payload_rd_data;
                    packet_payload_rd_addr <=
                        {{(PAYLOAD_ADDR_WIDTH-2){1'b0}}, 2'd2};
                    state <= STATE_READ_COUNT;
                end

                STATE_READ_COUNT: begin
                    count_reg <= packet_payload_rd_data;

                    if (!range_is_valid(offset_reg, packet_payload_rd_data)) begin
                        status_reg <= status_reg | STATUS_ERROR;
                        prepare_error_response(seq_reg, cmd_reg);
                        error_pulse <= 1'b1;
                    end else if ((status_reg & STATUS_DONE) == 8'd0) begin
                        prepare_error_response(seq_reg, cmd_reg);
                        error_pulse <= 1'b1;
                    end else begin
                        tx_cmd <= RSP_RESULT_CHUNK;
                        tx_seq <= seq_reg;
                        tx_payload_len <=
                            16'd4 + ({8'd0, packet_payload_rd_data} << 1);
                        resp_mem[0] <= status_reg;
                        resp_mem[1] <= offset_reg[7:0];
                        resp_mem[2] <= offset_reg[15:8];
                        resp_mem[3] <= packet_payload_rd_data;

                        for (resp_index = 0;
                             resp_index < MAX_CHUNK_SAMPLES;
                             resp_index = resp_index + 1) begin
                            if (resp_index < packet_payload_rd_data) begin
                                resp_mem[4 + (resp_index << 1)] <=
                                    result_frame[offset_reg + resp_index][7:0];
                                resp_mem[5 + (resp_index << 1)] <=
                                    result_frame[offset_reg + resp_index][15:8];
                            end
                        end

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
