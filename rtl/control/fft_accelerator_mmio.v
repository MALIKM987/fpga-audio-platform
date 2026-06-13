module fft_accelerator_mmio #(
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
    output wire [DATA_WIDTH-1:0]             rd_data,

    output wire                              busy,
    output wire                              done,
    output wire                              overflow,
    output wire                              error
);

    localparam [1:0] STATE_IDLE = 2'd0;
    localparam [1:0] STATE_FEED = 2'd1;
    localparam [1:0] STATE_WAIT = 2'd2;

    reg [1:0] state = STATE_IDLE;
    reg [INDEX_WIDTH-1:0] feed_index = {INDEX_WIDTH{1'b0}};
    reg start_rejected_pulse = 1'b0;
    reg pipeline_sample_valid = 1'b0;
    reg pipeline_start_request = 1'b0;

    wire start_pulse;
    wire clear_pulse;
    wire [DATA_WIDTH-1:0] mode_reg;
    wire signed [GAIN_WIDTH-1:0] bass_gain;
    wire signed [GAIN_WIDTH-1:0] mid_gain;
    wire signed [GAIN_WIDTH-1:0] treble_gain;
    wire signed [SAMPLE_WIDTH-1:0] input_sample_read_data;

    wire pipeline_rst;
    wire pipeline_out_valid;
    wire [INDEX_WIDTH-1:0] pipeline_out_index;
    wire signed [SAMPLE_WIDTH-1:0] pipeline_sample_out;
    wire pipeline_busy;
    wire pipeline_done;
    wire pipeline_overflow;
    wire core_busy;

    assign pipeline_rst = rst | clear_pulse;
    assign core_busy = (state != STATE_IDLE) | pipeline_busy;
    assign busy = core_busy;
    assign done = pipeline_done;
    assign overflow = pipeline_overflow;
    assign error = start_rejected_pulse;

    fft_mmio_regs #(
        .FFT_SIZE(FFT_SIZE),
        .SAMPLE_WIDTH(SAMPLE_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .GAIN_WIDTH(GAIN_WIDTH),
        .INDEX_WIDTH(INDEX_WIDTH)
    ) regs_inst (
        .clk(clk),
        .rst(rst),
        .wr_en(wr_en),
        .wr_addr(wr_addr),
        .wr_data(wr_data),
        .rd_en(rd_en),
        .rd_addr(rd_addr),
        .rd_data(rd_data),
        .pipeline_busy(core_busy),
        .pipeline_done(pipeline_done),
        .pipeline_overflow(pipeline_overflow),
        .pipeline_error(start_rejected_pulse),
        .output_sample_we(pipeline_out_valid),
        .output_sample_index(pipeline_out_index),
        .output_sample_data(pipeline_sample_out),
        .input_sample_read_index(feed_index),
        .input_sample_read_data(input_sample_read_data),
        .start_pulse(start_pulse),
        .clear_pulse(clear_pulse),
        .mode_reg(mode_reg),
        .bass_gain(bass_gain),
        .mid_gain(mid_gain),
        .treble_gain(treble_gain)
    );

    fft_ifft_pipeline #(
        .FFT_SIZE(FFT_SIZE),
        .SAMPLE_WIDTH(SAMPLE_WIDTH),
        .GAIN_WIDTH(GAIN_WIDTH),
        .INDEX_WIDTH(INDEX_WIDTH),
        .AUTO_START(0)
    ) pipeline_inst (
        .clk(clk),
        .rst(pipeline_rst),
        .sample_valid(pipeline_sample_valid),
        .sample_in(input_sample_read_data),
        .bass_gain(bass_gain),
        .mid_gain(mid_gain),
        .treble_gain(treble_gain),
        .start_process(pipeline_start_request),
        .out_valid(pipeline_out_valid),
        .out_index(pipeline_out_index),
        .sample_out(pipeline_sample_out),
        .busy(pipeline_busy),
        .done(pipeline_done),
        .overflow(pipeline_overflow)
    );

    always @(posedge clk) begin
        if (rst) begin
            state <= STATE_IDLE;
            feed_index <= {INDEX_WIDTH{1'b0}};
            start_rejected_pulse <= 1'b0;
            pipeline_sample_valid <= 1'b0;
            pipeline_start_request <= 1'b0;
        end else begin
            start_rejected_pulse <= 1'b0;
            pipeline_sample_valid <= 1'b0;

            if (clear_pulse) begin
                state <= STATE_IDLE;
                feed_index <= {INDEX_WIDTH{1'b0}};
                pipeline_start_request <= 1'b0;
            end else begin
                case (state)
                    STATE_IDLE: begin
                        pipeline_start_request <= 1'b0;

                        if (start_pulse) begin
                            if (pipeline_busy) begin
                                start_rejected_pulse <= 1'b1;
                            end else begin
                                state <= STATE_FEED;
                                feed_index <= {INDEX_WIDTH{1'b0}};
                                pipeline_start_request <= 1'b1;
                            end
                        end
                    end

                    STATE_FEED: begin
                        pipeline_start_request <= 1'b1;
                        pipeline_sample_valid <= 1'b1;

                        if (start_pulse) begin
                            start_rejected_pulse <= 1'b1;
                        end

                        if (feed_index == FFT_SIZE - 1) begin
                            feed_index <= {INDEX_WIDTH{1'b0}};
                            state <= STATE_WAIT;
                        end else begin
                            feed_index <= feed_index + 1'b1;
                        end
                    end

                    STATE_WAIT: begin
                        pipeline_start_request <= 1'b1;

                        if (start_pulse) begin
                            start_rejected_pulse <= 1'b1;
                        end

                        if (pipeline_done) begin
                            pipeline_start_request <= 1'b0;
                            state <= STATE_IDLE;
                        end
                    end

                    default: begin
                        state <= STATE_IDLE;
                        pipeline_start_request <= 1'b0;
                    end
                endcase
            end
        end
    end

endmodule
