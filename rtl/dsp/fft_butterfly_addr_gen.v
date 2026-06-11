// Standalone radix-2 FFT butterfly address generator.
//
// For each FFT stage, a radix-2 decimation-in-time FFT processes N/2
// butterflies. Each butterfly reads two addresses:
//   addr_a = group * group_size + index_in_group
//   addr_b = addr_a + half_size
//
// The twiddle index is derived from the position inside the group:
//   twiddle_index = index_in_group * (FFT_SIZE / group_size)
//
// This first implementation is combinational and verified for FFT_SIZE = 256.
// It is standalone and is not connected to fft_radix2_core.v or the current
// passthrough FFT/IFFT wrappers yet.

module fft_butterfly_addr_gen #(
    parameter integer FFT_SIZE    = 256,
    parameter integer INDEX_WIDTH = 8,
    parameter integer STAGE_WIDTH = 3
)(
    input  wire [STAGE_WIDTH-1:0] stage,
    input  wire [INDEX_WIDTH-2:0] butterfly_index,

    output reg  [INDEX_WIDTH-1:0] addr_a,
    output reg  [INDEX_WIDTH-1:0] addr_b,
    output reg  [INDEX_WIDTH-1:0] twiddle_index
);

    integer stage_value;
    integer half_size;
    integer group_size;
    integer group;
    integer index_in_group;
    integer twiddle_step;
    integer addr_a_int;
    integer addr_b_int;
    integer twiddle_index_int;

    always @* begin
        stage_value = stage;
        half_size = 1 << stage_value;
        group_size = 1 << (stage_value + 1);
        group = butterfly_index / half_size;
        index_in_group = butterfly_index % half_size;
        twiddle_step = FFT_SIZE / group_size;

        addr_a_int = (group * group_size) + index_in_group;
        addr_b_int = addr_a_int + half_size;
        twiddle_index_int = index_in_group * twiddle_step;

        addr_a = addr_a_int;
        addr_b = addr_b_int;
        twiddle_index = twiddle_index_int;
    end

endmodule
