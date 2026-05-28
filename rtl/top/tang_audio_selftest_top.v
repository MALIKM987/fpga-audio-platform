module tang_audio_selftest_top #(
    parameter integer CLK_FREQ_HZ            = 27_000_000,
    parameter integer SAMPLE_RATE_HZ         = 48_000,
    parameter integer MODE_PERIOD_CYCLES     = 27_000_000,
    parameter integer ANALYZER_WINDOW_SAMPLES = 1024,
    parameter integer UART_BAUD_RATE         = 115_200,
    parameter integer HEARTBEAT_BIT          = 24
)(
    input  wire clk,
    input  wire rst,
    output wire uart_tx,
    output wire led_heartbeat,
    output wire led_clip,
    output wire [2:0] led_mode
);

    // Standalone diagnostic top for Tang Nano 20K.
    // No external audio hardware is required; UART carries text reports only.

    wire signed [15:0] test_sample;
    wire test_sample_valid;
    wire [2:0] mode;
    wire [3:0] volume_gain;
    wire signed [4:0] bass_gain;
    wire signed [4:0] mid_gain;
    wire signed [4:0] treble_gain;
    wire signed [15:0] processed_sample;
    wire processed_valid;
    wire clip;
    wire signed [15:0] in_min;
    wire signed [15:0] in_max;
    wire signed [15:0] out_min;
    wire signed [15:0] out_max;
    wire clip_seen;
    wire report_valid;
    wire [7:0] uart_data;
    wire uart_valid;
    wire uart_busy;

    reg [31:0] heartbeat_cnt;

    test_signal_gen #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .SAMPLE_RATE_HZ(SAMPLE_RATE_HZ)
    ) test_signal_gen_inst (
        .clk(clk),
        .rst(rst),
        .sample_out(test_sample),
        .sample_valid(test_sample_valid)
    );

    auto_param_controller #(
        .MODE_PERIOD_CYCLES(MODE_PERIOD_CYCLES)
    ) auto_param_controller_inst (
        .clk(clk),
        .rst(rst),
        .mode(mode),
        .volume_gain(volume_gain),
        .bass_gain(bass_gain),
        .mid_gain(mid_gain),
        .treble_gain(treble_gain)
    );

    modulation_core modulation_core_inst (
        .clk(clk),
        .rst(rst),
        .sample_in(test_sample),
        .sample_valid(test_sample_valid),
        .volume_gain_level(volume_gain),
        .bass_gain_level(bass_gain),
        .mid_gain_level(mid_gain),
        .treble_gain_level(treble_gain),
        .sample_out(processed_sample),
        .sample_out_valid(processed_valid),
        .clip(clip)
    );

    debug_analyzer #(
        .WINDOW_SAMPLES(ANALYZER_WINDOW_SAMPLES)
    ) debug_analyzer_inst (
        .clk(clk),
        .rst(rst),
        .sample_in(test_sample),
        .sample_out(processed_sample),
        .sample_valid(processed_valid),
        .clip(clip),
        .in_min(in_min),
        .in_max(in_max),
        .out_min(out_min),
        .out_max(out_max),
        .clip_seen(clip_seen),
        .report_valid(report_valid)
    );

    uart_debug_formatter uart_debug_formatter_inst (
        .clk(clk),
        .rst(rst),
        .report_valid(report_valid),
        .mode(mode),
        .volume_gain(volume_gain),
        .bass_gain(bass_gain),
        .mid_gain(mid_gain),
        .treble_gain(treble_gain),
        .in_min(in_min),
        .in_max(in_max),
        .out_min(out_min),
        .out_max(out_max),
        .clip_seen(clip_seen),
        .uart_busy(uart_busy),
        .uart_data(uart_data),
        .uart_valid(uart_valid)
    );

    uart_tx #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE(UART_BAUD_RATE)
    ) uart_tx_inst (
        .clk(clk),
        .rst(rst),
        .data(uart_data),
        .valid(uart_valid),
        .tx(uart_tx),
        .busy(uart_busy)
    );

    always @(posedge clk) begin
        if (rst) begin
            heartbeat_cnt <= 32'd0;
        end else begin
            heartbeat_cnt <= heartbeat_cnt + 32'd1;
        end
    end

    assign led_heartbeat = heartbeat_cnt[HEARTBEAT_BIT];
    assign led_clip      = clip | clip_seen;
    assign led_mode      = mode;

endmodule
