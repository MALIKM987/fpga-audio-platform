`timescale 1ns/1ps

module uart_frame_buffer_backend_tb;

    localparam integer MAX_PAYLOAD_LEN = 128;
    localparam integer PAYLOAD_ADDR_WIDTH = 8;

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

    localparam [15:0] FRAME_CONTROL      = 16'hA000;
    localparam [15:0] FRAME_STATUS       = 16'hA001;
    localparam [15:0] FRAME_BASS_GAIN    = 16'hA003;
    localparam [15:0] FRAME_MID_GAIN     = 16'hA004;
    localparam [15:0] FRAME_TREBLE_GAIN  = 16'hA005;
    localparam [15:0] FRAME_INPUT_BASE   = 16'hA100;
    localparam [15:0] FRAME_RESULT_BASE  = 16'hA200;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg packet_valid = 1'b0;
    reg [7:0] packet_cmd = 8'd0;
    reg [7:0] packet_seq = 8'd0;
    reg [15:0] packet_payload_len = 16'd0;
    reg tx_ready = 1'b1;
    reg [7:0] debug_sample_rd_addr = 8'd0;
    reg cpu_wr_en = 1'b0;
    reg cpu_rd_en = 1'b0;
    reg [15:0] cpu_addr = 16'd0;
    reg [15:0] cpu_wdata = 16'd0;

    wire [PAYLOAD_ADDR_WIDTH-1:0] packet_payload_rd_addr;
    wire [7:0] packet_payload_rd_data;
    wire tx_start;
    wire [7:0] tx_cmd;
    wire [7:0] tx_seq;
    wire [15:0] tx_payload_len;
    wire [PAYLOAD_ADDR_WIDTH-1:0] tx_payload_rd_addr;
    wire [7:0] tx_payload_rd_data;
    wire tx_valid;
    wire [7:0] tx_data;
    wire tx_busy;
    wire tx_done;
    wire tx_error_length_too_large;
    wire ack_pulse;
    wire error_pulse;
    wire frame_loaded;
    wire frame_done;
    wire [15:0] bass_gain_q2_14;
    wire [15:0] mid_gain_q2_14;
    wire [15:0] treble_gain_q2_14;
    wire [7:0] status_debug;
    wire signed [15:0] debug_input_sample;
    wire signed [15:0] debug_result_sample;
    wire [15:0] cpu_rdata;
    wire cpu_ready;

    reg [7:0] payload_mem [0:MAX_PAYLOAD_LEN-1];
    reg [7:0] captured [0:255];
    integer captured_count = 0;
    integer errors = 0;
    integer i;
    integer wait_count;
    integer canary_ok;
    reg [15:0] cpu_read_value;

    assign packet_payload_rd_data = payload_mem[packet_payload_rd_addr];

    uart_frame_buffer_backend #(
        .FRAME_SAMPLES(256),
        .MAX_PAYLOAD_LEN(MAX_PAYLOAD_LEN),
        .PAYLOAD_ADDR_WIDTH(PAYLOAD_ADDR_WIDTH),
        .MAX_CHUNK_SAMPLES(32)
    ) backend_inst (
        .clk(clk),
        .rst(rst),
        .packet_valid(packet_valid),
        .packet_cmd(packet_cmd),
        .packet_seq(packet_seq),
        .packet_payload_len(packet_payload_len),
        .packet_payload_rd_addr(packet_payload_rd_addr),
        .packet_payload_rd_data(packet_payload_rd_data),
        .tx_start(tx_start),
        .tx_cmd(tx_cmd),
        .tx_seq(tx_seq),
        .tx_payload_len(tx_payload_len),
        .tx_payload_rd_addr(tx_payload_rd_addr),
        .tx_payload_rd_data(tx_payload_rd_data),
        .tx_busy(tx_busy),
        .ack_pulse(ack_pulse),
        .error_pulse(error_pulse),
        .frame_loaded(frame_loaded),
        .frame_done(frame_done),
        .bass_gain_q2_14(bass_gain_q2_14),
        .mid_gain_q2_14(mid_gain_q2_14),
        .treble_gain_q2_14(treble_gain_q2_14),
        .status_debug(status_debug),
        .debug_sample_rd_addr(debug_sample_rd_addr),
        .debug_input_sample(debug_input_sample),
        .debug_result_sample(debug_result_sample),
        .cpu_wr_en(cpu_wr_en),
        .cpu_rd_en(cpu_rd_en),
        .cpu_addr(cpu_addr),
        .cpu_wdata(cpu_wdata),
        .cpu_rdata(cpu_rdata),
        .cpu_ready(cpu_ready)
    );

    uart_frame_packet_tx #(
        .MAX_PAYLOAD_LEN(MAX_PAYLOAD_LEN),
        .PAYLOAD_ADDR_WIDTH(PAYLOAD_ADDR_WIDTH)
    ) tx_inst (
        .clk(clk),
        .rst(rst),
        .start(tx_start),
        .cmd(tx_cmd),
        .seq(tx_seq),
        .payload_len(tx_payload_len),
        .payload_rd_addr(tx_payload_rd_addr),
        .payload_rd_data(tx_payload_rd_data),
        .tx_ready(tx_ready),
        .tx_valid(tx_valid),
        .tx_data(tx_data),
        .busy(tx_busy),
        .done(tx_done),
        .error_length_too_large(tx_error_length_too_large)
    );

    always #5 clk = ~clk;

    task report_result;
        input [8*80-1:0] name;
        input pass;
        begin
            if (pass) begin
                $display("TEST %0s PASS", name);
            end else begin
                $display("TEST %0s FAIL", name);
                errors = errors + 1;
            end
        end
    endtask

    task clear_payload;
        begin
            for (i = 0; i < MAX_PAYLOAD_LEN; i = i + 1) begin
                payload_mem[i] = 8'd0;
            end
        end
    endtask

    task clear_capture;
        begin
            captured_count = 0;
            for (i = 0; i < 256; i = i + 1) begin
                captured[i] = 8'd0;
            end
        end
    endtask

    task reset_system;
        begin
            @(negedge clk);
            rst = 1'b1;
            packet_valid = 1'b0;
            packet_cmd = 8'd0;
            packet_seq = 8'd0;
            packet_payload_len = 16'd0;
            debug_sample_rd_addr = 8'd0;
            cpu_wr_en = 1'b0;
            cpu_rd_en = 1'b0;
            cpu_addr = 16'd0;
            cpu_wdata = 16'd0;
            clear_payload();
            clear_capture();
            repeat (4) @(negedge clk);
            rst = 1'b0;
            repeat (2) @(negedge clk);
        end
    endtask

    task send_packet;
        input [7:0] cmd_value;
        input [7:0] seq_value;
        input [15:0] len_value;
        begin
            clear_capture();
            @(negedge clk);
            packet_cmd = cmd_value;
            packet_seq = seq_value;
            packet_payload_len = len_value;
            packet_valid = 1'b1;
            @(negedge clk);
            packet_valid = 1'b0;
        end
    endtask

    task wait_for_response;
        input integer max_cycles;
        begin
            wait_count = 0;
            while (tx_done !== 1'b1 && wait_count < max_cycles) begin
                @(posedge clk);
                #1;
                wait_count = wait_count + 1;
            end
            repeat (2) @(posedge clk);
            #1;
        end
    endtask

    function [7:0] response_checksum;
        input integer payload_len_value;
        reg [15:0] sum;
        integer checksum_index;
        begin
            sum = {8'd0, captured[1]} +
                  {8'd0, captured[2]} +
                  {8'd0, captured[3]} +
                  {8'd0, captured[4]};
            for (checksum_index = 0;
                 checksum_index < payload_len_value;
                 checksum_index = checksum_index + 1) begin
                sum = sum + {8'd0, captured[5 + checksum_index]};
            end
            response_checksum = sum[7:0];
        end
    endfunction

    function response_packet_ok;
        input [7:0] expected_cmd;
        input [7:0] expected_seq;
        input integer expected_payload_len;
        begin
            response_packet_ok =
                captured_count == expected_payload_len + 7 &&
                captured[0] == 8'hA5 &&
                captured[1] == expected_cmd &&
                captured[2] == expected_seq &&
                captured[3] == expected_payload_len[7:0] &&
                captured[4] == expected_payload_len[15:8] &&
                captured[5 + expected_payload_len] ==
                    response_checksum(expected_payload_len) &&
                captured[6 + expected_payload_len] == 8'h5A;
        end
    endfunction

    function signed [15:0] payload_sample;
        input integer payload_offset;
        begin
            payload_sample = {captured[5 + payload_offset + 1],
                              captured[5 + payload_offset]};
        end
    endfunction

    task set_payload_i16;
        input integer payload_offset;
        input signed [15:0] value;
        begin
            payload_mem[payload_offset] = value[7:0];
            payload_mem[payload_offset + 1] = value[15:8];
        end
    endtask

    task cpu_read;
        input [15:0] addr;
        output [15:0] data;
        begin
            @(negedge clk);
            cpu_addr = addr;
            cpu_rd_en = 1'b1;
            #1;
            data = cpu_rdata;
            @(negedge clk);
            cpu_rd_en = 1'b0;
            cpu_addr = 16'd0;
        end
    endtask

    task cpu_write;
        input [15:0] addr;
        input [15:0] data;
        begin
            @(negedge clk);
            cpu_addr = addr;
            cpu_wdata = data;
            cpu_wr_en = 1'b1;
            @(negedge clk);
            cpu_wr_en = 1'b0;
            cpu_addr = 16'd0;
            cpu_wdata = 16'd0;
        end
    endtask

    always @(posedge clk) begin
        #1;
        if (tx_valid) begin
            captured[captured_count] = tx_data;
            captured_count = captured_count + 1;
        end
    end

    initial begin
        $display("=== UART FRAME BUFFER BACKEND TEST ===");
        $display("MODE=CPU_VISIBLE_MAILBOX_NO_DIRECT_FFT");
        $display("");

        reset_system();
        report_result("reset_status",
                      status_debug == 8'd0 &&
                      frame_loaded == 1'b0 &&
                      frame_done == 1'b0);
        report_result("default_gains",
                      bass_gain_q2_14 == 16'd16384 &&
                      mid_gain_q2_14 == 16'd16384 &&
                      treble_gain_q2_14 == 16'd16384);

        send_packet(CMD_PING, 8'h01, 16'd0);
        wait_for_response(40);
        report_result("ping_returns_pong",
                      response_packet_ok(RSP_PONG, 8'h01, 0));

        clear_payload();
        payload_mem[0] = 8'h00;
        payload_mem[1] = 8'h60;
        payload_mem[2] = 8'h00;
        payload_mem[3] = 8'h40;
        payload_mem[4] = 8'h00;
        payload_mem[5] = 8'h30;
        send_packet(CMD_SET_GAINS, 8'h02, 16'd6);
        wait_for_response(60);
        report_result("set_gains_response",
                      response_packet_ok(RSP_STATUS, 8'h02, 1) &&
                      captured[5] == 8'h00);
        report_result("set_gains_values",
                      bass_gain_q2_14 == 16'h6000 &&
                      mid_gain_q2_14 == 16'h4000 &&
                      treble_gain_q2_14 == 16'h3000);
        cpu_read(FRAME_BASS_GAIN, cpu_read_value);
        report_result("cpu_reads_bass_gain", cpu_read_value == 16'h6000);
        cpu_read(FRAME_MID_GAIN, cpu_read_value);
        report_result("cpu_reads_mid_gain", cpu_read_value == 16'h4000);
        cpu_read(FRAME_TREBLE_GAIN, cpu_read_value);
        report_result("cpu_reads_treble_gain", cpu_read_value == 16'h3000);

        clear_payload();
        payload_mem[0] = 8'h00;
        payload_mem[1] = 8'h00;
        payload_mem[2] = 8'd4;
        set_payload_i16(3, 16'sd10);
        set_payload_i16(5, -16'sd20);
        set_payload_i16(7, 16'sd30);
        set_payload_i16(9, -16'sd40);
        send_packet(CMD_WRITE_FRAME_CHUNK, 8'h03, 16'd11);
        wait_for_response(80);
        report_result("write_chunk_response",
                      response_packet_ok(RSP_STATUS, 8'h03, 1) &&
                      captured[5] == STATUS_INPUT_LOADED);
        debug_sample_rd_addr = 8'd0;
        #1;
        report_result("write_chunk_sample0", debug_input_sample == 16'sd10);
        debug_sample_rd_addr = 8'd1;
        #1;
        report_result("write_chunk_sample1", debug_input_sample == -16'sd20);
        debug_sample_rd_addr = 8'd3;
        #1;
        report_result("write_chunk_sample3", debug_input_sample == -16'sd40);
        cpu_read(FRAME_INPUT_BASE, cpu_read_value);
        report_result("cpu_reads_input0", cpu_read_value == 16'sd10);
        cpu_read(FRAME_INPUT_BASE + 16'd1, cpu_read_value);
        report_result("cpu_reads_input1", cpu_read_value == -16'sd20);

        clear_payload();
        payload_mem[0] = 8'h10;
        payload_mem[1] = 8'h00;
        payload_mem[2] = 8'd2;
        set_payload_i16(3, 16'sd111);
        set_payload_i16(5, -16'sd222);
        send_packet(CMD_WRITE_FRAME_CHUNK, 8'h04, 16'd7);
        wait_for_response(80);
        debug_sample_rd_addr = 8'd16;
        #1;
        report_result("write_chunk_offset16_sample0",
                      debug_input_sample == 16'sd111);
        debug_sample_rd_addr = 8'd17;
        #1;
        report_result("write_chunk_offset16_sample1",
                      debug_input_sample == -16'sd222);

        send_packet(CMD_RUN_FRAME, 8'h05, 16'd0);
        wait_for_response(400);
        report_result("run_frame_response",
                      response_packet_ok(RSP_STATUS, 8'h05, 1) &&
                      captured[5] == STATUS_INPUT_LOADED);
        cpu_read(FRAME_CONTROL, cpu_read_value);
        report_result("run_sets_cpu_request", cpu_read_value[0] == 1'b1);
        report_result("run_does_not_copy_without_cpu",
                      status_debug == STATUS_INPUT_LOADED &&
                      frame_done == 1'b0);

        clear_payload();
        payload_mem[0] = 8'h00;
        payload_mem[1] = 8'h00;
        payload_mem[2] = 8'd4;
        send_packet(CMD_READ_RESULT_CHUNK, 8'h06, 16'd3);
        wait_for_response(100);
        report_result("read_before_done_returns_error",
                      response_packet_ok(CMD_ERROR, 8'h06, 1) &&
                      captured[5] == CMD_READ_RESULT_CHUNK);

        cpu_write(FRAME_CONTROL, 16'h0001);
        cpu_write(FRAME_STATUS, STATUS_CPU_BUSY);
        cpu_read(FRAME_CONTROL, cpu_read_value);
        report_result("cpu_ack_clears_request", cpu_read_value[0] == 1'b0);
        report_result("cpu_sets_busy", status_debug == STATUS_CPU_BUSY);

        cpu_write(FRAME_RESULT_BASE, 16'sd10);
        cpu_write(FRAME_RESULT_BASE + 16'd1, -16'sd20);
        cpu_write(FRAME_RESULT_BASE + 16'd2, 16'sd30);
        cpu_write(FRAME_RESULT_BASE + 16'd3, -16'sd40);
        cpu_write(FRAME_RESULT_BASE + 16'd16, 16'sd111);
        cpu_write(FRAME_RESULT_BASE + 16'd17, -16'sd222);
        cpu_write(FRAME_STATUS, STATUS_INPUT_LOADED | STATUS_DONE);

        debug_sample_rd_addr = 8'd0;
        #1;
        report_result("cpu_writes_result0", debug_result_sample == 16'sd10);
        debug_sample_rd_addr = 8'd16;
        #1;
        report_result("cpu_writes_result16", debug_result_sample == 16'sd111);

        clear_payload();
        payload_mem[0] = 8'h00;
        payload_mem[1] = 8'h00;
        payload_mem[2] = 8'd4;
        send_packet(CMD_READ_RESULT_CHUNK, 8'h07, 16'd3);
        wait_for_response(100);
        report_result("read_result_response",
                      response_packet_ok(RSP_RESULT_CHUNK, 8'h07, 12));
        report_result("read_result_header",
                      captured[5] ==
                          (STATUS_INPUT_LOADED | STATUS_DONE) &&
                      captured[6] == 8'h00 &&
                      captured[7] == 8'h00 &&
                      captured[8] == 8'd4);
        report_result("read_result_samples",
                      payload_sample(4) == 16'sd10 &&
                      payload_sample(6) == -16'sd20 &&
                      payload_sample(8) == 16'sd30 &&
                      payload_sample(10) == -16'sd40);

        clear_payload();
        payload_mem[0] = 8'h10;
        payload_mem[1] = 8'h00;
        payload_mem[2] = 8'd2;
        send_packet(CMD_READ_RESULT_CHUNK, 8'h08, 16'd3);
        wait_for_response(100);
        report_result("read_result_offset16",
                      response_packet_ok(RSP_RESULT_CHUNK, 8'h08, 8) &&
                      captured[6] == 8'h10 &&
                      captured[7] == 8'h00 &&
                      captured[8] == 8'd2 &&
                      payload_sample(4) == 16'sd111 &&
                      payload_sample(6) == -16'sd222);

        cpu_write(FRAME_RESULT_BASE + 16'd0, 16'sd0);
        cpu_write(FRAME_RESULT_BASE + 16'd1, 16'sd1);
        cpu_write(FRAME_RESULT_BASE + 16'd2, -16'sd1);
        cpu_write(FRAME_RESULT_BASE + 16'd3, 16'sd127);
        cpu_write(FRAME_RESULT_BASE + 16'd4, 16'sd128);
        cpu_write(FRAME_RESULT_BASE + 16'd5, 16'sd255);
        cpu_write(FRAME_RESULT_BASE + 16'd6, 16'sd256);
        cpu_write(FRAME_RESULT_BASE + 16'd7, -16'sd128);
        cpu_write(FRAME_RESULT_BASE + 16'd8, -16'sd129);
        cpu_write(FRAME_RESULT_BASE + 16'd9, 16'sh7FFF);
        cpu_write(FRAME_RESULT_BASE + 16'd10, 16'sh8000);
        cpu_write(FRAME_STATUS, STATUS_INPUT_LOADED | STATUS_DONE);

        clear_payload();
        payload_mem[0] = 8'h00;
        payload_mem[1] = 8'h00;
        payload_mem[2] = 8'd11;
        send_packet(CMD_READ_RESULT_CHUNK, 8'h0C, 16'd3);
        wait_for_response(140);
        canary_ok =
            response_packet_ok(RSP_RESULT_CHUNK, 8'h0C, 26) &&
            captured[6] == 8'h00 &&
            captured[7] == 8'h00 &&
            captured[8] == 8'd11 &&
            payload_sample(4) == 16'sd0 &&
            payload_sample(6) == 16'sd1 &&
            payload_sample(8) == -16'sd1 &&
            payload_sample(10) == 16'sd127 &&
            payload_sample(12) == 16'sd128 &&
            payload_sample(14) == 16'sd255 &&
            payload_sample(16) == 16'sd256 &&
            payload_sample(18) == -16'sd128 &&
            payload_sample(20) == -16'sd129 &&
            payload_sample(22) == 16'sh7FFF &&
            payload_sample(24) == 16'sh8000;
        report_result("read_result_preserves_full_int16", canary_ok);

        send_packet(CMD_GET_STATUS, 8'h09, 16'd0);
        wait_for_response(60);
        report_result("get_status",
                      response_packet_ok(RSP_STATUS, 8'h09, 1) &&
                      captured[5] == (STATUS_INPUT_LOADED | STATUS_DONE));

        clear_payload();
        payload_mem[0] = 8'd250;
        payload_mem[1] = 8'd0;
        payload_mem[2] = 8'd16;
        send_packet(CMD_READ_RESULT_CHUNK, 8'h0A, 16'd3);
        wait_for_response(80);
        report_result("invalid_read_returns_error",
                      response_packet_ok(CMD_ERROR, 8'h0A, 1) &&
                      captured[5] == CMD_READ_RESULT_CHUNK &&
                      (status_debug & STATUS_ERROR) != 8'd0);

        send_packet(8'h55, 8'h0B, 16'd0);
        wait_for_response(80);
        report_result("unknown_returns_error",
                      response_packet_ok(CMD_ERROR, 8'h0B, 1) &&
                      captured[5] == 8'h55);

        report_result("tx_length_ok", tx_error_length_too_large == 1'b0);

        $display("");
        if (errors == 0) begin
            $display("STATUS=PASS");
        end else begin
            $display("STATUS=FAIL errors=%0d", errors);
        end

        $finish;
    end

endmodule
