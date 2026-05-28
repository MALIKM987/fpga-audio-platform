module auto_param_controller #(
    parameter integer MODE_PERIOD_CYCLES = 27_000_000
)(
    input  wire clk,
    input  wire rst,
    output reg  [2:0] mode,
    output reg  [3:0] volume_gain,
    output reg  signed [4:0] bass_gain,
    output reg  signed [4:0] mid_gain,
    output reg  signed [4:0] treble_gain
);

    reg [31:0] period_cnt;

    always @* begin
        case (mode)
            3'd1: begin
                volume_gain = 4'd8;
                bass_gain   = 5'sd3;
                mid_gain    = 5'sd0;
                treble_gain = 5'sd0;
            end
            3'd2: begin
                volume_gain = 4'd8;
                bass_gain   = 5'sd0;
                mid_gain    = 5'sd3;
                treble_gain = 5'sd0;
            end
            3'd3: begin
                volume_gain = 4'd8;
                bass_gain   = 5'sd0;
                mid_gain    = 5'sd0;
                treble_gain = 5'sd3;
            end
            3'd4: begin
                volume_gain = 4'd15;
                bass_gain   = 5'sd3;
                mid_gain    = 5'sd3;
                treble_gain = 5'sd3;
            end
            default: begin
                volume_gain = 4'd8;
                bass_gain   = 5'sd0;
                mid_gain    = 5'sd0;
                treble_gain = 5'sd0;
            end
        endcase
    end

    always @(posedge clk) begin
        if (rst) begin
            period_cnt <= 32'd0;
            mode       <= 3'd0;
        end else begin
            if (period_cnt == MODE_PERIOD_CYCLES - 1) begin
                period_cnt <= 32'd0;
                if (mode == 3'd4) begin
                    mode <= 3'd0;
                end else begin
                    mode <= mode + 3'd1;
                end
            end else begin
                period_cnt <= period_cnt + 32'd1;
            end
        end
    end

endmodule
