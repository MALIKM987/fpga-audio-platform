module tang_audio_control_top #(
    parameter integer CLK_HZ              = 27000000,
    parameter integer BUTTON_DEBOUNCE_MS  = 20,
    parameter         BUTTON_ACTIVE_LEVEL = 1'b1
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
    output wire led_right_active
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

    wire signed [15:0] tone_sample;
    wire signed [15:0] sample_left_volume;
    wire signed [15:0] sample_right_volume;
    wire sample_left_valid;
    wire sample_right_valid;
    reg [25:0] heartbeat_count;

    assign PA_SD = 1'b1;
    assign led_heartbeat = heartbeat_count[25];

    always @(posedge clk) begin
        if (rst)
            heartbeat_count <= 26'd0;
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

    tone_gen #(
        .CLK_FREQ_HZ(CLK_HZ),
        .TONE_FREQ_HZ(1000)
    ) u_tone_gen (
        .clk(clk),
        .rst(rst),
        .sample(tone_sample)
    );

    // Volume is already active in the audio path and is controlled per channel.
    volume_control u_volume_left (
        .clk(clk),
        .rst(rst),
        .sample_in(tone_sample),
        .sample_valid(1'b1),
        .volume_level(volume_L),
        .sample_out(sample_left_volume),
        .sample_out_valid(sample_left_valid)
    );

    volume_control u_volume_right (
        .clk(clk),
        .rst(rst),
        .sample_in(tone_sample),
        .sample_valid(1'b1),
        .volume_level(volume_R),
        .sample_out(sample_right_volume),
        .sample_out_valid(sample_right_valid)
    );

    // Bass/mid/treble registers are generated above for a future spectral_processor:
    // FFT -> spectral_gain_select -> complex bin gain -> IFFT -> volume -> I2S.
    i2s_tx #(
        .CLK_FREQ_HZ(CLK_HZ),
        .SAMPLE_RATE_HZ(48000),
        .SAMPLE_WIDTH(16),
        .USE_STEREO_INPUTS(1)
    ) u_i2s_tx (
        .clk(clk),
        .rst(rst),
        .sample_in(sample_left_volume),
        .sample_left(sample_left_volume),
        .sample_right(sample_right_volume),
        .bclk(I2S_BCLK),
        .lrck(I2S_LRCK),
        .sdata(I2S_DIN)
    );

endmodule
