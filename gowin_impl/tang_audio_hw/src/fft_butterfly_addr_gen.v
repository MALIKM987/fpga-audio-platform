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
// The standalone fft_radix2_core.v uses it internally, but the real FFT core
// is still not connected to the current passthrough FFT/IFFT wrappers.

module fft_butterfly_addr_gen #(
    parameter integer FFT_SIZE    = 256,
    parameter integer INDEX_WIDTH = 8,
    parameter integer STAGE_WIDTH = 3
)(
    input  wire [STAGE_WIDTH-1:0] stage,
    input  wire [INDEX_WIDTH-2:0] butterfly_index,

    output wire [INDEX_WIDTH-1:0] addr_a,
    output wire [INDEX_WIDTH-1:0] addr_b,
    output wire [INDEX_WIDTH-1:0] twiddle_index
);

    function [INDEX_WIDTH-1:0] calc_addr_a;
        input [STAGE_WIDTH-1:0] stage_in;
        input [INDEX_WIDTH-2:0] butterfly_index_in;
        integer stage_value;
        integer half_size;
        integer group_size;
        integer group;
        integer index_in_group;
        integer addr_a_int;
        begin
            stage_value = stage_in;
            half_size = 1 << stage_value;
            group_size = 1 << (stage_value + 1);
            group = butterfly_index_in / half_size;
            index_in_group = butterfly_index_in % half_size;
            addr_a_int = (group * group_size) + index_in_group;
            calc_addr_a = addr_a_int;
        end
    endfunction

    function [INDEX_WIDTH-1:0] calc_addr_b;
        input [STAGE_WIDTH-1:0] stage_in;
        input [INDEX_WIDTH-2:0] butterfly_index_in;
        integer stage_value;
        integer half_size;
        integer addr_a_int;
        begin
            stage_value = stage_in;
            half_size = 1 << stage_value;
            addr_a_int = calc_addr_a(stage_in, butterfly_index_in);
            calc_addr_b = addr_a_int + half_size;
        end
    endfunction

    function [INDEX_WIDTH-1:0] calc_twiddle_index;
        input [STAGE_WIDTH-1:0] stage_in;
        input [INDEX_WIDTH-2:0] butterfly_index_in;
        integer stage_value;
        integer half_size;
        integer group_size;
        integer index_in_group;
        integer twiddle_step;
        integer twiddle_index_int;
        begin
            stage_value = stage_in;
            half_size = 1 << stage_value;
            group_size = 1 << (stage_value + 1);
            index_in_group = butterfly_index_in % half_size;
            twiddle_step = FFT_SIZE / group_size;
            twiddle_index_int = index_in_group * twiddle_step;
            calc_twiddle_index = twiddle_index_int;
        end
    endfunction

    // Continuous assignments keep the first stage-0/butterfly-0 addresses
    // driven from time zero in event-driven simulators.
    assign addr_a = calc_addr_a(stage, butterfly_index);
    assign addr_b = calc_addr_b(stage, butterfly_index);
    assign twiddle_index = calc_twiddle_index(stage, butterfly_index);

endmodule
