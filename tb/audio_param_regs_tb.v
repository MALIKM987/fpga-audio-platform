`timescale 1ns/1ps

// Sanity and saturation test for audio_param_regs:
// checks reset defaults, active channel routing and volume/EQ saturation.
module audio_param_regs_tb;

    reg clk = 1'b0;
    reg rst = 1'b1;

    reg vol_up_pulse = 1'b0;
    reg vol_down_pulse = 1'b0;
    reg bass_up_pulse = 1'b0;
    reg bass_down_pulse = 1'b0;
    reg mid_up_pulse = 1'b0;
    reg mid_down_pulse = 1'b0;
    reg treble_up_pulse = 1'b0;
    reg treble_down_pulse = 1'b0;
    reg channel_select_pulse = 1'b0;

    wire active_channel;
    wire led_left_active;
    wire led_right_active;
    wire [3:0] volume_L;
    wire [3:0] volume_R;
    wire signed [4:0] bass_gain_L;
    wire signed [4:0] bass_gain_R;
    wire signed [4:0] mid_gain_L;
    wire signed [4:0] mid_gain_R;
    wire signed [4:0] treble_gain_L;
    wire signed [4:0] treble_gain_R;

    integer errors;
    integer i;

    audio_param_regs dut (
        .clk(clk),
        .rst(rst),
        .vol_up_pulse(vol_up_pulse),
        .vol_down_pulse(vol_down_pulse),
        .bass_up_pulse(bass_up_pulse),
        .bass_down_pulse(bass_down_pulse),
        .mid_up_pulse(mid_up_pulse),
        .mid_down_pulse(mid_down_pulse),
        .treble_up_pulse(treble_up_pulse),
        .treble_down_pulse(treble_down_pulse),
        .channel_select_pulse(channel_select_pulse),
        .active_channel(active_channel),
        .led_left_active(led_left_active),
        .led_right_active(led_right_active),
        .volume_L(volume_L),
        .volume_R(volume_R),
        .bass_gain_L(bass_gain_L),
        .bass_gain_R(bass_gain_R),
        .mid_gain_L(mid_gain_L),
        .mid_gain_R(mid_gain_R),
        .treble_gain_L(treble_gain_L),
        .treble_gain_R(treble_gain_R)
    );

    always #5 clk = ~clk;

    task expect_bit;
        input actual;
        input expected;
        input [255:0] message;
        begin
            if (actual !== expected) begin
                $display("FAIL: %0s actual=%0b expected=%0b", message, actual, expected);
                errors = errors + 1;
            end
        end
    endtask

    task expect_volume;
        input [3:0] actual;
        input [3:0] expected;
        input [255:0] message;
        begin
            if (actual !== expected) begin
                $display("FAIL: %0s actual=%0d expected=%0d", message, actual, expected);
                errors = errors + 1;
            end
        end
    endtask

    task expect_gain;
        input signed [4:0] actual;
        input signed [4:0] expected;
        input [255:0] message;
        begin
            if (actual !== expected) begin
                $display("FAIL: %0s actual=%0d expected=%0d", message, actual, expected);
                errors = errors + 1;
            end
        end
    endtask

    task pulse_vol_up;
        begin
            @(negedge clk);
            vol_up_pulse = 1'b1;
            @(negedge clk);
            vol_up_pulse = 1'b0;
            @(negedge clk);
        end
    endtask

    task pulse_vol_down;
        begin
            @(negedge clk);
            vol_down_pulse = 1'b1;
            @(negedge clk);
            vol_down_pulse = 1'b0;
            @(negedge clk);
        end
    endtask

    task pulse_bass_up;
        begin
            @(negedge clk);
            bass_up_pulse = 1'b1;
            @(negedge clk);
            bass_up_pulse = 1'b0;
            @(negedge clk);
        end
    endtask

    task pulse_bass_down;
        begin
            @(negedge clk);
            bass_down_pulse = 1'b1;
            @(negedge clk);
            bass_down_pulse = 1'b0;
            @(negedge clk);
        end
    endtask

    task pulse_mid_up;
        begin
            @(negedge clk);
            mid_up_pulse = 1'b1;
            @(negedge clk);
            mid_up_pulse = 1'b0;
            @(negedge clk);
        end
    endtask

    task pulse_mid_down;
        begin
            @(negedge clk);
            mid_down_pulse = 1'b1;
            @(negedge clk);
            mid_down_pulse = 1'b0;
            @(negedge clk);
        end
    endtask

    task pulse_treble_up;
        begin
            @(negedge clk);
            treble_up_pulse = 1'b1;
            @(negedge clk);
            treble_up_pulse = 1'b0;
            @(negedge clk);
        end
    endtask

    task pulse_treble_down;
        begin
            @(negedge clk);
            treble_down_pulse = 1'b1;
            @(negedge clk);
            treble_down_pulse = 1'b0;
            @(negedge clk);
        end
    endtask

    task pulse_channel_select;
        begin
            @(negedge clk);
            channel_select_pulse = 1'b1;
            @(negedge clk);
            channel_select_pulse = 1'b0;
            @(negedge clk);
        end
    endtask

    initial begin
        errors = 0;

        repeat (3) @(negedge clk);
        rst = 1'b0;
        repeat (2) @(negedge clk);

        expect_bit(active_channel, 1'b0, "default active channel is LEFT");
        expect_bit(led_left_active, 1'b1, "left LED active after reset");
        expect_bit(led_right_active, 1'b0, "right LED inactive after reset");
        expect_volume(volume_L, 4'd8, "default volume_L");
        expect_volume(volume_R, 4'd8, "default volume_R");
        expect_gain(bass_gain_L, 5'sd0, "default bass_gain_L");
        expect_gain(bass_gain_R, 5'sd0, "default bass_gain_R");
        expect_gain(mid_gain_L, 5'sd0, "default mid_gain_L");
        expect_gain(mid_gain_R, 5'sd0, "default mid_gain_R");
        expect_gain(treble_gain_L, 5'sd0, "default treble_gain_L");
        expect_gain(treble_gain_R, 5'sd0, "default treble_gain_R");

        pulse_vol_up;
        expect_volume(volume_L, 4'd9, "volume_L increments while LEFT is active");
        expect_volume(volume_R, 4'd8, "volume_R unchanged while LEFT is active");

        pulse_channel_select;
        expect_bit(active_channel, 1'b1, "CHANNEL_SELECT switches to RIGHT");
        expect_bit(led_left_active, 1'b0, "left LED inactive after switch");
        expect_bit(led_right_active, 1'b1, "right LED active after switch");

        pulse_vol_up;
        expect_volume(volume_R, 4'd9, "volume_R increments while RIGHT is active");
        expect_volume(volume_L, 4'd9, "volume_L unchanged while RIGHT is active");

        pulse_bass_up;
        pulse_mid_down;
        pulse_treble_up;
        expect_gain(bass_gain_R, 5'sd1, "bass_gain_R increments");
        expect_gain(mid_gain_R, -5'sd1, "mid_gain_R decrements");
        expect_gain(treble_gain_R, 5'sd1, "treble_gain_R increments");
        expect_gain(bass_gain_L, 5'sd0, "bass_gain_L unchanged during RIGHT edit");
        expect_gain(mid_gain_L, 5'sd0, "mid_gain_L unchanged during RIGHT edit");
        expect_gain(treble_gain_L, 5'sd0, "treble_gain_L unchanged during RIGHT edit");

        for (i = 0; i < 20; i = i + 1)
            pulse_vol_up;
        expect_volume(volume_R, 4'd15, "volume_R saturates at 15");

        for (i = 0; i < 30; i = i + 1)
            pulse_vol_down;
        expect_volume(volume_R, 4'd0, "volume_R saturates at 0");

        for (i = 0; i < 20; i = i + 1)
            pulse_bass_up;
        expect_gain(bass_gain_R, 5'sd6, "bass_gain_R saturates at +6");

        for (i = 0; i < 30; i = i + 1)
            pulse_bass_down;
        expect_gain(bass_gain_R, -5'sd6, "bass_gain_R saturates at -6");

        for (i = 0; i < 20; i = i + 1)
            pulse_mid_down;
        expect_gain(mid_gain_R, -5'sd6, "mid_gain_R saturates at -6");

        for (i = 0; i < 30; i = i + 1)
            pulse_mid_up;
        expect_gain(mid_gain_R, 5'sd6, "mid_gain_R saturates at +6");

        for (i = 0; i < 20; i = i + 1)
            pulse_treble_up;
        expect_gain(treble_gain_R, 5'sd6, "treble_gain_R saturates at +6");

        for (i = 0; i < 30; i = i + 1)
            pulse_treble_down;
        expect_gain(treble_gain_R, -5'sd6, "treble_gain_R saturates at -6");

        expect_volume(volume_L, 4'd9, "volume_L still unchanged after RIGHT saturation tests");
        expect_gain(bass_gain_L, 5'sd0, "bass_gain_L still unchanged");
        expect_gain(mid_gain_L, 5'sd0, "mid_gain_L still unchanged");
        expect_gain(treble_gain_L, 5'sd0, "treble_gain_L still unchanged");

        if (errors == 0)
            $display("PASS: audio_param_regs_tb");
        else
            $display("FAIL: audio_param_regs_tb errors=%0d", errors);

        $finish;
    end

endmodule
