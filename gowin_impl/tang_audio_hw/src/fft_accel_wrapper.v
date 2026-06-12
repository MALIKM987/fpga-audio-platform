module fft_accel_wrapper #(
    parameter integer FFT_SIZE    = 256,
    parameter integer DATA_WIDTH  = 16,
    parameter integer INDEX_WIDTH = 8
) (
    input  wire                              clk,
    input  wire                              rst,
    input  wire                              start,
    input  wire                              in_valid,
    input  wire [INDEX_WIDTH-1:0]            in_index,
    input  wire signed [DATA_WIDTH-1:0]      real_in,
    input  wire signed [DATA_WIDTH-1:0]      imag_in,

    output wire                              out_valid,
    output wire [INDEX_WIDTH-1:0]            out_index,
    output wire signed [DATA_WIDTH-1:0]      real_out,
    output wire signed [DATA_WIDTH-1:0]      imag_out,
    output wire                              busy,
    output wire                              done
);

    // Thin FFT wrapper for the forward transform path.
    // inverse is tied low here: the IFFT wrapper is intentionally unchanged
    // and remains a passthrough model until the next integration step.
    fft_radix2_core #(
        .FFT_SIZE(FFT_SIZE),
        .DATA_WIDTH(DATA_WIDTH),
        .INDEX_WIDTH(INDEX_WIDTH)
    ) fft_core_inst (
        .clk(clk),
        .rst(rst),
        .start(start),
        .inverse(1'b0),
        .in_valid(in_valid),
        .in_index(in_index),
        .real_in(real_in),
        .imag_in(imag_in),
        .out_valid(out_valid),
        .out_index(out_index),
        .real_out(real_out),
        .imag_out(imag_out),
        .busy(busy),
        .done(done)
    );

endmodule
