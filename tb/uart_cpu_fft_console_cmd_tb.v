`timescale 1ns/1ps

module uart_cpu_fft_console_cmd_tb;

    localparam integer CLK_FREQ_HZ = 1_000_000;
    localparam integer BAUD_RATE = 100_000;
    localparam integer CLKS_PER_BIT = CLK_FREQ_HZ / BAUD_RATE;

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
    integer accepted_count = 0;
    integer ignored_count = 0;
    integer wait_count = 0;

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
        begin
            @(negedge clk);
            uart_rx_line = 1'b0;
            repeat (CLKS_PER_BIT) @(posedge clk);

            for (i = 0; i < 8; i = i + 1) begin
                uart_rx_line = byte_value[i];
                repeat (CLKS_PER_BIT) @(posedge clk);
            end

            uart_rx_line = 1'b1;
            repeat (CLKS_PER_BIT) @(posedge clk);
        end
    endtask

    task send_packet;
        input [7:0] cmd;
        begin
            send_uart_byte(8'hA5);
            send_uart_byte(cmd);
            send_uart_byte(8'h5A);
        end
    endtask

    always @(posedge clk) begin
        #1;
        if (command_accepted) begin
            accepted_count = accepted_count + 1;
        end

        if (command_ignored) begin
            ignored_count = ignored_count + 1;
        end
    end

    initial begin
        $display("=== UART CPU FFT CONSOLE COMMAND TEST ===");
        $display("PROTOCOL=binary A5 01 5A");
        $display("");

        repeat (4) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        send_packet(8'h02);
        repeat (CLKS_PER_BIT * 8) @(posedge clk);
        report_result("invalid_command_ignored",
                      (accepted_count == 0) &&
                      (ignored_count >= 1) &&
                      (console_busy === 1'b0));

        send_packet(8'h01);
        wait_count = 0;
        while (accepted_count < 1 && wait_count < 2000) begin
            @(posedge clk);
            #1;
            wait_count = wait_count + 1;
        end

        report_result("valid_run_command_accepted", accepted_count == 1);
        report_result("console_busy_after_run", console_busy === 1'b1);

        send_packet(8'h01);
        wait_count = 0;
        while (ignored_count < 2 && wait_count < 5000) begin
            @(posedge clk);
            #1;
            wait_count = wait_count + 1;
        end

        report_result("busy_command_ignored", ignored_count >= 2);
        report_result("no_second_run_started", accepted_count == 1);

        $display("");
        if (errors == 0) begin
            $display("STATUS=PASS");
        end else begin
            $display("STATUS=FAIL errors=%0d", errors);
        end

        $finish;
    end

endmodule
