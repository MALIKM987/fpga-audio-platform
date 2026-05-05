module eq3band_stereo #(
    parameter integer LOW_SHIFT  = 8,
    parameter integer HIGH_SHIFT = 3
)(
    input  wire clk,
    input  wire rst,
    input  wire signed [15:0] sample_left_in,
    input  wire signed [15:0] sample_right_in,
    input  wire sample_valid,
    input  wire signed [4:0] bass_gain_L,
    input  wire signed [4:0] mid_gain_L,
    input  wire signed [4:0] treble_gain_L,
    input  wire signed [4:0] bass_gain_R,
    input  wire signed [4:0] mid_gain_R,
    input  wire signed [4:0] treble_gain_R,
    output wire signed [15:0] sample_left_out,
    output wire signed [15:0] sample_right_out,
    output wire sample_out_valid,
    output wire clip_L,
    output wire clip_R
);

    wire left_valid;
    wire right_valid;

    eq3band_simple #(
        .LOW_SHIFT(LOW_SHIFT),
        .HIGH_SHIFT(HIGH_SHIFT)
    ) u_eq_left (
        .clk(clk),
        .rst(rst),
        .sample_in(sample_left_in),
        .sample_valid(sample_valid),
        .bass_gain_level(bass_gain_L),
        .mid_gain_level(mid_gain_L),
        .treble_gain_level(treble_gain_L),
        .sample_out(sample_left_out),
        .sample_out_valid(left_valid),
        .clip(clip_L)
    );

    eq3band_simple #(
        .LOW_SHIFT(LOW_SHIFT),
        .HIGH_SHIFT(HIGH_SHIFT)
    ) u_eq_right (
        .clk(clk),
        .rst(rst),
        .sample_in(sample_right_in),
        .sample_valid(sample_valid),
        .bass_gain_level(bass_gain_R),
        .mid_gain_level(mid_gain_R),
        .treble_gain_level(treble_gain_R),
        .sample_out(sample_right_out),
        .sample_out_valid(right_valid),
        .clip(clip_R)
    );

    assign sample_out_valid = left_valid & right_valid;

endmodule
