// Standalone fixed-point complex multiplier for the future custom FFT/IFFT.
//
// Computes:
//   (a_real + j*a_imag) * (b_real + j*b_imag)
//
// Formula:
//   out_real = a_real*b_real - a_imag*b_imag
//   out_imag = a_real*b_imag + a_imag*b_real
//
// The default format is signed Q2.14. Multiplication creates wider internal
// products, then the result is shifted right by FRAC_BITS to return to Q2.14.
// The scaled result is saturated back to DATA_WIDTH. That keeps twiddle
// rotation from silently wrapping when a later pipeline stage uses wider
// internal FFT bins.
//
// This module is standalone and is not connected to the current passthrough
// FFT/IFFT wrappers yet.

module complex_mult #(
    parameter DATA_WIDTH = 16,
    parameter FRAC_BITS = 14
)(
    input  wire signed [DATA_WIDTH-1:0] a_real,
    input  wire signed [DATA_WIDTH-1:0] a_imag,
    input  wire signed [DATA_WIDTH-1:0] b_real,
    input  wire signed [DATA_WIDTH-1:0] b_imag,
    output wire signed [DATA_WIDTH-1:0] out_real,
    output wire signed [DATA_WIDTH-1:0] out_imag
);

    localparam integer PRODUCT_WIDTH = 2 * DATA_WIDTH;
    localparam integer FULL_WIDTH = PRODUCT_WIDTH + 1;

    wire signed [PRODUCT_WIDTH-1:0] real_product = a_real * b_real;
    wire signed [PRODUCT_WIDTH-1:0] imag_product = a_imag * b_imag;
    wire signed [PRODUCT_WIDTH-1:0] cross_product_a = a_real * b_imag;
    wire signed [PRODUCT_WIDTH-1:0] cross_product_b = a_imag * b_real;

    wire signed [FULL_WIDTH-1:0] real_product_ext =
        {real_product[PRODUCT_WIDTH-1], real_product};
    wire signed [FULL_WIDTH-1:0] imag_product_ext =
        {imag_product[PRODUCT_WIDTH-1], imag_product};
    wire signed [FULL_WIDTH-1:0] cross_product_a_ext =
        {cross_product_a[PRODUCT_WIDTH-1], cross_product_a};
    wire signed [FULL_WIDTH-1:0] cross_product_b_ext =
        {cross_product_b[PRODUCT_WIDTH-1], cross_product_b};

    wire signed [FULL_WIDTH-1:0] real_full =
        real_product_ext - imag_product_ext;

    wire signed [FULL_WIDTH-1:0] imag_full =
        cross_product_a_ext + cross_product_b_ext;

    wire signed [FULL_WIDTH-1:0] real_scaled = real_full >>> FRAC_BITS;
    wire signed [FULL_WIDTH-1:0] imag_scaled = imag_full >>> FRAC_BITS;

    localparam integer GUARD_WIDTH = FULL_WIDTH - DATA_WIDTH + 1;

    function signed [DATA_WIDTH-1:0] saturate_scaled;
        input signed [FULL_WIDTH-1:0] value;
        reg [GUARD_WIDTH-1:0] guard_bits;
        begin
            guard_bits = value[FULL_WIDTH-1:DATA_WIDTH-1];
            if (guard_bits == {GUARD_WIDTH{value[DATA_WIDTH-1]}}) begin
                saturate_scaled = value[DATA_WIDTH-1:0];
            end else if (value[FULL_WIDTH-1]) begin
                saturate_scaled = {1'b1, {(DATA_WIDTH-1){1'b0}}};
            end else begin
                saturate_scaled = {1'b0, {(DATA_WIDTH-1){1'b1}}};
            end
        end
    endfunction

    assign out_real = saturate_scaled(real_scaled);
    assign out_imag = saturate_scaled(imag_scaled);

endmodule
