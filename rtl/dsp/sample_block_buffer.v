module sample_block_buffer #(
    parameter integer FFT_SIZE     = 256,
    parameter integer SAMPLE_WIDTH = 16,
    parameter integer ADDR_WIDTH   = 8
) (
    input  wire                             clk,
    input  wire                             rst,

    input  wire                             sample_valid,
    input  wire signed [SAMPLE_WIDTH-1:0]   sample_in,

    input  wire                             consume_frame,

    output reg                              frame_ready,
    output reg                              frame_valid,
    output reg                              frame_start,
    output reg                              frame_end,
    output reg  [ADDR_WIDTH-1:0]            frame_index,
    output reg  signed [SAMPLE_WIDTH-1:0]   frame_sample,

    output reg                              overflow
);

    localparam [1:0] STATE_COLLECT = 2'd0;
    localparam [1:0] STATE_READY   = 2'd1;
    localparam [1:0] STATE_READ    = 2'd2;
    localparam integer COUNT_WIDTH = ADDR_WIDTH + 1;
    localparam [ADDR_WIDTH:0] FFT_SIZE_VALUE = FFT_SIZE;

    reg [1:0] state;
    reg [ADDR_WIDTH:0] write_count;
    reg [ADDR_WIDTH:0] read_count;
    reg signed [SAMPLE_WIDTH-1:0] sample_mem [0:FFT_SIZE-1];

    always @(posedge clk) begin
        if (rst) begin
            state        <= STATE_COLLECT;
            write_count  <= {COUNT_WIDTH{1'b0}};
            read_count   <= {COUNT_WIDTH{1'b0}};
            frame_ready  <= 1'b0;
            frame_valid  <= 1'b0;
            frame_start  <= 1'b0;
            frame_end    <= 1'b0;
            frame_index  <= {ADDR_WIDTH{1'b0}};
            frame_sample <= {SAMPLE_WIDTH{1'b0}};
            overflow     <= 1'b0;
        end else begin
            frame_valid <= 1'b0;
            frame_start <= 1'b0;
            frame_end   <= 1'b0;

            case (state)
                STATE_COLLECT: begin
                    frame_ready <= 1'b0;

                    if (sample_valid) begin
                        sample_mem[write_count[ADDR_WIDTH-1:0]] <= sample_in;

                        if (write_count == FFT_SIZE - 1) begin
                            write_count <= FFT_SIZE_VALUE;
                            frame_ready <= 1'b1;
                            state       <= STATE_READY;
                        end else begin
                            write_count <= write_count + 1'b1;
                        end
                    end
                end

                STATE_READY: begin
                    frame_ready <= 1'b1;

                    if (sample_valid) begin
                        overflow <= 1'b1;
                    end

                    if (consume_frame) begin
                        frame_valid  <= 1'b1;
                        frame_start  <= 1'b1;
                        frame_end    <= (FFT_SIZE == 1);
                        frame_index  <= {ADDR_WIDTH{1'b0}};
                        frame_sample <= sample_mem[0];
                        read_count   <= {{ADDR_WIDTH{1'b0}}, 1'b1};
                        state        <= STATE_READ;
                    end
                end

                STATE_READ: begin
                    frame_ready  <= 1'b1;
                    frame_valid  <= 1'b1;
                    frame_start  <= (read_count == 0);
                    frame_end    <= (read_count == FFT_SIZE - 1);
                    frame_index  <= read_count[ADDR_WIDTH-1:0];
                    frame_sample <= sample_mem[read_count[ADDR_WIDTH-1:0]];

                    if (sample_valid) begin
                        overflow <= 1'b1;
                    end

                    if (read_count == FFT_SIZE - 1) begin
                        state       <= STATE_COLLECT;
                        write_count <= {COUNT_WIDTH{1'b0}};
                        read_count  <= {COUNT_WIDTH{1'b0}};
                        frame_ready <= 1'b0;
                        overflow    <= 1'b0;
                    end else begin
                        read_count <= read_count + 1'b1;
                    end
                end

                default: begin
                    state       <= STATE_COLLECT;
                    write_count <= {COUNT_WIDTH{1'b0}};
                    read_count  <= {COUNT_WIDTH{1'b0}};
                end
            endcase
        end
    end

endmodule
