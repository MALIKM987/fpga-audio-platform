// Standalone bit-reversal helper for a future radix-2 FFT/IFFT core.
//
// Radix-2 FFT implementations need a defined sample/bin ordering. One common
// approach is to reorder an input frame by reversing the address bits before
// the butterfly stages. For N = 256, INDEX_WIDTH = 8.
//
// This module is purely combinational and parameterized for other widths. It
// is not connected to the current passthrough FFT/IFFT wrappers yet.

module fft_bit_reverse #(
    parameter INDEX_WIDTH = 8
)(
    input  wire [INDEX_WIDTH-1:0] index_in,
    output wire [INDEX_WIDTH-1:0] index_out
);

    genvar bit_idx;

    generate
        for (bit_idx = 0;
             bit_idx < INDEX_WIDTH;
             bit_idx = bit_idx + 1) begin : gen_reverse
            assign index_out[INDEX_WIDTH-1-bit_idx] = index_in[bit_idx];
        end
    endgenerate

endmodule
