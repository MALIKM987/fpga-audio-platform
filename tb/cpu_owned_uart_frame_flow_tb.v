`timescale 1ns/1ps
`include "rtl/cpu/mini_cpu_defs.vh"

module cpu_owned_uart_frame_flow_tb;

    localparam integer MAX_PAYLOAD_LEN = 128;
    localparam integer PAYLOAD_ADDR_WIDTH = 8;
    localparam integer TIMEOUT_CYCLES = 800000;

    localparam [7:0] CMD_SET_GAINS         = 8'h11;
    localparam [7:0] CMD_WRITE_FRAME_CHUNK = 8'h12;
    localparam [7:0] CMD_RUN_FRAME         = 8'h13;
    localparam [7:0] CMD_READ_RESULT_CHUNK = 8'h14;
    localparam [7:0] CMD_GET_STATUS        = 8'h15;
    localparam [7:0] CMD_ERROR             = 8'h7F;

    localparam [7:0] RSP_RESULT_CHUNK = 8'h94;
    localparam [7:0] RSP_STATUS       = 8'h95;

    localparam [7:0] STATUS_INPUT_LOADED = 8'h01;
    localparam [7:0] STATUS_DONE         = 8'h04;
    localparam [7:0] STATUS_ERROR        = 8'h08;
    localparam [7:0] STATUS_TIMEOUT      = 8'h10;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg packet_valid = 1'b0;
    reg [7:0] packet_cmd = 8'd0;
    reg [7:0] packet_seq = 8'd0;
    reg [15:0] packet_payload_len = 16'd0;
    reg tx_ready = 1'b1;
    reg [7:0] debug_sample_rd_addr = 8'd0;

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

    wire frame_cpu_wr_en;
    wire frame_cpu_rd_en;
    wire [15:0] frame_cpu_addr;
    wire [15:0] frame_cpu_wdata;
    wire [15:0] frame_cpu_rdata;
    wire frame_cpu_ready;

    wire [15:0] gpio_result;
    wire cpu_halted;
    wire fft_busy;
    wire fft_done;
    wire fft_overflow;
    wire fft_error;
    wire [15:0] bus_addr_debug;
    wire [15:0] bus_wdata_debug;
    wire bus_we_debug;
    wire bus_re_debug;
    wire [15:0] debug_pc;
    wire debug_zero_flag;
    wire [15:0] debug_reg0;
    wire [15:0] debug_reg1;
    wire [15:0] debug_reg2;
    wire [15:0] debug_reg3;
    wire [15:0] debug_reg4;
    wire [15:0] debug_reg5;
    wire [15:0] debug_reg6;
    wire [15:0] debug_reg7;
    wire debug_saw_frame_request;
    wire debug_fft_start_written;
    wire [15:0] debug_fft_bass_gain_written;
    wire [15:0] debug_fft_mid_gain_written;
    wire [15:0] debug_fft_treble_gain_written;
    wire [15:0] debug_fft_input0_written;
    wire [15:0] debug_fft_input1_written;
    wire [15:0] debug_fft_input2_written;
    wire [15:0] debug_fft_input16_written;
    wire [15:0] debug_fft_input64_written;
    wire [15:0] debug_fft_input128_written;
    wire [15:0] debug_fft_input255_written;
    wire debug_frame_result0_written;

    reg [7:0] payload_mem [0:MAX_PAYLOAD_LEN-1];
    reg [7:0] captured [0:255];
    integer captured_count = 0;
    integer errors = 0;
    integer i;
    integer wait_count;
    integer timeout_count;
    integer chunk_offset;
    integer outputs_ok = 1;

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
        .cpu_wr_en(frame_cpu_wr_en),
        .cpu_rd_en(frame_cpu_rd_en),
        .cpu_addr(frame_cpu_addr),
        .cpu_wdata(frame_cpu_wdata),
        .cpu_rdata(frame_cpu_rdata),
        .cpu_ready(frame_cpu_ready)
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

    mini_cpu_uart_frame_system #(
        .PROGRAM_ID(`MINI_CPU_PROGRAM_UART_FRAME_SERVICE)
    ) cpu_system_inst (
        .clk(clk),
        .rst(rst),
        .frame_cpu_wr_en(frame_cpu_wr_en),
        .frame_cpu_rd_en(frame_cpu_rd_en),
        .frame_cpu_addr(frame_cpu_addr),
        .frame_cpu_wdata(frame_cpu_wdata),
        .frame_cpu_rdata(frame_cpu_rdata),
        .frame_cpu_ready(frame_cpu_ready),
        .gpio_result(gpio_result),
        .cpu_halted(cpu_halted),
        .fft_busy(fft_busy),
        .fft_done(fft_done),
        .fft_overflow(fft_overflow),
        .fft_error(fft_error),
        .bus_addr_debug(bus_addr_debug),
        .bus_wdata_debug(bus_wdata_debug),
        .bus_we_debug(bus_we_debug),
        .bus_re_debug(bus_re_debug),
        .debug_pc(debug_pc),
        .debug_zero_flag(debug_zero_flag),
        .debug_reg0(debug_reg0),
        .debug_reg1(debug_reg1),
        .debug_reg2(debug_reg2),
        .debug_reg3(debug_reg3),
        .debug_reg4(debug_reg4),
        .debug_reg5(debug_reg5),
        .debug_reg6(debug_reg6),
        .debug_reg7(debug_reg7),
        .debug_saw_frame_request(debug_saw_frame_request),
        .debug_fft_start_written(debug_fft_start_written),
        .debug_fft_bass_gain_written(debug_fft_bass_gain_written),
        .debug_fft_mid_gain_written(debug_fft_mid_gain_written),
        .debug_fft_treble_gain_written(debug_fft_treble_gain_written),
        .debug_fft_input0_written(debug_fft_input0_written),
        .debug_fft_input1_written(debug_fft_input1_written),
        .debug_fft_input2_written(debug_fft_input2_written),
        .debug_fft_input16_written(debug_fft_input16_written),
        .debug_fft_input64_written(debug_fft_input64_written),
        .debug_fft_input128_written(debug_fft_input128_written),
        .debug_fft_input255_written(debug_fft_input255_written),
        .debug_frame_result0_written(debug_frame_result0_written)
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

    task set_payload_i16;
        input integer payload_offset;
        input signed [15:0] value;
        begin
            payload_mem[payload_offset] = value[7:0];
            payload_mem[payload_offset + 1] = value[15:8];
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

    task wait_for_done_status;
        begin
            timeout_count = 0;
            while ((status_debug & STATUS_DONE) == 8'd0 &&
                   timeout_count < TIMEOUT_CYCLES) begin
                @(posedge clk);
                #1;
                timeout_count = timeout_count + 1;
            end
        end
    endtask

    task send_impulse_chunk;
        input integer offset_value;
        input [7:0] seq_value;
        input signed [15:0] impulse_value;
        begin
            clear_payload();
            payload_mem[0] = offset_value[7:0];
            payload_mem[1] = offset_value[15:8];
            payload_mem[2] = 8'd32;

            for (i = 0; i < 32; i = i + 1) begin
                if (offset_value + i == 0) begin
                    set_payload_i16(3 + (i << 1), impulse_value);
                end else begin
                    set_payload_i16(3 + (i << 1), 16'sd0);
                end
            end

            send_packet(CMD_WRITE_FRAME_CHUNK, seq_value, 16'd67);
            wait_for_response(100);
        end
    endtask

    task upload_impulse_frame;
        input [7:0] seq_base;
        input signed [15:0] impulse_value;
        begin
            for (chunk_offset = 0; chunk_offset < 256;
                 chunk_offset = chunk_offset + 32) begin
                send_impulse_chunk(
                    chunk_offset,
                    seq_base + (chunk_offset >> 5),
                    impulse_value
                );
                report_result("write_frame_chunk_status",
                              response_packet_ok(
                                  RSP_STATUS,
                                  seq_base + (chunk_offset >> 5),
                                  1
                              ) && captured[5] == STATUS_INPUT_LOADED);
            end
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

    function integer sample_close;
        input signed [15:0] actual;
        input signed [15:0] expected;
        reg signed [16:0] diff;
        begin
            diff = {actual[15], actual} - {expected[15], expected};
            sample_close = (diff <= 17'sd2) && (diff >= -17'sd2);
        end
    endfunction

    task read_and_check_single;
        input [7:0] seq_value;
        input [15:0] offset_value;
        input signed [15:0] expected_value;
        input [8*40-1:0] name;
        begin
            clear_payload();
            payload_mem[0] = offset_value[7:0];
            payload_mem[1] = offset_value[15:8];
            payload_mem[2] = 8'd1;
            send_packet(CMD_READ_RESULT_CHUNK, seq_value, 16'd3);
            wait_for_response(120);
            if (!response_packet_ok(RSP_RESULT_CHUNK, seq_value, 6) ||
                !sample_close(payload_sample(4), expected_value)) begin
                outputs_ok = 0;
                $display("  %0s expected=%0d actual=%0d",
                         name, expected_value, payload_sample(4));
            end
        end
    endtask

    task run_frame_and_wait;
        input [7:0] run_seq;
        input [7:0] status_seq;
        begin
            send_packet(CMD_RUN_FRAME, run_seq, 16'd0);
            wait_for_response(100);
            report_result("run_sets_request",
                          response_packet_ok(RSP_STATUS, run_seq, 1) &&
                          captured[5] == STATUS_INPUT_LOADED);

            wait_for_done_status();
            report_result("service_loop_reaches_done",
                          (status_debug & STATUS_DONE) != 8'd0);
            report_result("service_loop_status_no_error_timeout",
                          (status_debug &
                           (STATUS_ERROR | STATUS_TIMEOUT)) == 8'd0);

            send_packet(CMD_GET_STATUS, status_seq, 16'd0);
            wait_for_response(100);
            report_result("get_status_done",
                          response_packet_ok(RSP_STATUS, status_seq, 1) &&
                          captured[5] ==
                              (STATUS_INPUT_LOADED | STATUS_DONE));
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
        $display("=== CPU OWNED UART FRAME SERVICE LOOP TEST ===");
        $display("FRAME=two_impulse_transactions");
        $display("OWNERSHIP=UART_TO_MAILBOX_CPU_TO_FFT");
        $display("");

        clear_payload();
        clear_capture();
        repeat (5) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        clear_payload();
        set_payload_i16(0, 16'sd16384);
        set_payload_i16(2, 16'sd16384);
        set_payload_i16(4, 16'sd16384);
        send_packet(CMD_SET_GAINS, 8'h01, 16'd6);
        wait_for_response(100);
        report_result("uart_writes_unity_gains",
                      response_packet_ok(RSP_STATUS, 8'h01, 1) &&
                      bass_gain_q2_14 == 16'd16384 &&
                      mid_gain_q2_14 == 16'd16384 &&
                      treble_gain_q2_14 == 16'd16384);

        upload_impulse_frame(8'h10, 16'sd64);

        debug_sample_rd_addr = 8'd0;
        #1;
        report_result("first_frame_input0", debug_input_sample == 16'sd64);
        debug_sample_rd_addr = 8'd1;
        #1;
        report_result("first_frame_input1", debug_input_sample == 16'sd0);
        report_result("first_frame_loaded", frame_loaded == 1'b1);

        send_packet(CMD_RUN_FRAME, 8'h30, 16'd0);
        wait_for_response(100);
        report_result("first_run_sets_request",
                      response_packet_ok(RSP_STATUS, 8'h30, 1) &&
                      captured[5] == STATUS_INPUT_LOADED);

        clear_payload();
        payload_mem[0] = 8'h00;
        payload_mem[1] = 8'h00;
        payload_mem[2] = 8'd1;
        send_packet(CMD_READ_RESULT_CHUNK, 8'h31, 16'd3);
        wait_for_response(100);
        report_result("read_before_done_rejected",
                      response_packet_ok(CMD_ERROR, 8'h31, 1) &&
                      captured[5] == CMD_READ_RESULT_CHUNK);

        wait_for_done_status();
        report_result("mini_cpu_detects_request",
                      debug_saw_frame_request == 1'b1);
        report_result("mini_cpu_writes_fft_gains",
                      debug_fft_bass_gain_written == 16'd16384 &&
                      debug_fft_mid_gain_written == 16'd16384 &&
                      debug_fft_treble_gain_written == 16'd16384);
        report_result("mini_cpu_writes_selected_fft_inputs",
                      debug_fft_input0_written == 16'sd64 &&
                      debug_fft_input1_written == 16'sd0 &&
                      debug_fft_input2_written == 16'sd0 &&
                      debug_fft_input16_written == 16'sd0 &&
                      debug_fft_input64_written == 16'sd0 &&
                      debug_fft_input128_written == 16'sd0 &&
                      debug_fft_input255_written == 16'sd0);
        report_result("mini_cpu_starts_fft", debug_fft_start_written == 1'b1);
        report_result("mini_cpu_writes_result_frame",
                      debug_frame_result0_written == 1'b1);
        report_result("mini_cpu_keeps_running_after_frame",
                      cpu_halted == 1'b0);
        report_result("first_status_done_no_error",
                      status_debug[2] == 1'b1 &&
                      status_debug[3] == 1'b0 &&
                      status_debug[4] == 1'b0);

        send_packet(CMD_GET_STATUS, 8'h40, 16'd0);
        wait_for_response(100);
        report_result("first_get_status_done",
                      response_packet_ok(RSP_STATUS, 8'h40, 1) &&
                      captured[5] == (STATUS_INPUT_LOADED | STATUS_DONE));

        outputs_ok = 1;
        read_and_check_single(8'h41, 16'd0, 16'sd64, "first_output0");
        read_and_check_single(8'h42, 16'd1, 16'sd0, "first_output1");
        read_and_check_single(8'h43, 16'd2, 16'sd0, "first_output2");
        read_and_check_single(8'h44, 16'd16, 16'sd0, "first_output16");
        read_and_check_single(8'h45, 16'd64, 16'sd0, "first_output64");
        read_and_check_single(8'h46, 16'd128, 16'sd0, "first_output128");
        read_and_check_single(8'h47, 16'd255, 16'sd0, "first_output255");
        report_result("first_read_result_selected_samples", outputs_ok);

        upload_impulse_frame(8'h50, 16'sd32);
        report_result("second_upload_clears_stale_done",
                      (status_debug & STATUS_DONE) == 8'd0 &&
                      frame_done == 1'b0);
        debug_sample_rd_addr = 8'd0;
        #1;
        report_result("second_frame_input0", debug_input_sample == 16'sd32);

        run_frame_and_wait(8'h70, 8'h71);
        report_result("second_transaction_cpu_still_running",
                      cpu_halted == 1'b0);

        outputs_ok = 1;
        read_and_check_single(8'h72, 16'd0, 16'sd32, "second_output0");
        read_and_check_single(8'h73, 16'd1, 16'sd0, "second_output1");
        read_and_check_single(8'h74, 16'd255, 16'sd0, "second_output255");
        report_result("second_read_result_selected_samples", outputs_ok);

        report_result("no_fft_error_outputs",
                      fft_overflow == 1'b0 &&
                      fft_error == 1'b0 &&
                      tx_error_length_too_large == 1'b0);

        $display("");
        if (errors == 0) begin
            $display("STATUS=PASS");
        end else begin
            $display("STATUS=FAIL errors=%0d", errors);
        end

        $finish;
    end

endmodule
