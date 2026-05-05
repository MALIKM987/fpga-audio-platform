module tone_gen #(
    parameter integer CLK_FREQ_HZ  = 27_000_000,
    parameter integer TONE_FREQ_HZ = 1000
)(
    input  wire        clk,
    input  wire        rst,
    output reg  signed [15:0] sample
);

    localparam integer HALF_PERIOD = CLK_FREQ_HZ / (2 * TONE_FREQ_HZ);

    reg [31:0] cnt = 32'd0;
    reg        tone = 1'b0;

    always @(posedge clk) begin
        if (rst) begin
            cnt    <= 32'd0;
            tone   <= 1'b0;
            sample <= 16'd0;
        end else begin
            if (cnt == HALF_PERIOD - 1) begin
                cnt  <= 32'd0;
                tone <= ~tone;
            end else begin
                cnt <= cnt + 1'b1;
            end

            if (tone)
                sample <= 16'sd12000;
            else
                sample <= -16'sd12000;
        end
    end

endmodule
