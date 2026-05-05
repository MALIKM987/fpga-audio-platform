`timescale 1ns/1ps

// Sanity test for eq3band_stereo:
// checks independent L/R gains and independent clipping flags.
module eq3band_stereo_tb;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg signed [15:0] sample_left_in = 16'sd0;
    reg signed [15:0] sample_right_in = 16'sd0;
    reg sample_valid = 1'b0;
    reg signed [4:0] bass_gain_L = 5'sd0;
    reg signed [4:0] mid_gain_L = 5'sd0;
    reg signed [4:0] treble_gain_L = 5'sd0;
    reg signed [4:0] bass_gain_R = 5'sd0;
    reg signed [4:0] mid_gain_R = 5'sd0;
    reg signed [4:0] treble_gain_R = 5'sd0;

    wire signed [15:0] sample_left_out;
    wire signed [15:0] sample_right_out;
    wire sample_out_valid;
    wire clip_L;
    wire clip_R;

    integer errors;
    integer k;
    integer clip_l_seen;
    integer clip_r_seen;
    reg signed [15:0] last_left;
    reg signed [15:0] last_right;

    eq3band_stereo #(
        .LOW_SHIFT(3),
        .HIGH_SHIFT(2)
    ) dut (
        .clk(clk),
        .rst(rst),
        .sample_left_in(sample_left_in),
        .sample_right_in(sample_right_in),
        .sample_valid(sample_valid),
        .bass_gain_L(bass_gain_L),
        .mid_gain_L(mid_gain_L),
        .treble_gain_L(treble_gain_L),
        .bass_gain_R(bass_gain_R),
        .mid_gain_R(mid_gain_R),
        .treble_gain_R(treble_gain_R),
        .sample_left_out(sample_left_out),
        .sample_right_out(sample_right_out),
        .sample_out_valid(sample_out_valid),
        .clip_L(clip_L),
        .clip_R(clip_R)
    );

    always #5 clk = ~clk;

    task reset_dut;
        begin
            @(negedge clk);
            rst = 1'b1;
            sample_valid = 1'b0;
            sample_left_in = 16'sd0;
            sample_right_in = 16'sd0;
            bass_gain_L = 5'sd0;
            mid_gain_L = 5'sd0;
            treble_gain_L = 5'sd0;
            bass_gain_R = 5'sd0;
            mid_gain_R = 5'sd0;
            treble_gain_R = 5'sd0;
            repeat (4) @(negedge clk);
            rst = 1'b0;
            repeat (2) @(negedge clk);
        end
    endtask

    task run_stereo_constant;
        input signed [15:0] left_value;
        input signed [15:0] right_value;
        input signed [4:0] bass_l;
        input signed [4:0] mid_l;
        input signed [4:0] treble_l;
        input signed [4:0] bass_r;
        input signed [4:0] mid_r;
        input signed [4:0] treble_r;
        input integer cycles;
        begin
            clip_l_seen = 0;
            clip_r_seen = 0;
            last_left = 16'sd0;
            last_right = 16'sd0;
            @(negedge clk);
            sample_left_in = left_value;
            sample_right_in = right_value;
            bass_gain_L = bass_l;
            mid_gain_L = mid_l;
            treble_gain_L = treble_l;
            bass_gain_R = bass_r;
            mid_gain_R = mid_r;
            treble_gain_R = treble_r;
            sample_valid = 1'b1;

            for (k = 0; k < cycles; k = k + 1) begin
                @(posedge clk);
                #1;
                if (sample_out_valid) begin
                    last_left = sample_left_out;
                    last_right = sample_right_out;
                    if (clip_L)
                        clip_l_seen = 1;
                    if (clip_R)
                        clip_r_seen = 1;
                    if (^sample_left_out === 1'bx || ^sample_right_out === 1'bx) begin
                        $display("FAIL: stereo EQ output has X/Z");
                        errors = errors + 1;
                    end
                end
            end

            @(negedge clk);
            sample_valid = 1'b0;
            repeat (3) @(posedge clk);
        end
    endtask

    initial begin
        errors = 0;

        reset_dut;
        run_stereo_constant(16'sd4000, 16'sd4000,
                            5'sd6, 5'sd0, 5'sd0,
                            5'sd0, 5'sd0, 5'sd0,
                            80);
        if (last_left <= last_right + 16'sd500) begin
            $display("FAIL: L bass boost did not affect L independently L=%0d R=%0d",
                     last_left, last_right);
            errors = errors + 1;
        end

        reset_dut;
        run_stereo_constant(16'sd4000, 16'sd4000,
                            5'sd0, 5'sd0, 5'sd0,
                            5'sd6, 5'sd0, 5'sd0,
                            80);
        if (last_right <= last_left + 16'sd500) begin
            $display("FAIL: R bass boost did not affect R independently L=%0d R=%0d",
                     last_left, last_right);
            errors = errors + 1;
        end

        reset_dut;
        run_stereo_constant(16'sd30000, 16'sd2000,
                            5'sd6, 5'sd6, 5'sd6,
                            5'sd0, 5'sd0, 5'sd0,
                            12);
        if (clip_l_seen == 0 || clip_r_seen != 0) begin
            $display("FAIL: independent left clip failed clip_L=%0d clip_R=%0d",
                     clip_l_seen, clip_r_seen);
            errors = errors + 1;
        end

        reset_dut;
        run_stereo_constant(16'sd2000, -16'sd30000,
                            5'sd0, 5'sd0, 5'sd0,
                            5'sd6, 5'sd6, 5'sd6,
                            12);
        if (clip_l_seen != 0 || clip_r_seen == 0) begin
            $display("FAIL: independent right clip failed clip_L=%0d clip_R=%0d",
                     clip_l_seen, clip_r_seen);
            errors = errors + 1;
        end

        if (errors == 0)
            $display("PASS: eq3band_stereo_tb");
        else
            $display("FAIL: eq3band_stereo_tb errors=%0d", errors);

        $finish;
    end

endmodule
