module fft_accelerator_core #(
    parameter integer FFT_SIZE     = 256,
    parameter integer SAMPLE_WIDTH = 16,
    parameter integer ADDR_WIDTH   = 4,
    parameter integer DATA_WIDTH   = 32,
    parameter integer GAIN_WIDTH   = 16
) (
    input  wire                              clk,
    input  wire                              rst,

    input  wire                              wr_en,
    input  wire [ADDR_WIDTH-1:0]             wr_addr,
    input  wire [DATA_WIDTH-1:0]             wr_data,

    input  wire                              rd_en,
    input  wire [ADDR_WIDTH-1:0]             rd_addr,
    output wire [DATA_WIDTH-1:0]             rd_data,

    input  wire                              sample_valid,
    input  wire signed [SAMPLE_WIDTH-1:0]    sample_in,

    output wire                              out_valid,
    output wire [7:0]                        out_index,
    output wire signed [SAMPLE_WIDTH-1:0]    sample_out,

    output wire                              busy,
    output wire                              done,
    output wire                              overflow
);

    localparam integer INDEX_WIDTH = 8;

    wire start_pulse;
    wire bypass_enable;
    wire spectral_enable;
    wire signed [GAIN_WIDTH-1:0] bass_gain;
    wire signed [GAIN_WIDTH-1:0] mid_gain;
    wire signed [GAIN_WIDTH-1:0] treble_gain;
    wire [DATA_WIDTH-1:0] test_select;

    reg start_pending;

    wire pipeline_busy;
    wire pipeline_done;
    wire pipeline_overflow;
    wire pipeline_error;
    wire core_busy;

    assign pipeline_error = 1'b0;
    assign core_busy = start_pending | pipeline_busy;

    assign busy = core_busy;
    assign done = pipeline_done;
    assign overflow = pipeline_overflow;

    fft_control_regs #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .GAIN_WIDTH(GAIN_WIDTH)
    ) control_regs_inst (
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
        .pipeline_error(pipeline_error),
        .start_pulse(start_pulse),
        .bypass_enable(bypass_enable),
        .spectral_enable(spectral_enable),
        .bass_gain(bass_gain),
        .mid_gain(mid_gain),
        .treble_gain(treble_gain),
        .test_select(test_select)
    );

    fft_ifft_pipeline #(
        .FFT_SIZE(FFT_SIZE),
        .SAMPLE_WIDTH(SAMPLE_WIDTH),
        .GAIN_WIDTH(GAIN_WIDTH),
        .INDEX_WIDTH(INDEX_WIDTH),
        .AUTO_START(0)
    ) pipeline_inst (
        .clk(clk),
        .rst(rst),
        .sample_valid(sample_valid),
        .sample_in(sample_in),
        .bass_gain(bass_gain),
        .mid_gain(mid_gain),
        .treble_gain(treble_gain),
        .start_process(start_pending),
        .out_valid(out_valid),
        .out_index(out_index),
        .sample_out(sample_out),
        .busy(pipeline_busy),
        .done(pipeline_done),
        .overflow(pipeline_overflow)
    );

    always @(posedge clk) begin
        if (rst) begin
            start_pending <= 1'b0;
        end else begin
            if (start_pulse) begin
                start_pending <= 1'b1;
            end

            if (pipeline_done) begin
                start_pending <= 1'b0;
            end
        end
    end

endmodule
