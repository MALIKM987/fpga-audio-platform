module modulation_core #(
    parameter integer LOW_SHIFT  = 6,
    parameter integer HIGH_SHIFT = 2
)(
    input  wire clk,
    input  wire rst,
    input  wire signed [15:0] sample_in,
    input  wire sample_valid,
    input  wire [3:0] volume_gain_level,
    input  wire signed [4:0] bass_gain_level,
    input  wire signed [4:0] mid_gain_level,
    input  wire signed [4:0] treble_gain_level,
    output reg  signed [15:0] sample_out,
    output reg  sample_out_valid,
    output reg  clip
);

    // Self-test DSP core: simple time-domain modulation with no FFT/IFFT.
    // Components are approximate and intended for diagnostics before real audio hardware.

    wire [15:0] volume_q2_14;
    wire [15:0] bass_q2_14;
    wire [15:0] mid_q2_14;
    wire [15:0] treble_q2_14;

    reg signed [31:0] bass_state;
    reg signed [31:0] fast_lp_state;

    wire signed [31:0] sample_ext;
    wire signed [31:0] bass_next;
    wire signed [31:0] fast_lp_next;
    wire signed [31:0] bass_component;
    wire signed [31:0] treble_component;
    wire signed [31:0] mid_component;

    wire signed [16:0] volume_gain_signed;
    wire signed [16:0] bass_gain_signed;
    wire signed [16:0] mid_gain_signed;
    wire signed [16:0] treble_gain_signed;

    wire signed [48:0] bass_product;
    wire signed [48:0] mid_product;
    wire signed [48:0] treble_product;
    wire signed [48:0] bass_scaled;
    wire signed [48:0] mid_scaled;
    wire signed [48:0] treble_scaled;
    wire signed [50:0] band_sum;
    wire signed [67:0] volume_product;
    wire signed [67:0] final_scaled;

    assign sample_ext        = {{16{sample_in[15]}}, sample_in};
    assign bass_next         = bass_state + ((sample_ext - bass_state) >>> LOW_SHIFT);
    assign fast_lp_next      = fast_lp_state + ((sample_ext - fast_lp_state) >>> HIGH_SHIFT);
    assign bass_component    = bass_next;
    assign treble_component  = sample_ext - fast_lp_next;
    assign mid_component     = sample_ext - bass_component - treble_component;

    assign volume_gain_signed = {1'b0, volume_q2_14};
    assign bass_gain_signed   = {1'b0, bass_q2_14};
    assign mid_gain_signed    = {1'b0, mid_q2_14};
    assign treble_gain_signed = {1'b0, treble_q2_14};

    assign bass_product   = bass_component * bass_gain_signed;
    assign mid_product    = mid_component * mid_gain_signed;
    assign treble_product = treble_component * treble_gain_signed;
    assign bass_scaled    = bass_product >>> 14;
    assign mid_scaled     = mid_product >>> 14;
    assign treble_scaled  = treble_product >>> 14;
    assign band_sum       = bass_scaled + mid_scaled + treble_scaled;
    assign volume_product = band_sum * volume_gain_signed;
    assign final_scaled   = volume_product >>> 14;

    volume_lut_q2_14 volume_lut_inst (
        .volume_level(volume_gain_level),
        .volume_q2_14(volume_q2_14)
    );

    gain_lut_q2_14 bass_lut_inst (
        .gain_level(bass_gain_level),
        .gain_q2_14(bass_q2_14)
    );

    gain_lut_q2_14 mid_lut_inst (
        .gain_level(mid_gain_level),
        .gain_q2_14(mid_q2_14)
    );

    gain_lut_q2_14 treble_lut_inst (
        .gain_level(treble_gain_level),
        .gain_q2_14(treble_q2_14)
    );

    always @(posedge clk) begin
        if (rst) begin
            bass_state       <= 32'sd0;
            fast_lp_state    <= 32'sd0;
            sample_out       <= 16'sd0;
            sample_out_valid <= 1'b0;
            clip             <= 1'b0;
        end else begin
            sample_out_valid <= sample_valid;
            clip             <= 1'b0;

            if (sample_valid) begin
                bass_state    <= bass_next;
                fast_lp_state <= fast_lp_next;

                if (final_scaled > 68'sd32767) begin
                    sample_out <= 16'sd32767;
                    clip       <= 1'b1;
                end else if (final_scaled < -68'sd32768) begin
                    sample_out <= 16'sh8000;
                    clip       <= 1'b1;
                end else begin
                    sample_out <= final_scaled[15:0];
                    clip       <= 1'b0;
                end
            end
        end
    end

endmodule
