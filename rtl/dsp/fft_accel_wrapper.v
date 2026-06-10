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

    output reg                               out_valid,
    output reg  [INDEX_WIDTH-1:0]            out_index,
    output reg  signed [DATA_WIDTH-1:0]      real_out,
    output reg  signed [DATA_WIDTH-1:0]      imag_out,
    output reg                               busy,
    output reg                               done
);

    // Model testowy interfejsu. Docelowo ten blok zostanie zastapiony
    // prawdziwym FFT albo wrapperem Gowin FFT IP z tym samym interfejsem.
    localparam [1:0] STATE_IDLE   = 2'd0;
    localparam [1:0] STATE_INPUT  = 2'd1;
    localparam [1:0] STATE_OUTPUT = 2'd2;
    localparam [1:0] STATE_DONE   = 2'd3;
    localparam integer COUNT_WIDTH = INDEX_WIDTH + 1;

    reg [1:0] state;
    reg [INDEX_WIDTH:0] input_count;
    reg [INDEX_WIDTH:0] output_count;
    reg signed [DATA_WIDTH-1:0] real_mem [0:FFT_SIZE-1];
    reg signed [DATA_WIDTH-1:0] imag_mem [0:FFT_SIZE-1];

    always @(posedge clk) begin
        if (rst) begin
            state        <= STATE_IDLE;
            input_count  <= {COUNT_WIDTH{1'b0}};
            output_count <= {COUNT_WIDTH{1'b0}};
            out_valid    <= 1'b0;
            out_index    <= {INDEX_WIDTH{1'b0}};
            real_out     <= {DATA_WIDTH{1'b0}};
            imag_out     <= {DATA_WIDTH{1'b0}};
            busy         <= 1'b0;
            done         <= 1'b0;
        end else begin
            out_valid <= 1'b0;
            done      <= 1'b0;

            case (state)
                STATE_IDLE: begin
                    busy <= 1'b0;

                    if (start) begin
                        state        <= STATE_INPUT;
                        input_count  <= {COUNT_WIDTH{1'b0}};
                        output_count <= {COUNT_WIDTH{1'b0}};
                        busy         <= 1'b1;
                    end
                end

                STATE_INPUT: begin
                    busy <= 1'b1;

                    if (in_valid) begin
                        real_mem[in_index] <= real_in;
                        imag_mem[in_index] <= imag_in;

                        if (input_count == FFT_SIZE - 1) begin
                            input_count  <= {COUNT_WIDTH{1'b0}};
                            output_count <= {COUNT_WIDTH{1'b0}};
                            state        <= STATE_OUTPUT;
                        end else begin
                            input_count <= input_count + 1'b1;
                        end
                    end
                end

                STATE_OUTPUT: begin
                    busy      <= 1'b1;
                    out_valid <= 1'b1;
                    out_index <= output_count[INDEX_WIDTH-1:0];
                    real_out  <= real_mem[output_count[INDEX_WIDTH-1:0]];
                    imag_out  <= imag_mem[output_count[INDEX_WIDTH-1:0]];

                    if (output_count == FFT_SIZE - 1) begin
                        output_count <= {COUNT_WIDTH{1'b0}};
                        state        <= STATE_DONE;
                    end else begin
                        output_count <= output_count + 1'b1;
                    end
                end

                STATE_DONE: begin
                    busy  <= 1'b0;
                    done  <= 1'b1;
                    state <= STATE_IDLE;
                end

                default: begin
                    state        <= STATE_IDLE;
                    input_count  <= {COUNT_WIDTH{1'b0}};
                    output_count <= {COUNT_WIDTH{1'b0}};
                    busy         <= 1'b0;
                end
            endcase
        end
    end

endmodule
