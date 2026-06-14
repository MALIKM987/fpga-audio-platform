module spectral_processor #(
    parameter integer FFT_SIZE   = 256,
    parameter integer BIN_WIDTH  = 8,
    parameter integer DATA_WIDTH = 16,
    parameter integer GAIN_WIDTH = 16
) (
    input  wire                              clk,
    input  wire                              rst,
    input  wire                              in_valid,
    input  wire [BIN_WIDTH-1:0]              bin_index,
    input  wire signed [DATA_WIDTH-1:0]      real_in,
    input  wire signed [DATA_WIDTH-1:0]      imag_in,
    input  wire signed [GAIN_WIDTH-1:0]      bass_gain,
    input  wire signed [GAIN_WIDTH-1:0]      mid_gain,
    input  wire signed [GAIN_WIDTH-1:0]      treble_gain,
    output reg                               out_valid,
    output reg  signed [DATA_WIDTH-1:0]      real_out,
    output reg  signed [DATA_WIDTH-1:0]      imag_out,
    output reg  signed [GAIN_WIDTH-1:0]      selected_gain,
    output reg  [1:0]                        band_id
);

    wire signed [GAIN_WIDTH-1:0] selected_gain_comb;
    wire [1:0] band_id_comb;

    spectral_gain_select #(
        .FFT_SIZE(FFT_SIZE),
        .BIN_WIDTH(BIN_WIDTH),
        .GAIN_WIDTH(GAIN_WIDTH)
    ) gain_select_inst (
        .bin_index(bin_index),
        .bass_gain(bass_gain),
        .mid_gain(mid_gain),
        .treble_gain(treble_gain),
        .selected_gain(selected_gain_comb),
        .band_id(band_id_comb)
    );

    function signed [DATA_WIDTH-1:0] apply_q2_14_gain;
        input signed [DATA_WIDTH-1:0] value;
        input signed [GAIN_WIDTH-1:0] gain;
        reg signed [DATA_WIDTH+GAIN_WIDTH-1:0] product;
        reg signed [DATA_WIDTH+GAIN_WIDTH-1:0] scaled;
        reg [GAIN_WIDTH:0] guard_bits;
        begin
            product = value * gain;
            scaled = product >>> 14;
            guard_bits = scaled[DATA_WIDTH+GAIN_WIDTH-1:DATA_WIDTH-1];
            if (guard_bits == {(GAIN_WIDTH+1){scaled[DATA_WIDTH-1]}}) begin
                apply_q2_14_gain = scaled[DATA_WIDTH-1:0];
            end else if (scaled[DATA_WIDTH+GAIN_WIDTH-1]) begin
                apply_q2_14_gain = {1'b1, {(DATA_WIDTH-1){1'b0}}};
            end else begin
                apply_q2_14_gain = {1'b0, {(DATA_WIDTH-1){1'b1}}};
            end
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            out_valid     <= 1'b0;
            real_out      <= {DATA_WIDTH{1'b0}};
            imag_out      <= {DATA_WIDTH{1'b0}};
            selected_gain <= {GAIN_WIDTH{1'b0}};
            band_id       <= 2'd0;
        end else begin
            out_valid <= 1'b0;

            if (in_valid) begin
                real_out      <= apply_q2_14_gain(real_in, selected_gain_comb);
                imag_out      <= apply_q2_14_gain(imag_in, selected_gain_comb);
                selected_gain <= selected_gain_comb;
                band_id       <= band_id_comb;
                out_valid     <= 1'b1;
            end
        end
    end

endmodule
