module gain_lut_q2_14 (
    input  wire signed [4:0] gain_level,
    output reg  [15:0] gain_q2_14
);

    localparam signed [4:0] GAIN_MIN = -5'sd6;
    localparam signed [4:0] GAIN_MAX =  5'sd6;

    always @* begin
        if (gain_level < GAIN_MIN) begin
            gain_q2_14 = 16'd8192;
        end else if (gain_level > GAIN_MAX) begin
            gain_q2_14 = 16'd24576;
        end else begin
            case (gain_level)
                -5'sd6: gain_q2_14 = 16'd8192;
                -5'sd5: gain_q2_14 = 16'd9557;
                -5'sd4: gain_q2_14 = 16'd10923;
                -5'sd3: gain_q2_14 = 16'd12288;
                -5'sd2: gain_q2_14 = 16'd13653;
                -5'sd1: gain_q2_14 = 16'd15019;
                 5'sd0: gain_q2_14 = 16'd16384;
                 5'sd1: gain_q2_14 = 16'd17749;
                 5'sd2: gain_q2_14 = 16'd19115;
                 5'sd3: gain_q2_14 = 16'd20480;
                 5'sd4: gain_q2_14 = 16'd21845;
                 5'sd5: gain_q2_14 = 16'd23211;
                 5'sd6: gain_q2_14 = 16'd24576;
                default: gain_q2_14 = 16'd16384;
            endcase
        end
    end

endmodule
