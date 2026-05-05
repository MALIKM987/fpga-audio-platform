module spectral_gain_select #(
    parameter integer FFT_N       = 512,
    parameter integer SAMPLE_RATE = 48000
)(
    input  wire [8:0] bin_index,
    input  wire signed [4:0] bass_gain,
    input  wire signed [4:0] mid_gain,
    input  wire signed [4:0] treble_gain,
    output wire [15:0] selected_gain_q2_14
);

    wire [9:0] bin_index_ext;
    wire [9:0] abs_bin_ext;
    wire [8:0] abs_bin;
    reg  signed [4:0] selected_gain_level;

    assign bin_index_ext = {1'b0, bin_index};
    assign abs_bin_ext   = (bin_index_ext <= (FFT_N / 2)) ?
                           bin_index_ext :
                           (FFT_N - bin_index_ext);
    assign abs_bin       = abs_bin_ext[8:0];

    always @* begin
        if (abs_bin == 9'd0)
            selected_gain_level = 5'sd0;
        else if (abs_bin <= 9'd3)
            selected_gain_level = bass_gain;
        else if (abs_bin <= 9'd42)
            selected_gain_level = mid_gain;
        else if (abs_bin <= 9'd255)
            selected_gain_level = treble_gain;
        else
            selected_gain_level = 5'sd0;
    end

    gain_lut_q2_14 u_gain_lut_q2_14 (
        .gain_level(selected_gain_level),
        .gain_q2_14(selected_gain_q2_14)
    );

endmodule
