`timescale 1ns/1ps

module tang_cpu_owned_frame_uart_top_tb;

    localparam integer CLK_FREQ_HZ = 1_000_000;
    localparam integer BAUD_RATE = 100_000;
    localparam integer CLKS_PER_BIT = CLK_FREQ_HZ / BAUD_RATE;
    localparam integer UART_WAIT_TIMEOUT = 50000;
    localparam integer POLL_LIMIT = 500;

    localparam [7:0] CMD_PING              = 8'h10;
    localparam [7:0] CMD_SET_GAINS         = 8'h11;
    localparam [7:0] CMD_WRITE_FRAME_CHUNK = 8'h12;
    localparam [7:0] CMD_RUN_FRAME         = 8'h13;
    localparam [7:0] CMD_READ_RESULT_CHUNK = 8'h14;
    localparam [7:0] CMD_GET_STATUS        = 8'h15;

    localparam [7:0] RSP_PONG         = 8'h90;
    localparam [7:0] RSP_RESULT_CHUNK = 8'h94;
    localparam [7:0] RSP_STATUS       = 8'h95;

    localparam [7:0] STATUS_INPUT_LOADED = 8'h01;
    localparam [7:0] STATUS_CPU_BUSY     = 8'h02;
    localparam [7:0] STATUS_DONE         = 8'h04;
    localparam [7:0] STATUS_ERROR        = 8'h08;
    localparam [7:0] STATUS_TIMEOUT      = 8'h10;

    reg clk = 1'b0;
    reg uart_rx = 1'b1;
    wire uart_tx;
    wire led;

    reg [7:0] captured [0:255];
    reg [7:0] tx_checksum = 8'd0;
    reg [7:0] status_byte = 8'd0;
    reg stop_bit = 1'b0;
    reg outputs_ok = 1'b1;
    reg packet_timeout = 1'b0;
    integer captured_count = 0;
    integer errors = 0;
    integer wait_guard = 0;
    integer i;
    integer chunk_offset;
    integer poll_count;
    integer rx_byte_count = 0;
    integer packet_valid_count = 0;
    integer backend_tx_start_count = 0;
    integer packet_tx_valid_count = 0;
    integer uart_tx_byte_valid_count = 0;

    tang_cpu_owned_frame_uart_top #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE(BAUD_RATE),
        .RESET_COUNT_MAX(4),
        .BLINK_COUNTER_WIDTH(8),
        .LED_ACTIVE_LOW(1)
    ) dut (
        .clk(clk),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .led(led)
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (dut.rx_byte_valid) begin
            rx_byte_count = rx_byte_count + 1;
        end
        if (dut.packet_valid) begin
            packet_valid_count = packet_valid_count + 1;
        end
        if (dut.backend_tx_start) begin
            backend_tx_start_count = backend_tx_start_count + 1;
        end
        if (dut.packet_tx_valid) begin
            packet_tx_valid_count = packet_tx_valid_count + 1;
        end
        if (dut.uart_tx_byte_valid) begin
            uart_tx_byte_valid_count = uart_tx_byte_valid_count + 1;
        end
    end

    task report_result;
        input [8*72-1:0] name;
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

    task send_uart_byte;
        input [7:0] byte_value;
        integer bit_index;
        begin
            @(negedge clk);
            uart_rx = 1'b0;
            repeat (CLKS_PER_BIT) @(posedge clk);

            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                uart_rx = byte_value[bit_index];
                repeat (CLKS_PER_BIT) @(posedge clk);
            end

            uart_rx = 1'b1;
            repeat (CLKS_PER_BIT) @(posedge clk);
        end
    endtask

    task receive_uart_byte;
        output [7:0] byte_value;
        output stop_value;
        integer bit_index;
        begin
            wait_guard = 0;
            byte_value = 8'h00;
            stop_value = 1'b0;

            while (uart_tx !== 1'b1 && wait_guard < UART_WAIT_TIMEOUT) begin
                @(posedge clk);
                wait_guard = wait_guard + 1;
            end

            while (uart_tx === 1'b1 && wait_guard < UART_WAIT_TIMEOUT) begin
                @(posedge clk);
                wait_guard = wait_guard + 1;
            end

            if (wait_guard < UART_WAIT_TIMEOUT) begin
                repeat (CLKS_PER_BIT / 2) @(posedge clk);

                if (uart_tx === 1'b0) begin
                    repeat (CLKS_PER_BIT) @(posedge clk);

                    for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                        byte_value[bit_index] = uart_tx;
                        repeat (CLKS_PER_BIT) @(posedge clk);
                    end

                    stop_value = uart_tx;
                    @(posedge clk);
                end
            end
        end
    endtask

    task clear_capture;
        integer capture_index;
        begin
            captured_count = 0;
            for (capture_index = 0; capture_index < 256;
                 capture_index = capture_index + 1) begin
                captured[capture_index] = 8'd0;
            end
        end
    endtask

    task send_header;
        input [7:0] cmd_value;
        input [7:0] seq_value;
        input [15:0] len_value;
        begin
            tx_checksum = cmd_value + seq_value + len_value[7:0] +
                          len_value[15:8];
            send_uart_byte(8'hA5);
            send_uart_byte(cmd_value);
            send_uart_byte(seq_value);
            send_uart_byte(len_value[7:0]);
            send_uart_byte(len_value[15:8]);
        end
    endtask

    task send_payload_byte;
        input [7:0] byte_value;
        begin
            tx_checksum = tx_checksum + byte_value;
            send_uart_byte(byte_value);
        end
    endtask

    task finish_packet;
        begin
            send_uart_byte(tx_checksum);
            send_uart_byte(8'h5A);
        end
    endtask

    task send_no_payload_packet;
        input [7:0] cmd_value;
        input [7:0] seq_value;
        begin
            send_header(cmd_value, seq_value, 16'd0);
            finish_packet();
        end
    endtask

    task send_i16_payload;
        input signed [15:0] value;
        begin
            send_payload_byte(value[7:0]);
            send_payload_byte(value[15:8]);
        end
    endtask

    task send_set_gains_packet;
        input [7:0] seq_value;
        begin
            send_header(CMD_SET_GAINS, seq_value, 16'd6);
            send_i16_payload(16'sd16384);
            send_i16_payload(16'sd16384);
            send_i16_payload(16'sd16384);
            finish_packet();
        end
    endtask

    task send_write_chunk_packet;
        input integer offset_value;
        input [7:0] seq_value;
        input integer impulse_index;
        input signed [15:0] impulse_value;
        reg signed [15:0] sample_value;
        integer sample_index;
        begin
            send_header(CMD_WRITE_FRAME_CHUNK, seq_value, 16'd67);
            send_payload_byte(offset_value[7:0]);
            send_payload_byte(offset_value[15:8]);
            send_payload_byte(8'd32);

            for (sample_index = 0; sample_index < 32;
                 sample_index = sample_index + 1) begin
                if (offset_value + sample_index == impulse_index) begin
                    sample_value = impulse_value;
                end else begin
                    sample_value = 16'sd0;
                end

                send_i16_payload(sample_value);
            end

            finish_packet();
        end
    endtask

    task send_read_result_packet;
        input [15:0] offset_value;
        input [7:0] seq_value;
        begin
            send_header(CMD_READ_RESULT_CHUNK, seq_value, 16'd3);
            send_payload_byte(offset_value[7:0]);
            send_payload_byte(offset_value[15:8]);
            send_payload_byte(8'd1);
            finish_packet();
        end
    endtask

    task receive_response_packet;
        integer payload_len;
        integer byte_index;
        begin
            clear_capture();
            packet_timeout = 1'b0;

            for (byte_index = 0; byte_index < 5; byte_index = byte_index + 1) begin
                receive_uart_byte(captured[byte_index], stop_bit);
                if (stop_bit !== 1'b1) begin
                    packet_timeout = 1'b1;
                end
            end

            payload_len = captured[3] | (captured[4] << 8);
            captured_count = 5 + payload_len + 2;

            if (!packet_timeout && captured_count <= 256) begin
                for (byte_index = 5; byte_index < captured_count;
                     byte_index = byte_index + 1) begin
                    receive_uart_byte(captured[byte_index], stop_bit);
                    if (stop_bit !== 1'b1) begin
                        packet_timeout = 1'b1;
                    end
                end
            end else begin
                packet_timeout = 1'b1;
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

    task send_and_check_status_packet;
        input [7:0] cmd_value;
        input [7:0] seq_value;
        input [8*64-1:0] name;
        begin
            send_no_payload_packet(cmd_value, seq_value);
            receive_response_packet();
            status_byte = captured[5];
            report_result(name, response_packet_ok(RSP_STATUS, seq_value, 1));
        end
    endtask

    task read_and_check_sample;
        input [15:0] offset_value;
        input [7:0] seq_value;
        input signed [15:0] expected_value;
        input [8*32-1:0] name;
        reg signed [15:0] actual_value;
        begin
            send_read_result_packet(offset_value, seq_value);
            receive_response_packet();
            actual_value = payload_sample(4);

            if (!response_packet_ok(RSP_RESULT_CHUNK, seq_value, 6) ||
                captured[8] !== 8'd1 ||
                !sample_close(actual_value, expected_value)) begin
                outputs_ok = 1'b0;
                $display("  %0s expected=%0d actual=%0d",
                         name, expected_value, actual_value);
            end
        end
    endtask

    initial begin
        $display("=== TANG CPU-OWNED FRAME UART TOP TEST ===");
        $display("PROTOCOL=UART_FRAME_FULL_256_SAMPLE_FLOW");
        $display("OWNERSHIP=UART_MAILBOX_TO_MINI_CPU_TO_FFT_MMIO");
        $display("LED=active_low");
        $display("");

        repeat (2) @(posedge clk);
        #1;
        report_result("power_on_reset", dut.rst === 1'b1);
        report_result("uart_tx_idle_high", uart_tx === 1'b1);

        repeat (8) @(posedge clk);
        #1;
        report_result("reset_released", dut.rst === 1'b0);

        send_no_payload_packet(CMD_PING, 8'h00);
        receive_response_packet();
        report_result("ping_returns_pong",
                      !packet_timeout &&
                      response_packet_ok(RSP_PONG, 8'h00, 0));

        if (packet_timeout || !response_packet_ok(RSP_PONG, 8'h00, 0)) begin
            $display("  debug rx_byte_count=%0d packet_valid_count=%0d backend_tx_start_count=%0d packet_tx_valid_count=%0d uart_tx_byte_valid_count=%0d",
                     rx_byte_count,
                     packet_valid_count,
                     backend_tx_start_count,
                     packet_tx_valid_count,
                     uart_tx_byte_valid_count);
            $display("");
            $display("STATUS=FAIL errors=%0d", errors);
            $finish;
        end

        send_set_gains_packet(8'h01);
        receive_response_packet();
        report_result("set_gains_response",
                      response_packet_ok(RSP_STATUS, 8'h01, 1));
        report_result("set_gains_values",
                      dut.bass_gain_q2_14 == 16'd16384 &&
                      dut.mid_gain_q2_14 == 16'd16384 &&
                      dut.treble_gain_q2_14 == 16'd16384);

        for (chunk_offset = 0; chunk_offset < 256;
             chunk_offset = chunk_offset + 32) begin
            send_write_chunk_packet(
                chunk_offset,
                8'h10 + (chunk_offset >> 5),
                0,
                16'sd64
            );
            receive_response_packet();
            report_result("write_frame_chunk_status",
                          response_packet_ok(
                              RSP_STATUS,
                              8'h10 + (chunk_offset >> 5),
                              1
                          ) && captured[5] == STATUS_INPUT_LOADED);
        end

        report_result("frame_loaded", dut.frame_loaded === 1'b1);

        send_and_check_status_packet(CMD_RUN_FRAME, 8'h30, "run_frame_response");
        report_result("run_sets_request_or_input_loaded",
                      (status_byte & STATUS_INPUT_LOADED) != 8'd0);

        poll_count = 0;
        while ((status_byte & STATUS_DONE) == 8'd0 &&
               poll_count < POLL_LIMIT) begin
            send_and_check_status_packet(
                CMD_GET_STATUS,
                8'h40 + poll_count[7:0],
                "get_status_response"
            );
            poll_count = poll_count + 1;
        end

        report_result("poll_until_done", (status_byte & STATUS_DONE) != 8'd0);
        report_result("status_no_error_timeout",
                      (status_byte & (STATUS_ERROR | STATUS_TIMEOUT)) == 8'd0);
        report_result("mini_cpu_controls_fft",
                      dut.debug_saw_frame_request === 1'b1 &&
                      dut.debug_fft_start_written === 1'b1 &&
                      dut.debug_frame_result0_written === 1'b1);

        outputs_ok = 1'b1;
        read_and_check_sample(16'd0, 8'h80, 16'sd64, "out0");
        read_and_check_sample(16'd1, 8'h81, 16'sd0, "out1");
        read_and_check_sample(16'd2, 8'h82, 16'sd0, "out2");
        read_and_check_sample(16'd16, 8'h83, 16'sd0, "out16");
        read_and_check_sample(16'd64, 8'h84, 16'sd0, "out64");
        read_and_check_sample(16'd128, 8'h85, 16'sd0, "out128");
        read_and_check_sample(16'd255, 8'h86, 16'sd0, "out255");
        report_result("read_selected_result_samples", outputs_ok);

        outputs_ok = 1'b1;
        for (chunk_offset = 0; chunk_offset < 256;
             chunk_offset = chunk_offset + 32) begin
            send_write_chunk_packet(
                chunk_offset,
                8'h90 + (chunk_offset >> 5),
                16,
                16'sd80
            );
            receive_response_packet();
            report_result("second_write_frame_chunk_status",
                          response_packet_ok(
                              RSP_STATUS,
                              8'h90 + (chunk_offset >> 5),
                              1
                          ) && captured[5] == STATUS_INPUT_LOADED);
        end

        send_and_check_status_packet(
            CMD_RUN_FRAME,
            8'hB0,
            "second_run_frame_response"
        );
        report_result("second_run_clears_stale_done",
                      (status_byte & STATUS_DONE) == 8'd0 &&
                      (status_byte & STATUS_INPUT_LOADED) != 8'd0);

        poll_count = 0;
        while ((status_byte & STATUS_DONE) == 8'd0 &&
               poll_count < POLL_LIMIT) begin
            send_and_check_status_packet(
                CMD_GET_STATUS,
                8'hC0 + poll_count[7:0],
                "second_get_status_response"
            );
            poll_count = poll_count + 1;
        end

        report_result("second_poll_until_done",
                      (status_byte & STATUS_DONE) != 8'd0);
        report_result("second_status_no_error_timeout",
                      (status_byte & (STATUS_ERROR | STATUS_TIMEOUT)) == 8'd0);

        read_and_check_sample(16'd0, 8'hD0, 16'sd0, "second_out0");
        read_and_check_sample(16'd16, 8'hD1, 16'sd80, "second_out16");
        read_and_check_sample(16'd64, 8'hD2, 16'sd0, "second_out64");
        read_and_check_sample(16'd255, 8'hD3, 16'sd0, "second_out255");
        report_result("second_read_selected_result_samples", outputs_ok);
        report_result("two_uart_transactions_without_reset",
                      dut.cpu_halted === 1'b0 &&
                      dut.status_debug[2] === 1'b1 &&
                      dut.status_debug[3] === 1'b0);

        repeat (4) @(posedge clk);
        #1;
        report_result("led_pass_active_low", led === 1'b0);

        report_result("no_fft_overflow_error",
                      dut.fft_overflow === 1'b0 &&
                      dut.fft_error === 1'b0);

        $display("");
        if (errors == 0) begin
            $display("STATUS=PASS");
        end else begin
            $display("STATUS=FAIL errors=%0d", errors);
        end

        $finish;
    end

endmodule
