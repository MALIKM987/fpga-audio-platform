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
    localparam [7:0] STATUS_CPU_BUSY     = 8'h02;
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
    integer fft_start_write_count = 0;
    integer frame_done_write_count = 0;
    integer previous_fft_start_count;
    integer previous_frame_done_count;
    integer transaction_outputs_ok;
    reg [7:0] last_status_byte = 8'd0;
    reg busy_seen = 1'b0;
    reg stale_done_cleared = 1'b0;
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

    mini_cpu_uart_frame_system cpu_system_inst (
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

    task send_frame_chunk;
        input integer offset_value;
        input [7:0] seq_value;
        input integer impulse_index;
        input signed [15:0] impulse_value;
        begin
            clear_payload();
            payload_mem[0] = offset_value[7:0];
            payload_mem[1] = offset_value[15:8];
            payload_mem[2] = 8'd32;

            for (i = 0; i < 32; i = i + 1) begin
                if (offset_value + i == impulse_index) begin
                    set_payload_i16(3 + (i << 1), impulse_value);
                end else begin
                    set_payload_i16(3 + (i << 1), 16'sd0);
                end
            end

            send_packet(CMD_WRITE_FRAME_CHUNK, seq_value, 16'd67);
            wait_for_response(100);
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

    task get_status_packet;
        input [7:0] seq_value;
        begin
            send_packet(CMD_GET_STATUS, seq_value, 16'd0);
            wait_for_response(100);
            if (response_packet_ok(RSP_STATUS, seq_value, 1)) begin
                last_status_byte = captured[5];
            end else begin
                last_status_byte = 8'hFF;
            end
        end
    endtask

    task run_frame_transaction;
        input integer impulse_index;
        input signed [15:0] impulse_value;
        input [7:0] seq_base;
        input [8*40-1:0] name;
        begin
            previous_fft_start_count = fft_start_write_count;
            previous_frame_done_count = frame_done_write_count;
            transaction_outputs_ok = 1;
            busy_seen = 1'b0;
            stale_done_cleared = 1'b0;

            for (chunk_offset = 0; chunk_offset < 256;
                 chunk_offset = chunk_offset + 32) begin
                send_frame_chunk(
                    chunk_offset,
                    seq_base + 8'h10 + (chunk_offset >> 5),
                    impulse_index,
                    impulse_value
                );

                if (!response_packet_ok(
                        RSP_STATUS,
                        seq_base + 8'h10 + (chunk_offset >> 5),
                        1
                    ) || captured[5] != STATUS_INPUT_LOADED) begin
                    transaction_outputs_ok = 0;
                end

                if (captured[5] == STATUS_INPUT_LOADED) begin
                    stale_done_cleared = 1'b1;
                end
            end

            report_result({name, "_write_chunks"},
                          transaction_outputs_ok && stale_done_cleared);
            report_result({name, "_frame_loaded"}, frame_loaded == 1'b1);

            send_packet(CMD_RUN_FRAME, seq_base + 8'h30, 16'd0);
            wait_for_response(100);
            report_result({name, "_run_response"},
                          response_packet_ok(
                              RSP_STATUS,
                              seq_base + 8'h30,
                              1
                          ) && captured[5] == STATUS_INPUT_LOADED);

            get_status_packet(seq_base + 8'h31);
            report_result({name, "_status_clears_stale_done"},
                          (last_status_byte & STATUS_DONE) == 8'd0 &&
                          (last_status_byte & STATUS_ERROR) == 8'd0);

            timeout_count = 0;
            while ((last_status_byte & STATUS_DONE) == 8'd0 &&
                   timeout_count < TIMEOUT_CYCLES) begin
                if ((status_debug & STATUS_CPU_BUSY) != 8'd0) begin
                    busy_seen = 1'b1;
                end

                if ((timeout_count & 10'h03F) == 0) begin
                    get_status_packet(seq_base + 8'h40 + timeout_count[7:0]);
                end

                @(posedge clk);
                #1;
                timeout_count = timeout_count + 1;
            end

            if ((last_status_byte & STATUS_DONE) == 8'd0) begin
                get_status_packet(seq_base + 8'h7E);
            end

            report_result({name, "_busy_seen"}, busy_seen == 1'b1);
            report_result({name, "_done"},
                          (last_status_byte & STATUS_DONE) != 8'd0);
            report_result({name, "_idle_ready"},
                          (status_debug & STATUS_CPU_BUSY) == 8'd0 &&
                          cpu_halted == 1'b0);
            report_result({name, "_no_error_timeout"},
                          (last_status_byte &
                           (STATUS_ERROR | STATUS_TIMEOUT)) == 8'd0);
            report_result({name, "_fft_start_count"},
                          fft_start_write_count >
                          previous_fft_start_count);
            report_result({name, "_frame_done_count"},
                          frame_done_write_count >
                          previous_frame_done_count);

            outputs_ok = 1;
            read_and_check_single(
                seq_base + 8'h80,
                16'd0,
                (impulse_index == 0) ? impulse_value : 16'sd0,
                {name, "_out0"}
            );
            read_and_check_single(
                seq_base + 8'h81,
                16'd1,
                (impulse_index == 1) ? impulse_value : 16'sd0,
                {name, "_out1"}
            );
            read_and_check_single(
                seq_base + 8'h82,
                16'd2,
                (impulse_index == 2) ? impulse_value : 16'sd0,
                {name, "_out2"}
            );
            read_and_check_single(
                seq_base + 8'h83,
                16'd16,
                (impulse_index == 16) ? impulse_value : 16'sd0,
                {name, "_out16"}
            );
            read_and_check_single(
                seq_base + 8'h84,
                16'd64,
                (impulse_index == 64) ? impulse_value : 16'sd0,
                {name, "_out64"}
            );
            read_and_check_single(
                seq_base + 8'h85,
                16'd128,
                (impulse_index == 128) ? impulse_value : 16'sd0,
                {name, "_out128"}
            );
            read_and_check_single(
                seq_base + 8'h86,
                16'd255,
                (impulse_index == 255) ? impulse_value : 16'sd0,
                {name, "_out255"}
            );
            report_result({name, "_selected_outputs"}, outputs_ok);
        end
    endtask

    always @(posedge clk) begin
        #1;
        if (tx_valid) begin
            captured[captured_count] = tx_data;
            captured_count = captured_count + 1;
        end
    end

    always @(posedge clk) begin
        #1;
        if (!rst && bus_we_debug) begin
            if (bus_addr_debug == 16'h9000 && bus_wdata_debug[0]) begin
                fft_start_write_count = fft_start_write_count + 1;
            end

            if (bus_addr_debug == 16'hA001 && bus_wdata_debug[2]) begin
                frame_done_write_count = frame_done_write_count + 1;
            end
        end
    end

    initial begin
        $display("=== CPU OWNED UART FRAME FLOW TEST ===");
        $display("FRAME=impulse64");
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

        run_frame_transaction(0, 16'sd64, 8'h00, "frame0_impulse0");

        debug_sample_rd_addr = 8'd0;
        #1;
        report_result("frame0_uart_writes_input0",
                      debug_input_sample == 16'sd64);
        debug_sample_rd_addr = 8'd1;
        #1;
        report_result("frame0_uart_writes_input1",
                      debug_input_sample == 16'sd0);

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
        report_result("mini_cpu_service_loop_does_not_halt",
                      cpu_halted == 1'b0);
        report_result("mini_cpu_writes_result_frame",
                      debug_frame_result0_written == 1'b1);

        run_frame_transaction(16, 16'sd80, 8'h80, "frame1_impulse16");

        debug_sample_rd_addr = 8'd0;
        #1;
        report_result("frame1_clears_previous_output0",
                      debug_result_sample == 16'sd0);
        debug_sample_rd_addr = 8'd16;
        #1;
        report_result("frame1_writes_new_output16",
                      sample_close(debug_result_sample, 16'sd80));
        report_result("two_back_to_back_transactions",
                      fft_start_write_count >= 2 &&
                      frame_done_write_count >= 2 &&
                      cpu_halted == 1'b0);

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
