module volume_control (
    input  wire clk,
    input  wire rst,
    input  wire signed [15:0] sample_in,
    input  wire sample_valid,
    input  wire [3:0] volume_level,
    output reg  signed [15:0] sample_out,
    output reg  sample_out_valid
);

    wire [15:0] volume_q2_14;
    wire signed [16:0] volume_q2_14_signed;
    wire signed [32:0] sample_in_ext;
    wire signed [32:0] volume_q2_14_ext;
    wire signed [32:0] product_next;
    reg  signed [32:0] product_stage;
    reg                valid_stage;
    wire signed [32:0] scaled_stage;

    assign volume_q2_14_signed = {1'b0, volume_q2_14};
    assign sample_in_ext = {{17{sample_in[15]}}, sample_in};
    assign volume_q2_14_ext = {16'd0, volume_q2_14_signed};
    assign product_next = sample_in_ext * volume_q2_14_ext;
    assign scaled_stage = product_stage >>> 14;

    volume_lut_q2_14 u_volume_lut_q2_14 (
        .volume_level(volume_level),
        .volume_q2_14(volume_q2_14)
    );

    // Pipeline latency: one clk cycle from sample_valid to sample_out_valid.
    always @(posedge clk) begin
        if (rst) begin
            product_stage    <= 33'sd0;
            valid_stage      <= 1'b0;
            sample_out       <= 16'sd0;
            sample_out_valid <= 1'b0;
        end else begin
            product_stage    <= product_next;
            valid_stage      <= sample_valid;
            sample_out_valid <= valid_stage;

            if (valid_stage) begin
                if (scaled_stage > 33'sd32767)
                    sample_out <= 16'sh7fff;
                else if (scaled_stage < -33'sd32768)
                    sample_out <= 16'sh8000;
                else
                    sample_out <= scaled_stage[15:0];
            end
        end
    end

endmodule
