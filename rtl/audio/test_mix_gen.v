module test_mix_gen #(
    parameter integer CLK_FREQ_HZ  = 27000000,
    parameter integer LOW_FREQ_HZ  = 100,
    parameter integer MID_FREQ_HZ  = 1000,
    parameter integer HIGH_FREQ_HZ = 6000
)(
    input  wire clk,
    input  wire rst,
    output reg  signed [15:0] sample_out,
    output reg  sample_valid
);

    localparam integer LOW_HALF_RAW  = CLK_FREQ_HZ / (2 * LOW_FREQ_HZ);
    localparam integer MID_HALF_RAW  = CLK_FREQ_HZ / (2 * MID_FREQ_HZ);
    localparam integer HIGH_HALF_RAW = CLK_FREQ_HZ / (2 * HIGH_FREQ_HZ);
    localparam integer LOW_HALF_PERIOD  = (LOW_HALF_RAW < 1) ? 1 : LOW_HALF_RAW;
    localparam integer MID_HALF_PERIOD  = (MID_HALF_RAW < 1) ? 1 : MID_HALF_RAW;
    localparam integer HIGH_HALF_PERIOD = (HIGH_HALF_RAW < 1) ? 1 : HIGH_HALF_RAW;

    reg [31:0] low_count;
    reg [31:0] mid_count;
    reg [31:0] high_count;
    reg low_square;
    reg mid_square;
    reg high_square;

    wire signed [15:0] low_component;
    wire signed [15:0] mid_component;
    wire signed [15:0] high_component;
    wire signed [17:0] mixed_sample;

    assign low_component  = low_square  ? 16'sd5000 : -16'sd5000;
    assign mid_component  = mid_square  ? 16'sd3500 : -16'sd3500;
    assign high_component = high_square ? 16'sd2500 : -16'sd2500;
    assign mixed_sample = low_component + mid_component + high_component;

    // Test signal for the time-domain EQ. A single tone does not exercise all
    // bands, so this generator mixes low, mid and high square-wave components.
    always @(posedge clk) begin
        if (rst) begin
            low_count    <= 32'd0;
            mid_count    <= 32'd0;
            high_count   <= 32'd0;
            low_square   <= 1'b0;
            mid_square   <= 1'b0;
            high_square  <= 1'b0;
            sample_out   <= 16'sd0;
            sample_valid <= 1'b0;
        end else begin
            sample_valid <= 1'b1;
            sample_out <= mixed_sample[15:0];

            if (low_count == LOW_HALF_PERIOD - 1) begin
                low_count <= 32'd0;
                low_square <= ~low_square;
            end else begin
                low_count <= low_count + 1'b1;
            end

            if (mid_count == MID_HALF_PERIOD - 1) begin
                mid_count <= 32'd0;
                mid_square <= ~mid_square;
            end else begin
                mid_count <= mid_count + 1'b1;
            end

            if (high_count == HIGH_HALF_PERIOD - 1) begin
                high_count <= 32'd0;
                high_square <= ~high_square;
            end else begin
                high_count <= high_count + 1'b1;
            end
        end
    end

endmodule
