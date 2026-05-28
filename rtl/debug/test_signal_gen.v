module test_signal_gen #(
    parameter integer CLK_FREQ_HZ    = 27_000_000,
    parameter integer SAMPLE_RATE_HZ = 48_000,
    parameter integer AMPLITUDE      = 16_000
)(
    input  wire clk,
    input  wire rst,
    output reg  signed [15:0] sample_out,
    output reg  sample_valid
);

    // Internal diagnostic source. This is not a precise 48 kHz audio generator;
    // SAMPLE_RATE_HZ only controls the logical sample_valid cadence.

    localparam integer SAMPLE_DIV = (CLK_FREQ_HZ / SAMPLE_RATE_HZ) > 0 ?
                                    (CLK_FREQ_HZ / SAMPLE_RATE_HZ) : 1;
    localparam signed [15:0] LOW_AMP  = AMPLITUDE / 2;
    localparam signed [15:0] MID_AMP  = AMPLITUDE / 3;
    localparam signed [15:0] HIGH_AMP = AMPLITUDE / 6;

    reg [31:0] div_cnt;
    reg [7:0]  phase;

    wire signed [15:0] low_component;
    wire signed [15:0] mid_component;
    wire signed [15:0] high_component;
    wire signed [17:0] mixed_sample;

    assign low_component  = phase[7]       ? -LOW_AMP  : LOW_AMP;
    assign mid_component  = phase[4]       ? -MID_AMP  : MID_AMP;
    assign high_component = phase[1]       ? -HIGH_AMP : HIGH_AMP;
    assign mixed_sample   = low_component + mid_component + high_component;

    always @(posedge clk) begin
        if (rst) begin
            div_cnt      <= 32'd0;
            phase        <= 8'd0;
            sample_out   <= 16'sd0;
            sample_valid <= 1'b0;
        end else begin
            sample_valid <= 1'b0;

            if (div_cnt == SAMPLE_DIV - 1) begin
                div_cnt      <= 32'd0;
                phase        <= phase + 8'd1;
                sample_out   <= mixed_sample[15:0];
                sample_valid <= 1'b1;
            end else begin
                div_cnt <= div_cnt + 32'd1;
            end
        end
    end

endmodule
