module button_control_top #(
    parameter integer CLK_HZ              = 27000000,
    parameter integer DEBOUNCE_MS         = 20,
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

    output wire       active_channel,
    output wire       led_left_active,
    output wire       led_right_active,
    output wire [3:0] volume_L,
    output wire [3:0] volume_R,
    output wire signed [4:0] bass_gain_L,
    output wire signed [4:0] bass_gain_R,
    output wire signed [4:0] mid_gain_L,
    output wire signed [4:0] mid_gain_R,
    output wire signed [4:0] treble_gain_L,
    output wire signed [4:0] treble_gain_R
);

    wire vol_up_pulse;
    wire vol_down_pulse;
    wire bass_up_pulse;
    wire bass_down_pulse;
    wire mid_up_pulse;
    wire mid_down_pulse;
    wire treble_up_pulse;
    wire treble_down_pulse;
    wire channel_select_pulse;

    button_onepulse #(
        .CLK_HZ(CLK_HZ),
        .DEBOUNCE_MS(DEBOUNCE_MS),
        .BUTTON_ACTIVE_LEVEL(BUTTON_ACTIVE_LEVEL)
    ) u_btn_vol_up (
        .clk(clk),
        .rst(rst),
        .button_raw(btn_vol_up),
        .pulse(vol_up_pulse)
    );

    button_onepulse #(
        .CLK_HZ(CLK_HZ),
        .DEBOUNCE_MS(DEBOUNCE_MS),
        .BUTTON_ACTIVE_LEVEL(BUTTON_ACTIVE_LEVEL)
    ) u_btn_vol_down (
        .clk(clk),
        .rst(rst),
        .button_raw(btn_vol_down),
        .pulse(vol_down_pulse)
    );

    button_onepulse #(
        .CLK_HZ(CLK_HZ),
        .DEBOUNCE_MS(DEBOUNCE_MS),
        .BUTTON_ACTIVE_LEVEL(BUTTON_ACTIVE_LEVEL)
    ) u_btn_bass_up (
        .clk(clk),
        .rst(rst),
        .button_raw(btn_bass_up),
        .pulse(bass_up_pulse)
    );

    button_onepulse #(
        .CLK_HZ(CLK_HZ),
        .DEBOUNCE_MS(DEBOUNCE_MS),
        .BUTTON_ACTIVE_LEVEL(BUTTON_ACTIVE_LEVEL)
    ) u_btn_bass_down (
        .clk(clk),
        .rst(rst),
        .button_raw(btn_bass_down),
        .pulse(bass_down_pulse)
    );

    button_onepulse #(
        .CLK_HZ(CLK_HZ),
        .DEBOUNCE_MS(DEBOUNCE_MS),
        .BUTTON_ACTIVE_LEVEL(BUTTON_ACTIVE_LEVEL)
    ) u_btn_mid_up (
        .clk(clk),
        .rst(rst),
        .button_raw(btn_mid_up),
        .pulse(mid_up_pulse)
    );

    button_onepulse #(
        .CLK_HZ(CLK_HZ),
        .DEBOUNCE_MS(DEBOUNCE_MS),
        .BUTTON_ACTIVE_LEVEL(BUTTON_ACTIVE_LEVEL)
    ) u_btn_mid_down (
        .clk(clk),
        .rst(rst),
        .button_raw(btn_mid_down),
        .pulse(mid_down_pulse)
    );

    button_onepulse #(
        .CLK_HZ(CLK_HZ),
        .DEBOUNCE_MS(DEBOUNCE_MS),
        .BUTTON_ACTIVE_LEVEL(BUTTON_ACTIVE_LEVEL)
    ) u_btn_treble_up (
        .clk(clk),
        .rst(rst),
        .button_raw(btn_treble_up),
        .pulse(treble_up_pulse)
    );

    button_onepulse #(
        .CLK_HZ(CLK_HZ),
        .DEBOUNCE_MS(DEBOUNCE_MS),
        .BUTTON_ACTIVE_LEVEL(BUTTON_ACTIVE_LEVEL)
    ) u_btn_treble_down (
        .clk(clk),
        .rst(rst),
        .button_raw(btn_treble_down),
        .pulse(treble_down_pulse)
    );

    button_onepulse #(
        .CLK_HZ(CLK_HZ),
        .DEBOUNCE_MS(DEBOUNCE_MS),
        .BUTTON_ACTIVE_LEVEL(BUTTON_ACTIVE_LEVEL)
    ) u_btn_channel_select (
        .clk(clk),
        .rst(rst),
        .button_raw(btn_channel_select),
        .pulse(channel_select_pulse)
    );

    audio_param_regs u_audio_param_regs (
        .clk(clk),
        .rst(rst),
        .vol_up_pulse(vol_up_pulse),
        .vol_down_pulse(vol_down_pulse),
        .bass_up_pulse(bass_up_pulse),
        .bass_down_pulse(bass_down_pulse),
        .mid_up_pulse(mid_up_pulse),
        .mid_down_pulse(mid_down_pulse),
        .treble_up_pulse(treble_up_pulse),
        .treble_down_pulse(treble_down_pulse),
        .channel_select_pulse(channel_select_pulse),
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

endmodule
