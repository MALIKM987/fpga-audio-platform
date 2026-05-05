module volume_lut_q2_14 (
    input  wire [3:0] volume_level,
    output reg  [15:0] volume_q2_14
);

    always @* begin
        case (volume_level)
            4'd0:  volume_q2_14 = 16'd0;
            4'd1:  volume_q2_14 = 16'd2048;
            4'd2:  volume_q2_14 = 16'd4096;
            4'd3:  volume_q2_14 = 16'd6144;
            4'd4:  volume_q2_14 = 16'd8192;
            4'd5:  volume_q2_14 = 16'd10240;
            4'd6:  volume_q2_14 = 16'd12288;
            4'd7:  volume_q2_14 = 16'd14336;
            4'd8:  volume_q2_14 = 16'd16384;
            4'd9:  volume_q2_14 = 16'd18432;
            4'd10: volume_q2_14 = 16'd20480;
            4'd11: volume_q2_14 = 16'd22528;
            4'd12: volume_q2_14 = 16'd24576;
            4'd13: volume_q2_14 = 16'd26624;
            4'd14: volume_q2_14 = 16'd28672;
            4'd15: volume_q2_14 = 16'd30720;
            default: volume_q2_14 = 16'd16384;
        endcase
    end

endmodule
