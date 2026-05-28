`timescale 1ns/1ps

module tang_audio_selftest_top_tb;
    reg clk;
    reg rst;
    wire uart_tx;
    wire led_heartbeat;
    wire led_clip;
    wire [2:0] led_mode;

    integer fail;
    integer sample_seen;
    integer mode_change_seen;
    integer uart_activity_seen;
    integer processed_change_seen;
    integer clip_seen;
    integer heartbeat_seen;
    reg uart_tx_prev;
    reg heartbeat_prev;
    reg [2:0] mode_prev;
    integer i;

    tang_audio_selftest_top #(
        .CLK_FREQ_HZ(1000),
        .SAMPLE_RATE_HZ(100),
        .MODE_PERIOD_CYCLES(50),
        .ANALYZER_WINDOW_SAMPLES(8),
        .UART_BAUD_RATE(100),
        .HEARTBEAT_BIT(6)
    ) dut (
        .clk(clk),
        .rst(rst),
        .uart_tx(uart_tx),
        .led_heartbeat(led_heartbeat),
        .led_clip(led_clip),
        .led_mode(led_mode)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst = 1'b1;
        fail = 0;
        sample_seen = 0;
        mode_change_seen = 0;
        uart_activity_seen = 0;
        processed_change_seen = 0;
        clip_seen = 0;
        heartbeat_seen = 0;
        uart_tx_prev = 1'b1;
        heartbeat_prev = 1'b0;
        mode_prev = 3'd0;

        repeat (5) @(posedge clk);
        rst = 1'b0;
        uart_tx_prev = uart_tx;
        heartbeat_prev = led_heartbeat;
        mode_prev = led_mode;

        for (i = 0; i < 25000; i = i + 1) begin
            @(posedge clk);
            #1;
            if (dut.test_sample_valid) sample_seen = 1;
            if (led_mode != mode_prev) mode_change_seen = 1;
            if (uart_tx != uart_tx_prev) uart_activity_seen = 1;
            if (led_heartbeat != heartbeat_prev) heartbeat_seen = 1;
            if (dut.processed_valid && dut.processed_sample != dut.test_sample && led_mode != 3'd0) begin
                processed_change_seen = 1;
            end
            if (led_clip) clip_seen = 1;
            uart_tx_prev = uart_tx;
            heartbeat_prev = led_heartbeat;
            mode_prev = led_mode;
        end

        if (!sample_seen) begin
            $display("FAIL: selftest top did not generate samples");
            fail = 1;
        end
        if (!mode_change_seen) begin
            $display("FAIL: selftest top mode did not change");
            fail = 1;
        end
        if (!processed_change_seen) begin
            $display("FAIL: modulation did not change samples after parameter change");
            fail = 1;
        end
        if (!clip_seen) begin
            $display("FAIL: clipping was not observed in selftest mode");
            fail = 1;
        end
        if (!uart_activity_seen) begin
            $display("FAIL: UART TX did not toggle");
            fail = 1;
        end
        if (!heartbeat_seen) begin
            $display("FAIL: heartbeat LED did not toggle");
            fail = 1;
        end

        if (fail) begin
            $display("tang_audio_selftest_top_tb FAIL");
        end else begin
            $display("tang_audio_selftest_top_tb PASS");
        end
        $finish;
    end
endmodule
