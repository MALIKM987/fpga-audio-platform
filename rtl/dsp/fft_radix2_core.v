// Standalone radix-2 FFT/IFFT core skeleton.
//
// This module validates frame control for the future custom FFT/IFFT:
// start -> busy -> load frame -> butterfly read walk -> output frame -> done.
//
// It is intentionally not a real FFT implementation yet. The LOAD state stores
// samples at bit-reversed addresses, then OUTPUT reads memory in natural order.
// The compute path now has the first micro-step of a future butterfly pipeline:
// it walks through all radix-2 stage/butterfly positions, reads A/B operands
// from memory using generated addresses, and latches them into working
// registers. It still does not calculate twiddles, multiply, or write modified
// butterfly results back to memory. Twiddle ROM access, complex multiplication,
// inverse twiddle sign, and IFFT normalization will be added later.
//
// This core is standalone and is not connected to the current passthrough
// FFT/IFFT wrappers yet.

module fft_radix2_core #(
    parameter integer FFT_SIZE    = 256,
    parameter integer DATA_WIDTH  = 16,
    parameter integer INDEX_WIDTH = 8
)(
    input  wire                              clk,
    input  wire                              rst,
    input  wire                              start,
    input  wire                              inverse,

    input  wire                              in_valid,
    input  wire [INDEX_WIDTH-1:0]            in_index,
    input  wire signed [DATA_WIDTH-1:0]      real_in,
    input  wire signed [DATA_WIDTH-1:0]      imag_in,

    output reg                               out_valid,
    output reg  [INDEX_WIDTH-1:0]            out_index,
    output reg  signed [DATA_WIDTH-1:0]      real_out,
    output reg  signed [DATA_WIDTH-1:0]      imag_out,
    output reg                               busy,
    output reg                               done
);

    localparam integer COUNT_WIDTH = INDEX_WIDTH + 1;
    localparam integer NUM_STAGES = 8;
    localparam integer BUTTERFLIES_PER_STAGE = FFT_SIZE / 2;

    localparam [2:0] STATE_IDLE              = 3'd0;
    localparam [2:0] STATE_LOAD              = 3'd1;
    localparam [2:0] STATE_BUTTERFLY_READ    = 3'd2;
    localparam [2:0] STATE_BUTTERFLY_ADVANCE = 3'd3;
    localparam [2:0] STATE_OUTPUT            = 3'd4;
    localparam [2:0] STATE_DONE              = 3'd5;

    reg [2:0] state = STATE_IDLE;
    reg [COUNT_WIDTH-1:0] load_count = {COUNT_WIDTH{1'b0}};
    reg [COUNT_WIDTH-1:0] output_count = {COUNT_WIDTH{1'b0}};
    reg [2:0] stage_counter = 3'd0;
    reg [INDEX_WIDTH-2:0] butterfly_counter = {(INDEX_WIDTH-1){1'b0}};
    reg inverse_latched = 1'b0;
    reg signed [DATA_WIDTH-1:0] a_real_reg = {DATA_WIDTH{1'b0}};
    reg signed [DATA_WIDTH-1:0] a_imag_reg = {DATA_WIDTH{1'b0}};
    reg signed [DATA_WIDTH-1:0] b_real_reg = {DATA_WIDTH{1'b0}};
    reg signed [DATA_WIDTH-1:0] b_imag_reg = {DATA_WIDTH{1'b0}};
    reg [INDEX_WIDTH-1:0] butterfly_addr_a_reg = {INDEX_WIDTH{1'b0}};
    reg [INDEX_WIDTH-1:0] butterfly_addr_b_reg = {INDEX_WIDTH{1'b0}};
    reg [INDEX_WIDTH-1:0] butterfly_twiddle_index_reg = {INDEX_WIDTH{1'b0}};
    reg [2:0] stage_counter_reg = 3'd0;
    reg [INDEX_WIDTH-2:0] butterfly_counter_reg = {(INDEX_WIDTH-1){1'b0}};

    reg signed [DATA_WIDTH-1:0] real_mem [0:FFT_SIZE-1];
    reg signed [DATA_WIDTH-1:0] imag_mem [0:FFT_SIZE-1];

    wire [INDEX_WIDTH-1:0] write_addr;
    wire [INDEX_WIDTH-1:0] butterfly_addr_a;
    wire [INDEX_WIDTH-1:0] butterfly_addr_b;
    wire [INDEX_WIDTH-1:0] butterfly_twiddle_index;

    fft_bit_reverse #(
        .INDEX_WIDTH(INDEX_WIDTH)
    ) bit_reverse_inst (
        .index_in(in_index),
        .index_out(write_addr)
    );

    fft_butterfly_addr_gen #(
        .FFT_SIZE(FFT_SIZE),
        .INDEX_WIDTH(INDEX_WIDTH),
        .STAGE_WIDTH(3)
    ) butterfly_addr_gen_inst (
        .stage(stage_counter),
        .butterfly_index(butterfly_counter),
        .addr_a(butterfly_addr_a),
        .addr_b(butterfly_addr_b),
        .twiddle_index(butterfly_twiddle_index)
    );

    always @(posedge clk) begin
        if (rst) begin
            state <= STATE_IDLE;
            load_count <= {COUNT_WIDTH{1'b0}};
            output_count <= {COUNT_WIDTH{1'b0}};
            stage_counter <= 3'd0;
            butterfly_counter <= {(INDEX_WIDTH-1){1'b0}};
            inverse_latched <= 1'b0;
            a_real_reg <= {DATA_WIDTH{1'b0}};
            a_imag_reg <= {DATA_WIDTH{1'b0}};
            b_real_reg <= {DATA_WIDTH{1'b0}};
            b_imag_reg <= {DATA_WIDTH{1'b0}};
            butterfly_addr_a_reg <= {INDEX_WIDTH{1'b0}};
            butterfly_addr_b_reg <= {INDEX_WIDTH{1'b0}};
            butterfly_twiddle_index_reg <= {INDEX_WIDTH{1'b0}};
            stage_counter_reg <= 3'd0;
            butterfly_counter_reg <= {(INDEX_WIDTH-1){1'b0}};
            out_valid <= 1'b0;
            out_index <= {INDEX_WIDTH{1'b0}};
            real_out <= {DATA_WIDTH{1'b0}};
            imag_out <= {DATA_WIDTH{1'b0}};
            busy <= 1'b0;
            done <= 1'b0;
        end else begin
            out_valid <= 1'b0;
            done <= 1'b0;

            case (state)
                STATE_IDLE: begin
                    busy <= 1'b0;
                    if (start) begin
                        busy <= 1'b1;
                        load_count <= {COUNT_WIDTH{1'b0}};
                        output_count <= {COUNT_WIDTH{1'b0}};
                        stage_counter <= 3'd0;
                        butterfly_counter <= {(INDEX_WIDTH-1){1'b0}};
                        a_real_reg <= {DATA_WIDTH{1'b0}};
                        a_imag_reg <= {DATA_WIDTH{1'b0}};
                        b_real_reg <= {DATA_WIDTH{1'b0}};
                        b_imag_reg <= {DATA_WIDTH{1'b0}};
                        butterfly_addr_a_reg <= {INDEX_WIDTH{1'b0}};
                        butterfly_addr_b_reg <= {INDEX_WIDTH{1'b0}};
                        butterfly_twiddle_index_reg <= {INDEX_WIDTH{1'b0}};
                        stage_counter_reg <= 3'd0;
                        butterfly_counter_reg <= {(INDEX_WIDTH-1){1'b0}};
                        // Reserved for future FFT/IFFT mode selection.
                        inverse_latched <= inverse;
                        state <= STATE_LOAD;
                    end
                end

                STATE_LOAD: begin
                    busy <= 1'b1;
                    if (in_valid) begin
                        real_mem[write_addr] <= real_in;
                        imag_mem[write_addr] <= imag_in;

                        if (load_count == FFT_SIZE - 1) begin
                            load_count <= load_count + 1'b1;
                            stage_counter <= 3'd0;
                            butterfly_counter <= {(INDEX_WIDTH-1){1'b0}};
                            state <= STATE_BUTTERFLY_READ;
                        end else begin
                            load_count <= load_count + 1'b1;
                        end
                    end
                end

                STATE_BUTTERFLY_READ: begin
                    busy <= 1'b1;
                    // First micro-step for the future butterfly pipeline:
                    // read A/B operands and latch address metadata. The next
                    // state advances to the next slot without modifying memory.
                    a_real_reg <= real_mem[butterfly_addr_a];
                    a_imag_reg <= imag_mem[butterfly_addr_a];
                    b_real_reg <= real_mem[butterfly_addr_b];
                    b_imag_reg <= imag_mem[butterfly_addr_b];
                    butterfly_addr_a_reg <= butterfly_addr_a;
                    butterfly_addr_b_reg <= butterfly_addr_b;
                    butterfly_twiddle_index_reg <= butterfly_twiddle_index;
                    stage_counter_reg <= stage_counter;
                    butterfly_counter_reg <= butterfly_counter;
                    state <= STATE_BUTTERFLY_ADVANCE;
                end

                STATE_BUTTERFLY_ADVANCE: begin
                    busy <= 1'b1;
                    // No butterfly math or writeback yet. This state only
                    // advances through every radix-2 stage/butterfly slot.
                    if ((stage_counter == NUM_STAGES - 1) &&
                        (butterfly_counter == BUTTERFLIES_PER_STAGE - 1)) begin
                        stage_counter <= 3'd0;
                        butterfly_counter <= {(INDEX_WIDTH-1){1'b0}};
                        output_count <= {COUNT_WIDTH{1'b0}};
                        state <= STATE_OUTPUT;
                    end else begin
                        if (butterfly_counter == BUTTERFLIES_PER_STAGE - 1) begin
                            butterfly_counter <= {(INDEX_WIDTH-1){1'b0}};
                            stage_counter <= stage_counter + 1'b1;
                        end else begin
                            butterfly_counter <= butterfly_counter + 1'b1;
                        end
                        state <= STATE_BUTTERFLY_READ;
                    end
                end

                STATE_OUTPUT: begin
                    busy <= 1'b1;
                    out_valid <= 1'b1;
                    out_index <= output_count[INDEX_WIDTH-1:0];
                    real_out <= real_mem[output_count[INDEX_WIDTH-1:0]];
                    imag_out <= imag_mem[output_count[INDEX_WIDTH-1:0]];

                    if (output_count == FFT_SIZE - 1) begin
                        output_count <= output_count + 1'b1;
                        state <= STATE_DONE;
                    end else begin
                        output_count <= output_count + 1'b1;
                    end
                end

                STATE_DONE: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    state <= STATE_IDLE;
                end

                default: begin
                    state <= STATE_IDLE;
                    busy <= 1'b0;
                end
            endcase
        end
    end

endmodule
