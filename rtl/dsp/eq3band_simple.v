module eq3band_simple #(
    parameter integer LOW_SHIFT  = 8,
    parameter integer HIGH_SHIFT = 3
)(
    input  wire clk,
    input  wire rst,
    input  wire signed [15:0] sample_in,
    input  wire sample_valid,
    input  wire signed [4:0] bass_gain_level,
    input  wire signed [4:0] mid_gain_level,
    input  wire signed [4:0] treble_gain_level,
    output reg  signed [15:0] sample_out,
    output reg  sample_out_valid,
    output reg  clip
);

    wire [15:0] bass_gain_q2_14;
    wire [15:0] mid_gain_q2_14;
    wire [15:0] treble_gain_q2_14;

    wire signed [31:0] sample_ext;
    wire signed [31:0] bass_lp_next;
    wire signed [31:0] fast_lp_next;
    wire signed [31:0] bass_band_next;
    wire signed [31:0] treble_band_next;
    wire signed [31:0] mid_band_next;

    reg signed [31:0] bass_lp;
    reg signed [31:0] fast_lp;
    reg signed [31:0] bass_band_stage;
    reg signed [31:0] mid_band_stage;
    reg signed [31:0] treble_band_stage;
    reg [15:0] bass_gain_stage;
    reg [15:0] mid_gain_stage;
    reg [15:0] treble_gain_stage;
    reg valid_stage1;

    wire signed [16:0] bass_gain_stage_ext;
    wire signed [16:0] mid_gain_stage_ext;
    wire signed [16:0] treble_gain_stage_ext;
    wire signed [48:0] bass_product;
    wire signed [48:0] mid_product;
    wire signed [48:0] treble_product;
    wire signed [48:0] bass_scaled;
    wire signed [48:0] mid_scaled;
    wire signed [48:0] treble_scaled;

    reg signed [49:0] sum_stage;
    reg valid_stage2;

    assign sample_ext = {{16{sample_in[15]}}, sample_in};
    assign bass_lp_next = bass_lp + ((sample_ext - bass_lp) >>> LOW_SHIFT);
    assign fast_lp_next = fast_lp + ((sample_ext - fast_lp) >>> HIGH_SHIFT);
    assign bass_band_next = bass_lp_next;
    assign treble_band_next = sample_ext - fast_lp_next;
    assign mid_band_next = sample_ext - bass_band_next - treble_band_next;

    assign bass_gain_stage_ext = {1'b0, bass_gain_stage};
    assign mid_gain_stage_ext = {1'b0, mid_gain_stage};
    assign treble_gain_stage_ext = {1'b0, treble_gain_stage};

    assign bass_product = bass_band_stage * bass_gain_stage_ext;
    assign mid_product = mid_band_stage * mid_gain_stage_ext;
    assign treble_product = treble_band_stage * treble_gain_stage_ext;
    assign bass_scaled = bass_product >>> 14;
    assign mid_scaled = mid_product >>> 14;
    assign treble_scaled = treble_product >>> 14;

    gain_lut_q2_14 u_bass_gain_lut (
        .gain_level(bass_gain_level),
        .gain_q2_14(bass_gain_q2_14)
    );

    gain_lut_q2_14 u_mid_gain_lut (
        .gain_level(mid_gain_level),
        .gain_q2_14(mid_gain_q2_14)
    );

    gain_lut_q2_14 u_treble_gain_lut (
        .gain_level(treble_gain_level),
        .gain_q2_14(treble_gain_q2_14)
    );

    // First simple DAFX/EQ block in the time domain. It is intentionally small:
    // two IIR low-pass states split the signal into approximate bass/mid/treble
    // bands. Future spectral processing will replace or complement this after
    // FFT and before IFFT.
    // Pipeline latency: two clk cycles from sample_valid to sample_out_valid.
    always @(posedge clk) begin
        if (rst) begin
            bass_lp           <= 32'sd0;
            fast_lp           <= 32'sd0;
            bass_band_stage   <= 32'sd0;
            mid_band_stage    <= 32'sd0;
            treble_band_stage <= 32'sd0;
            bass_gain_stage   <= 16'd16384;
            mid_gain_stage    <= 16'd16384;
            treble_gain_stage <= 16'd16384;
            valid_stage1      <= 1'b0;
            sum_stage         <= 50'sd0;
            valid_stage2      <= 1'b0;
            sample_out        <= 16'sd0;
            sample_out_valid  <= 1'b0;
            clip              <= 1'b0;
        end else begin
            valid_stage1 <= sample_valid;
            valid_stage2 <= valid_stage1;
            sample_out_valid <= valid_stage2;

            if (sample_valid) begin
                bass_lp <= bass_lp_next;
                fast_lp <= fast_lp_next;
                bass_band_stage <= bass_band_next;
                mid_band_stage <= mid_band_next;
                treble_band_stage <= treble_band_next;
                bass_gain_stage <= bass_gain_q2_14;
                mid_gain_stage <= mid_gain_q2_14;
                treble_gain_stage <= treble_gain_q2_14;
            end

            if (valid_stage1)
                sum_stage <= bass_scaled + mid_scaled + treble_scaled;

            if (valid_stage2) begin
                if (sum_stage > 50'sd32767) begin
                    sample_out <= 16'sh7fff;
                    clip <= 1'b1;
                end else if (sum_stage < -50'sd32768) begin
                    sample_out <= 16'sh8000;
                    clip <= 1'b1;
                end else begin
                    sample_out <= sum_stage[15:0];
                    clip <= 1'b0;
                end
            end else begin
                clip <= 1'b0;
            end
        end
    end

endmodule
