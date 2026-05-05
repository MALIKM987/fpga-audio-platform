module audio_param_regs (
    input  wire clk,
    input  wire rst,
    input  wire vol_up_pulse,
    input  wire vol_down_pulse,
    input  wire bass_up_pulse,
    input  wire bass_down_pulse,
    input  wire mid_up_pulse,
    input  wire mid_down_pulse,
    input  wire treble_up_pulse,
    input  wire treble_down_pulse,
    input  wire channel_select_pulse,

    output reg        active_channel,
    output wire       led_left_active,
    output wire       led_right_active,
    output reg  [3:0] volume_L,
    output reg  [3:0] volume_R,
    output reg signed [4:0] bass_gain_L,
    output reg signed [4:0] bass_gain_R,
    output reg signed [4:0] mid_gain_L,
    output reg signed [4:0] mid_gain_R,
    output reg signed [4:0] treble_gain_L,
    output reg signed [4:0] treble_gain_R
);

    localparam LEFT  = 1'b0;
    localparam RIGHT = 1'b1;

    localparam [3:0] VOLUME_MIN     = 4'd0;
    localparam [3:0] VOLUME_MAX     = 4'd15;
    localparam [3:0] VOLUME_DEFAULT = 4'd8;

    localparam signed [4:0] GAIN_MIN     = -5'sd6;
    localparam signed [4:0] GAIN_MAX     =  5'sd6;
    localparam signed [4:0] GAIN_DEFAULT =  5'sd0;

    assign led_left_active  = (active_channel == LEFT);
    assign led_right_active = (active_channel == RIGHT);

    function [3:0] next_volume;
        input [3:0] current_value;
        input       increase;
        input       decrease;
        begin
            if (increase && !decrease) begin
                if (current_value < VOLUME_MAX)
                    next_volume = current_value + 1'b1;
                else
                    next_volume = VOLUME_MAX;
            end else if (decrease && !increase) begin
                if (current_value > VOLUME_MIN)
                    next_volume = current_value - 1'b1;
                else
                    next_volume = VOLUME_MIN;
            end else begin
                next_volume = current_value;
            end
        end
    endfunction

    function signed [4:0] next_gain;
        input signed [4:0] current_value;
        input              increase;
        input              decrease;
        begin
            if (increase && !decrease) begin
                if (current_value < GAIN_MAX)
                    next_gain = current_value + 5'sd1;
                else
                    next_gain = GAIN_MAX;
            end else if (decrease && !increase) begin
                if (current_value > GAIN_MIN)
                    next_gain = current_value - 5'sd1;
                else
                    next_gain = GAIN_MIN;
            end else begin
                next_gain = current_value;
            end
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            active_channel <= LEFT;
            volume_L       <= VOLUME_DEFAULT;
            volume_R       <= VOLUME_DEFAULT;
            bass_gain_L    <= GAIN_DEFAULT;
            bass_gain_R    <= GAIN_DEFAULT;
            mid_gain_L     <= GAIN_DEFAULT;
            mid_gain_R     <= GAIN_DEFAULT;
            treble_gain_L  <= GAIN_DEFAULT;
            treble_gain_R  <= GAIN_DEFAULT;
        end else begin
            if (channel_select_pulse)
                active_channel <= ~active_channel;

            if (active_channel == LEFT) begin
                volume_L      <= next_volume(volume_L, vol_up_pulse, vol_down_pulse);
                bass_gain_L   <= next_gain(bass_gain_L, bass_up_pulse, bass_down_pulse);
                mid_gain_L    <= next_gain(mid_gain_L, mid_up_pulse, mid_down_pulse);
                treble_gain_L <= next_gain(treble_gain_L, treble_up_pulse, treble_down_pulse);
            end else begin
                volume_R      <= next_volume(volume_R, vol_up_pulse, vol_down_pulse);
                bass_gain_R   <= next_gain(bass_gain_R, bass_up_pulse, bass_down_pulse);
                mid_gain_R    <= next_gain(mid_gain_R, mid_up_pulse, mid_down_pulse);
                treble_gain_R <= next_gain(treble_gain_R, treble_up_pulse, treble_down_pulse);
            end
        end
    end

endmodule
