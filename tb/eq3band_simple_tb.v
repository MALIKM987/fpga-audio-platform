`timescale 1ns/1ps

// Sanity test for eq3band_simple:
// checks valid latency, unity gain behavior, band gain influence and clipping.
module eq3band_simple_tb;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg signed [15:0] sample_in = 16'sd0;
    reg sample_valid = 1'b0;
    reg signed [4:0] bass_gain_level = 5'sd0;
    reg signed [4:0] mid_gain_level = 5'sd0;
    reg signed [4:0] treble_gain_level = 5'sd0;

    wire signed [15:0] sample_out;
    wire sample_out_valid;
    wire clip;

    integer errors;
    integer saw_valid;
    integer saw_clip;
    integer k;
    integer neutral_abs_sum;
    integer boosted_abs_sum;
    reg signed [15:0] last_sample;
    reg signed [15:0] neutral_sample;
    reg signed [15:0] boosted_sample;

    eq3band_simple #(
        .LOW_SHIFT(3),
        .HIGH_SHIFT(2)
    ) dut (
        .clk(clk),
        .rst(rst),
        .sample_in(sample_in),
        .sample_valid(sample_valid),
        .bass_gain_level(bass_gain_level),
        .mid_gain_level(mid_gain_level),
        .treble_gain_level(treble_gain_level),
        .sample_out(sample_out),
        .sample_out_valid(sample_out_valid),
        .clip(clip)
    );

    always #5 clk = ~clk;

    function integer abs16;
        input signed [15:0] value;
        begin
            if (value < 16'sd0)
                abs16 = -value;
            else
                abs16 = value;
        end
    endfunction

    task check_known;
        input [15:0] value;
        input [255:0] message;
        begin
            if (^value === 1'bx) begin
                $display("FAIL: %0s has X/Z", message);
                errors = errors + 1;
            end
        end
    endtask

    task reset_dut;
        begin
            @(negedge clk);
            rst = 1'b1;
            sample_valid = 1'b0;
            sample_in = 16'sd0;
            bass_gain_level = 5'sd0;
            mid_gain_level = 5'sd0;
            treble_gain_level = 5'sd0;
            repeat (4) @(negedge clk);
            rst = 1'b0;
            repeat (2) @(negedge clk);
        end
    endtask

    task run_constant;
        input signed [15:0] sample_value;
        input signed [4:0] bass_gain;
        input signed [4:0] mid_gain;
        input signed [4:0] treble_gain;
        input integer cycles;
        output signed [15:0] final_sample;
        output integer clip_seen;
        begin
            final_sample = 16'sd0;
            clip_seen = 0;
            saw_valid = 0;
            @(negedge clk);
            bass_gain_level = bass_gain;
            mid_gain_level = mid_gain;
            treble_gain_level = treble_gain;
            sample_in = sample_value;
            sample_valid = 1'b1;

            for (k = 0; k < cycles; k = k + 1) begin
                @(posedge clk);
                #1;
                if (sample_out_valid) begin
                    saw_valid = 1;
                    final_sample = sample_out;
                    check_known(sample_out, "eq3band_simple output");
                    if (clip)
                        clip_seen = 1;
                end
            end

            @(negedge clk);
            sample_valid = 1'b0;
            repeat (3) begin
                @(posedge clk);
                #1;
                if (sample_out_valid) begin
                    saw_valid = 1;
                    final_sample = sample_out;
                    check_known(sample_out, "eq3band_simple tail output");
                    if (clip)
                        clip_seen = 1;
                end
            end
        end
    endtask

    task run_alternating_abs_sum;
        input signed [4:0] treble_gain;
        output integer abs_sum;
        begin
            abs_sum = 0;
            saw_valid = 0;
            @(negedge clk);
            bass_gain_level = 5'sd0;
            mid_gain_level = 5'sd0;
            treble_gain_level = treble_gain;
            sample_valid = 1'b1;

            for (k = 0; k < 80; k = k + 1) begin
                @(negedge clk);
                if (k[0])
                    sample_in = 16'sd5000;
                else
                    sample_in = -16'sd5000;
                @(posedge clk);
                #1;
                if (sample_out_valid) begin
                    saw_valid = 1;
                    check_known(sample_out, "alternating eq output");
                    if (k > 10)
                        abs_sum = abs_sum + abs16(sample_out);
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
        if (sample_out !== 16'sd0 || sample_out_valid !== 1'b0 || clip !== 1'b0) begin
            $display("FAIL: reset state is not clean");
            errors = errors + 1;
        end

        @(negedge clk);
        sample_in = 16'sd1000;
        sample_valid = 1'b1;
        @(negedge clk);
        sample_valid = 1'b0;
        @(posedge clk);
        #1;
        if (sample_out_valid !== 1'b0) begin
            $display("FAIL: sample_out_valid asserted too early");
            errors = errors + 1;
        end
        @(posedge clk);
        #1;
        if (sample_out_valid !== 1'b1) begin
            $display("FAIL: sample_out_valid missing at expected latency");
            errors = errors + 1;
        end
        check_known(sample_out, "single-sample output");

        reset_dut;
        run_constant(16'sd12000, 5'sd0, 5'sd0, 5'sd0, 30, last_sample, saw_clip);
        if (saw_valid == 0) begin
            $display("FAIL: no valid output for unity gain run");
            errors = errors + 1;
        end
        if (last_sample < 16'sd11500 || last_sample > 16'sd12500) begin
            $display("FAIL: unity EQ output not near input, output=%0d", last_sample);
            errors = errors + 1;
        end

        reset_dut;
        run_constant(16'sd4000, 5'sd0, 5'sd0, 5'sd0, 80, neutral_sample, saw_clip);
        reset_dut;
        run_constant(16'sd4000, 5'sd6, 5'sd0, 5'sd0, 80, boosted_sample, saw_clip);
        if (boosted_sample <= neutral_sample + 16'sd500) begin
            $display("FAIL: bass boost did not increase slow-signal response neutral=%0d boosted=%0d",
                     neutral_sample, boosted_sample);
            errors = errors + 1;
        end

        reset_dut;
        run_alternating_abs_sum(5'sd0, neutral_abs_sum);
        reset_dut;
        run_alternating_abs_sum(5'sd6, boosted_abs_sum);
        if (boosted_abs_sum <= neutral_abs_sum) begin
            $display("FAIL: treble boost did not increase fast-signal response neutral=%0d boosted=%0d",
                     neutral_abs_sum, boosted_abs_sum);
            errors = errors + 1;
        end

        reset_dut;
        run_constant(16'sd30000, 5'sd6, 5'sd6, 5'sd6, 12, last_sample, saw_clip);
        if (last_sample !== 16'sh7fff || saw_clip == 0) begin
            $display("FAIL: positive saturation failed output=%0d clip_seen=%0d", last_sample, saw_clip);
            errors = errors + 1;
        end

        reset_dut;
        run_constant(-16'sd30000, 5'sd6, 5'sd6, 5'sd6, 12, last_sample, saw_clip);
        if (last_sample !== 16'sh8000 || saw_clip == 0) begin
            $display("FAIL: negative saturation failed output=%0d clip_seen=%0d", last_sample, saw_clip);
            errors = errors + 1;
        end

        if (errors == 0)
            $display("PASS: eq3band_simple_tb");
        else
            $display("FAIL: eq3band_simple_tb errors=%0d", errors);

        $finish;
    end

endmodule
