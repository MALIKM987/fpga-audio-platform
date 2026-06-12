module spectral_gain_select #(
    parameter integer FFT_SIZE   = 256,
    parameter integer BIN_WIDTH  = 8,
    parameter integer GAIN_WIDTH = 16
) (
    input  wire [BIN_WIDTH-1:0]              bin_index,
    input  wire signed [GAIN_WIDTH-1:0]      bass_gain,
    input  wire signed [GAIN_WIDTH-1:0]      mid_gain,
    input  wire signed [GAIN_WIDTH-1:0]      treble_gain,
    output reg  signed [GAIN_WIDTH-1:0]      selected_gain,
    output reg  [1:0]                        band_id
);

    localparam [1:0] BAND_BASS   = 2'd0;
    localparam [1:0] BAND_MID    = 2'd1;
    localparam [1:0] BAND_TREBLE = 2'd2;
    localparam [BIN_WIDTH:0] FFT_SIZE_VALUE = FFT_SIZE;

    wire [BIN_WIDTH:0] bin_ext;
    wire [BIN_WIDTH:0] mirrored_bin;
    wire [BIN_WIDTH:0] effective_bin;

    assign bin_ext       = {1'b0, bin_index};
    assign mirrored_bin  = FFT_SIZE_VALUE - bin_ext;
    assign effective_bin = (bin_ext <= (FFT_SIZE / 2)) ? bin_ext : mirrored_bin;

    always @* begin
        if (effective_bin <= 1) begin
            selected_gain = bass_gain;
            band_id       = BAND_BASS;
        end else if (effective_bin <= 21) begin
            selected_gain = mid_gain;
            band_id       = BAND_MID;
        end else begin
            selected_gain = treble_gain;
            band_id       = BAND_TREBLE;
        end
    end

endmodule
