`timescale 1ns/1ps

module uart_cpu_fft_console_e2e_tb;

    localparam integer CLK_FREQ_HZ = 1_000_000;
    localparam integer BAUD_RATE = 100_000;
    localparam integer CLKS_PER_BIT = CLK_FREQ_HZ / BAUD_RATE;
    localparam integer RESPONSE_LEN = 18;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg uart_rx_line = 1'b1;
    wire uart_tx_line;
    wire console_busy;
    wire command_accepted;
    wire command_ignored;
    wire response_active;
    wire cpu_halted_debug;
    wire [15:0] gpio_result_debug;
    wire [15:0] debug_out0;
    wire [15:0] debug_out1;
    wire [15:0] debug_out2;
    wire [15:0] debug_out16;
    wire [15:0] debug_out64;
    wire [15:0] debug_out128;
    wire [15:0] debug_out255;

    integer errors = 0;
    integer i;
    integer wait_guard;
    integer response_seen;
    reg [7:0] response [0:RESPONSE_LEN-1];
    reg stop_bit;
    reg outputs_ok;

    uart_cpu_fft_console #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE(BAUD_RATE),
        .TIMEOUT_CYCLES(500000)
    ) dut (
        .clk(clk),
        .rst(rst),
        .uart_rx(uart_rx_line),
        .uart_tx(uart_tx_line),
        .console_busy(console_busy),
        .command_accepted(command_accepted),
        .command_ignored(command_ignored),
        .response_active(response_active),
        .cpu_halted_debug(cpu_halted_debug),
        .gpio_result_debug(gpio_result_debug),
        .debug_out0(debug_out0),
        .debug_out1(debug_out1),
        .debug_out2(debug_out2),
        .debug_out16(debug_out16),
        .debug_out64(debug_out64),
        .debug_out128(debug_out128),
        .debug_out255(debug_out255)
    );

    always #5 clk = ~clk;

    task report_result;
        input [8*56-1:0] name;
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
            uart_rx_line = 1'b0;
            repeat (CLKS_PER_BIT) @(posedge clk);

            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                uart_rx_line = byte_value[bit_index];
                repeat (CLKS_PER_BIT) @(posedge clk);
            end

            uart_rx_line = 1'b1;
            repeat (CLKS_PER_BIT) @(posedge clk);
        end
    endtask

    task send_run_packet;
        begin
            send_uart_byte(8'hA5);
            send_uart_byte(8'h01);
            send_uart_byte(8'h5A);
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

            while (uart_tx_line !== 1'b1 && wait_guard < 5000) begin
                @(posedge clk);
                wait_guard = wait_guard + 1;
            end

            while (uart_tx_line === 1'b1 && wait_guard < 5000) begin
                @(posedge clk);
                wait_guard = wait_guard + 1;
            end

            if (wait_guard >= 5000) begin
                byte_value = 8'h00;
                stop_value = 1'b0;
            end else begin
                repeat (CLKS_PER_BIT / 2) @(posedge clk);

                if (uart_tx_line !== 1'b0) begin
                    byte_value = 8'h00;
                    stop_value = 1'b0;
                end else begin
                    repeat (CLKS_PER_BIT) @(posedge clk);

                    for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                        byte_value[bit_index] = uart_tx_line;
                        repeat (CLKS_PER_BIT) @(posedge clk);
                    end

                    stop_value = uart_tx_line;
                    @(posedge clk);
                end
            end
        end
    endtask

    function signed [15:0] sample_from_response;
        input integer byte_index;
        begin
            sample_from_response = {response[byte_index + 1],
                                    response[byte_index]};
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

    task check_sample;
        input [8*16-1:0] name;
        input integer byte_index;
        input signed [15:0] expected;
        reg signed [15:0] actual;
        begin
            actual = sample_from_response(byte_index);

            if (!sample_close(actual, expected)) begin
                outputs_ok = 1'b0;
                $display("  %0s expected=%0d actual=%0d",
                         name, expected, actual);
            end
        end
    endtask

    initial begin
        $display("=== UART CPU FFT CONSOLE E2E TEST ===");
        $display("PROTOCOL=binary");
        $display("");

        repeat (4) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        send_run_packet();

        wait_guard = 0;
        response_seen = 0;
        while (!response_seen && wait_guard < 650000) begin
            @(posedge clk);
            #1;
            wait_guard = wait_guard + 1;

            if (response_active) begin
                response_seen = 1;
            end
        end

        report_result("response_started", response_seen == 1);

        if (response_seen) begin
            for (i = 0; i < RESPONSE_LEN; i = i + 1) begin
                receive_uart_byte(response[i], stop_bit);
                if (stop_bit !== 1'b1) begin
                    errors = errors + 1;
                    $display("TEST uart_stop_bit_%0d FAIL", i);
                end
            end
        end else begin
            for (i = 0; i < RESPONSE_LEN; i = i + 1) begin
                response[i] = 8'h00;
            end
        end

        report_result("response_start", response[0] === 8'hA5);
        report_result("response_id", response[1] === 8'h81);
        report_result("response_end", response[17] === 8'h5A);
        report_result("status_pass", response[2][0] === 1'b1);
        report_result("status_done", response[2][1] === 1'b1);
        report_result("status_no_overflow", response[2][2] === 1'b0);
        report_result("status_no_error", response[2][3] === 1'b0);
        report_result("status_no_timeout", response[2][4] === 1'b0);

        outputs_ok = 1'b1;
        check_sample("out0", 3, 16'sd64);
        check_sample("out1", 5, 16'sd0);
        check_sample("out2", 7, 16'sd0);
        check_sample("out16", 9, 16'sd0);
        check_sample("out64", 11, 16'sd0);
        check_sample("out128", 13, 16'sd0);
        check_sample("out255", 15, 16'sd0);
        report_result("selected_output_samples", outputs_ok);

        $display("");
        if (errors == 0) begin
            $display("STATUS=PASS");
        end else begin
            $display("STATUS=FAIL errors=%0d", errors);
        end

        $finish;
    end

endmodule
