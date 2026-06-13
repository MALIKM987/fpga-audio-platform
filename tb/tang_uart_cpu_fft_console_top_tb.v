`timescale 1ns/1ps

module tang_uart_cpu_fft_console_top_tb;

    localparam integer CLK_FREQ_HZ = 1_000_000;
    localparam integer BAUD_RATE = 100_000;
    localparam integer CLKS_PER_BIT = CLK_FREQ_HZ / BAUD_RATE;
    localparam integer RESPONSE_LEN = 18;
    localparam integer UART_WAIT_TIMEOUT = 700000;

    reg clk = 1'b0;
    reg uart_rx = 1'b1;
    wire uart_tx;
    wire led;

    integer errors = 0;
    integer wait_guard;
    integer i;
    reg [7:0] response [0:RESPONSE_LEN-1];
    reg stop_bit;
    reg outputs_ok;

    tang_uart_cpu_fft_console_top #(
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

            while (uart_tx !== 1'b1 && wait_guard < UART_WAIT_TIMEOUT) begin
                @(posedge clk);
                wait_guard = wait_guard + 1;
            end

            while (uart_tx === 1'b1 && wait_guard < UART_WAIT_TIMEOUT) begin
                @(posedge clk);
                wait_guard = wait_guard + 1;
            end

            if (wait_guard >= UART_WAIT_TIMEOUT) begin
                byte_value = 8'h00;
                stop_value = 1'b0;
            end else begin
                repeat (CLKS_PER_BIT / 2) @(posedge clk);

                if (uart_tx !== 1'b0) begin
                    byte_value = 8'h00;
                    stop_value = 1'b0;
                end else begin
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
        $display("=== TANG UART CPU FFT CONSOLE TOP TEST ===");
        $display("PROTOCOL=binary");
        $display("LED=active_low");
        $display("");

        repeat (2) @(posedge clk);
        #1;
        report_result("power_on_reset", dut.rst === 1'b1);
        report_result("uart_tx_idle_high", uart_tx === 1'b1);

        repeat (8) @(posedge clk);
        #1;
        report_result("reset_released", dut.rst === 1'b0);

        send_run_packet();

        for (i = 0; i < RESPONSE_LEN; i = i + 1) begin
            receive_uart_byte(response[i], stop_bit);
            if (stop_bit !== 1'b1) begin
                errors = errors + 1;
                $display("TEST uart_stop_bit_%0d FAIL", i);
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

        repeat (4) @(posedge clk);
        #1;
        report_result("led_pass_active_low", led === 1'b0);

        $display("");
        if (errors == 0) begin
            $display("STATUS=PASS");
        end else begin
            $display("STATUS=FAIL errors=%0d", errors);
        end

        $finish;
    end

endmodule
