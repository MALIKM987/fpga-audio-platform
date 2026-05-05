module tang_audio_eq_top #(
    parameter integer CLK_HZ              = 27000000,
    parameter integer BUTTON_DEBOUNCE_MS  = 20,
    parameter         BUTTON_ACTIVE_LEVEL = 1'b1,
    parameter integer HEARTBEAT_BIT       = 25
)(
    input  wire clk,
    input  wire rst,
    input  wire btn_vol_up,
    input  wire btn_vol_down,
    input  wire btn_bass_up,
    input  wire btn_bass_down,
    input  wire btn_mid_up,
    input  wire btn_mid_down,
    input  wire btn_treble_up,
    input  wire btn_treble_down,
    input  wire btn_channel_select,

    output wire I2S_BCLK,
    output wire I2S_LRCK,
    output wire I2S_DIN,
    output wire PA_SD,
    output wire led_heartbeat,
    output wire led_left_active,
    output wire led_right_active,
    output wire led_clip
);

    wire active_channel;
    wire [3:0] volume_L;
    wire [3:0] volume_R;
    wire signed [4:0] bass_gain_L;
    wire signed [4:0] bass_gain_R;
    wire signed [4:0] mid_gain_L;
    wire signed [4:0] mid_gain_R;
    wire signed [4:0] treble_gain_L;
    wire signed [4:0] treble_gain_R;

    wire signed [15:0] test_mix_sample;
    wire test_mix_valid;
    wire signed [15:0] eq_left_sample;
    wire signed [15:0] eq_right_sample;
    wire eq_valid;
    wire eq_clip_L;
    wire eq_clip_R;
    wire signed [15:0] volume_left_sample;
    wire signed [15:0] volume_right_sample;
    wire volume_left_valid;
    wire volume_right_valid;
    reg [HEARTBEAT_BIT:0] heartbeat_count;

    assign PA_SD = 1'b1;
    assign led_heartbeat = heartbeat_count[HEARTBEAT_BIT];
    assign led_clip = eq_clip_L | eq_clip_R;

    always @(posedge clk) begin
        if (rst)
            heartbeat_count <= {(HEARTBEAT_BIT + 1){1'b0}};
        else
            heartbeat_count <= heartbeat_count + 1'b1;
    end

    button_control_top #(
        .CLK_HZ(CLK_HZ),
        .DEBOUNCE_MS(BUTTON_DEBOUNCE_MS),
        .BUTTON_ACTIVE_LEVEL(BUTTON_ACTIVE_LEVEL)
    ) u_button_control_top (
        .clk(clk),
        .rst(rst),
        .btn_vol_up(btn_vol_up),
        .btn_vol_down(btn_vol_down),
        .btn_bass_up(btn_bass_up),
        .btn_bass_down(btn_bass_down),
        .btn_mid_up(btn_mid_up),
        .btn_mid_down(btn_mid_down),
        .btn_treble_up(btn_treble_up),
        .btn_treble_down(btn_treble_down),
        .btn_channel_select(btn_channel_select),
        .active_channel(active_channel),
        .led_left_active(led_left_active),
        .led_right_active(led_right_active),
        .volume_L(volume_L),
        .volume_R(volume_R),
        .bass_gain_L(bass_gain_L),
        .bass_gain_R(bass_gain_R),
        .mid_gain_L(mid_gain_L),
        .mid_gain_R(mid_gain_R),
        .treble_gain_L(treble_gain_L),
        .treble_gain_R(treble_gain_R)
    );

    test_mix_gen #(
        .CLK_FREQ_HZ(CLK_HZ),
        .LOW_FREQ_HZ(100),
        .MID_FREQ_HZ(1000),
        .HIGH_FREQ_HZ(6000)
    ) u_test_mix_gen (
        .clk(clk),
        .rst(rst),
        .sample_out(test_mix_sample),
        .sample_valid(test_mix_valid)
    );

    // First working DAFX/EQ path in the time domain.
    // Bass/mid/treble controls already affect audio samples here.
    // FFT/IFFT is still not implemented and remains a future accelerator stage.
    eq3band_stereo u_eq3band_stereo (
        .clk(clk),
        .rst(rst),
        .sample_left_in(test_mix_sample),
        .sample_right_in(test_mix_sample),
        .sample_valid(test_mix_valid),
        .bass_gain_L(bass_gain_L),
        .mid_gain_L(mid_gain_L),
        .treble_gain_L(treble_gain_L),
        .bass_gain_R(bass_gain_R),
        .mid_gain_R(mid_gain_R),
        .treble_gain_R(treble_gain_R),
        .sample_left_out(eq_left_sample),
        .sample_right_out(eq_right_sample),
        .sample_out_valid(eq_valid),
        .clip_L(eq_clip_L),
        .clip_R(eq_clip_R)
    );

    volume_control u_volume_left (
        .clk(clk),
        .rst(rst),
        .sample_in(eq_left_sample),
        .sample_valid(eq_valid),
        .volume_level(volume_L),
        .sample_out(volume_left_sample),
        .sample_out_valid(volume_left_valid)
    );

    volume_control u_volume_right (
        .clk(clk),
        .rst(rst),
        .sample_in(eq_right_sample),
        .sample_valid(eq_valid),
        .volume_level(volume_R),
        .sample_out(volume_right_sample),
        .sample_out_valid(volume_right_valid)
    );

    i2s_tx #(
        .CLK_FREQ_HZ(CLK_HZ),
        .SAMPLE_RATE_HZ(48000),
        .SAMPLE_WIDTH(16),
        .USE_STEREO_INPUTS(1)
    ) u_i2s_tx (
        .clk(clk),
        .rst(rst),
        .sample_in(volume_left_sample),
        .sample_left(volume_left_sample),
        .sample_right(volume_right_sample),
        .bclk(I2S_BCLK),
        .lrck(I2S_LRCK),
        .sdata(I2S_DIN)
    );

endmodule
