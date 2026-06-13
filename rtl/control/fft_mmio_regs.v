module fft_mmio_regs #(
    parameter integer FFT_SIZE     = 256,
    parameter integer SAMPLE_WIDTH = 16,
    parameter integer ADDR_WIDTH   = 16,
    parameter integer DATA_WIDTH   = 32,
    parameter integer GAIN_WIDTH   = 16,
    parameter integer INDEX_WIDTH  = 8
) (
    input  wire                              clk,
    input  wire                              rst,

    input  wire                              wr_en,
    input  wire [ADDR_WIDTH-1:0]             wr_addr,
    input  wire [DATA_WIDTH-1:0]             wr_data,

    input  wire                              rd_en,
    input  wire [ADDR_WIDTH-1:0]             rd_addr,
    output reg  [DATA_WIDTH-1:0]             rd_data,

    input  wire                              pipeline_busy,
    input  wire                              pipeline_done,
    input  wire                              pipeline_overflow,
    input  wire                              pipeline_error,

    input  wire                              output_sample_we,
    input  wire [INDEX_WIDTH-1:0]            output_sample_index,
    input  wire signed [SAMPLE_WIDTH-1:0]    output_sample_data,

    input  wire [INDEX_WIDTH-1:0]            input_sample_read_index,
    output wire signed [SAMPLE_WIDTH-1:0]    input_sample_read_data,

    output reg                               start_pulse,
    output reg                               clear_pulse,
    output reg  [DATA_WIDTH-1:0]             mode_reg,

    output reg  signed [GAIN_WIDTH-1:0]      bass_gain,
    output reg  signed [GAIN_WIDTH-1:0]      mid_gain,
    output reg  signed [GAIN_WIDTH-1:0]      treble_gain
);

    localparam [ADDR_WIDTH-1:0] CONTROL_REG        = 16'h0000;
    localparam [ADDR_WIDTH-1:0] STATUS_REG         = 16'h0001;
    localparam [ADDR_WIDTH-1:0] MODE_REG           = 16'h0002;
    localparam [ADDR_WIDTH-1:0] BASS_GAIN_REG      = 16'h0003;
    localparam [ADDR_WIDTH-1:0] MID_GAIN_REG       = 16'h0004;
    localparam [ADDR_WIDTH-1:0] TREBLE_GAIN_REG    = 16'h0005;
    localparam [ADDR_WIDTH-1:0] DEBUG_REG          = 16'h0006;
    localparam [ADDR_WIDTH-1:0] INPUT_SAMPLE_BASE  = 16'h0100;
    localparam [ADDR_WIDTH-1:0] OUTPUT_SAMPLE_BASE = 16'h0200;

    localparam [DATA_WIDTH-1:0] DEBUG_VERSION = 32'h00020000;
    localparam signed [GAIN_WIDTH-1:0] UNITY_GAIN = 16'sd16384;

    reg done_latched = 1'b0;
    reg overflow_latched = 1'b0;
    reg error_latched = 1'b0;

    reg signed [SAMPLE_WIDTH-1:0] input_sample_mem [0:FFT_SIZE-1];
    reg signed [SAMPLE_WIDTH-1:0] output_sample_mem [0:FFT_SIZE-1];

    wire input_addr_hit;
    wire output_addr_hit;
    wire [INDEX_WIDTH-1:0] input_addr_index;
    wire [INDEX_WIDTH-1:0] output_addr_index;
    wire [INDEX_WIDTH-1:0] read_addr_index;

    integer i;

    assign input_addr_hit = (wr_addr >= INPUT_SAMPLE_BASE) &&
                            (wr_addr < INPUT_SAMPLE_BASE + FFT_SIZE);
    assign output_addr_hit = (rd_addr >= OUTPUT_SAMPLE_BASE) &&
                             (rd_addr < OUTPUT_SAMPLE_BASE + FFT_SIZE);
    assign input_addr_index = wr_addr[INDEX_WIDTH-1:0];
    assign output_addr_index = rd_addr[INDEX_WIDTH-1:0];
    assign read_addr_index = rd_addr[INDEX_WIDTH-1:0];
    assign input_sample_read_data = input_sample_mem[input_sample_read_index];

    function [DATA_WIDTH-1:0] sign_extend_sample;
        input signed [SAMPLE_WIDTH-1:0] sample;
        begin
            sign_extend_sample = {{(DATA_WIDTH-SAMPLE_WIDTH)
                                  {sample[SAMPLE_WIDTH-1]}}, sample};
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            rd_data <= {DATA_WIDTH{1'b0}};
            start_pulse <= 1'b0;
            clear_pulse <= 1'b0;
            mode_reg <= {DATA_WIDTH{1'b0}};
            bass_gain <= UNITY_GAIN;
            mid_gain <= UNITY_GAIN;
            treble_gain <= UNITY_GAIN;
            done_latched <= 1'b0;
            overflow_latched <= 1'b0;
            error_latched <= 1'b0;

            for (i = 0; i < FFT_SIZE; i = i + 1) begin
                input_sample_mem[i] <= {SAMPLE_WIDTH{1'b0}};
                output_sample_mem[i] <= {SAMPLE_WIDTH{1'b0}};
            end
        end else begin
            start_pulse <= 1'b0;
            clear_pulse <= 1'b0;

            if (pipeline_done) begin
                done_latched <= 1'b1;
            end

            if (pipeline_overflow) begin
                overflow_latched <= 1'b1;
            end

            if (pipeline_error) begin
                error_latched <= 1'b1;
            end

            if (output_sample_we) begin
                output_sample_mem[output_sample_index] <= output_sample_data;
            end

            if (wr_en) begin
                if (input_addr_hit) begin
                    input_sample_mem[input_addr_index] <=
                        wr_data[SAMPLE_WIDTH-1:0];
                end else begin
                    case (wr_addr)
                        CONTROL_REG: begin
                            if (wr_data[0]) begin
                                start_pulse <= 1'b1;
                            end

                            if (wr_data[1]) begin
                                clear_pulse <= 1'b1;
                                done_latched <= 1'b0;
                                overflow_latched <= 1'b0;
                                error_latched <= 1'b0;

                                for (i = 0; i < FFT_SIZE; i = i + 1) begin
                                    output_sample_mem[i] <= {SAMPLE_WIDTH{1'b0}};
                                end
                            end
                        end

                        MODE_REG: begin
                            mode_reg <= wr_data;
                        end

                        BASS_GAIN_REG: begin
                            bass_gain <= wr_data[GAIN_WIDTH-1:0];
                        end

                        MID_GAIN_REG: begin
                            mid_gain <= wr_data[GAIN_WIDTH-1:0];
                        end

                        TREBLE_GAIN_REG: begin
                            treble_gain <= wr_data[GAIN_WIDTH-1:0];
                        end

                        default: begin
                        end
                    endcase
                end
            end

            if (rd_en) begin
                if (rd_addr >= INPUT_SAMPLE_BASE &&
                    rd_addr < INPUT_SAMPLE_BASE + FFT_SIZE) begin
                    rd_data <= sign_extend_sample(
                        input_sample_mem[read_addr_index]
                    );
                end else if (output_addr_hit) begin
                    rd_data <= sign_extend_sample(
                        output_sample_mem[output_addr_index]
                    );
                end else begin
                    case (rd_addr)
                        CONTROL_REG: begin
                            rd_data <= {DATA_WIDTH{1'b0}};
                        end

                        STATUS_REG: begin
                            rd_data <= {{(DATA_WIDTH-4){1'b0}},
                                        error_latched,
                                        overflow_latched,
                                        done_latched,
                                        pipeline_busy};
                        end

                        MODE_REG: begin
                            rd_data <= mode_reg;
                        end

                        BASS_GAIN_REG: begin
                            rd_data <= {{(DATA_WIDTH-GAIN_WIDTH)
                                        {bass_gain[GAIN_WIDTH-1]}},
                                        bass_gain};
                        end

                        MID_GAIN_REG: begin
                            rd_data <= {{(DATA_WIDTH-GAIN_WIDTH)
                                        {mid_gain[GAIN_WIDTH-1]}},
                                        mid_gain};
                        end

                        TREBLE_GAIN_REG: begin
                            rd_data <= {{(DATA_WIDTH-GAIN_WIDTH)
                                        {treble_gain[GAIN_WIDTH-1]}},
                                        treble_gain};
                        end

                        DEBUG_REG: begin
                            rd_data <= DEBUG_VERSION;
                        end

                        default: begin
                            rd_data <= {DATA_WIDTH{1'b0}};
                        end
                    endcase
                end
            end
        end
    end

endmodule
