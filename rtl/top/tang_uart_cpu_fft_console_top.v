module tang_uart_cpu_fft_console_top #(
    parameter integer CLK_FREQ_HZ = 27_000_000,
    parameter integer BAUD_RATE = 115_200,
    parameter integer RESET_COUNT_MAX = 65535,
    parameter integer BLINK_COUNTER_WIDTH = 24,
    parameter integer LED_ACTIVE_LOW = 1
) (
    input  wire clk,
    input  wire uart_rx,
    output wire uart_tx,
    output wire led
);

    localparam integer FAST_BLINK_BIT = (BLINK_COUNTER_WIDTH > 4) ?
                                        (BLINK_COUNTER_WIDTH - 4) : 0;
    localparam integer SLOW_BLINK_BIT = BLINK_COUNTER_WIDTH - 1;

    reg [31:0] rst_cnt = 32'd0;
    reg rst = 1'b1;
    reg [BLINK_COUNTER_WIDTH-1:0] blink_counter =
        {BLINK_COUNTER_WIDTH{1'b0}};

    reg run_seen = 1'b0;
    reg pass_latched = 1'b0;
    reg fail_latched = 1'b0;

    wire console_busy;
    wire command_accepted;
    wire response_active;
    wire cpu_halted_debug;
    wire [15:0] gpio_result_debug;
    wire [15:0] unused_debug_out0;
    wire [15:0] unused_debug_out1;
    wire [15:0] unused_debug_out2;
    wire [15:0] unused_debug_out16;
    wire [15:0] unused_debug_out64;
    wire [15:0] unused_debug_out128;
    wire [15:0] unused_debug_out255;

    wire fast_blink = blink_counter[FAST_BLINK_BIT];
    wire slow_blink = blink_counter[SLOW_BLINK_BIT];
    wire led_raw;

    assign led_raw = console_busy || response_active ? fast_blink :
                     fail_latched ? slow_blink :
                     pass_latched ? 1'b1 :
                     slow_blink;

    assign led = LED_ACTIVE_LOW ? ~led_raw : led_raw;

    uart_cpu_fft_console #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE(BAUD_RATE)
    ) console_inst (
        .clk(clk),
        .rst(rst),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .console_busy(console_busy),
        .command_accepted(command_accepted),
        .command_ignored(),
        .response_active(response_active),
        .cpu_halted_debug(cpu_halted_debug),
        .gpio_result_debug(gpio_result_debug),
        .debug_out0(unused_debug_out0),
        .debug_out1(unused_debug_out1),
        .debug_out2(unused_debug_out2),
        .debug_out16(unused_debug_out16),
        .debug_out64(unused_debug_out64),
        .debug_out128(unused_debug_out128),
        .debug_out255(unused_debug_out255)
    );

    always @(posedge clk) begin
        blink_counter <= blink_counter + 1'b1;

        if (rst_cnt < RESET_COUNT_MAX) begin
            rst_cnt <= rst_cnt + 32'd1;
            rst <= 1'b1;
        end else begin
            rst <= 1'b0;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            run_seen <= 1'b0;
            pass_latched <= 1'b0;
            fail_latched <= 1'b0;
        end else begin
            if (command_accepted) begin
                run_seen <= 1'b1;
                pass_latched <= 1'b0;
                fail_latched <= 1'b0;
            end

            if (run_seen && cpu_halted_debug) begin
                run_seen <= 1'b0;

                if (gpio_result_debug == 16'h00A5) begin
                    pass_latched <= 1'b1;
                    fail_latched <= 1'b0;
                end else begin
                    pass_latched <= 1'b0;
                    fail_latched <= 1'b1;
                end
            end
        end
    end

endmodule
