`timescale 1ns/1ps

// Sanity test for test_mix_gen:
// checks sample_valid and that the generated test mix changes sign and value.
module test_mix_gen_tb;

    reg clk = 1'b0;
    reg rst = 1'b1;

    wire signed [15:0] sample_out;
    wire sample_valid;

    reg signed [15:0] prev_sample;
    integer errors;
    integer valid_count;
    integer change_count;
    integer positive_seen;
    integer negative_seen;
    integer k;

    test_mix_gen #(
        .CLK_FREQ_HZ(12000),
        .LOW_FREQ_HZ(100),
        .MID_FREQ_HZ(1000),
        .HIGH_FREQ_HZ(3000)
    ) dut (
        .clk(clk),
        .rst(rst),
        .sample_out(sample_out),
        .sample_valid(sample_valid)
    );

    always #5 clk = ~clk;

    initial begin
        errors = 0;
        valid_count = 0;
        change_count = 0;
        positive_seen = 0;
        negative_seen = 0;
        prev_sample = 16'sd0;

        repeat (4) @(negedge clk);
        rst = 1'b0;

        for (k = 0; k < 300; k = k + 1) begin
            @(posedge clk);
            #1;
            if (sample_valid)
                valid_count = valid_count + 1;
            if (sample_out !== prev_sample)
                change_count = change_count + 1;
            if (sample_out > 16'sd0)
                positive_seen = 1;
            if (sample_out < 16'sd0)
                negative_seen = 1;
            if (^sample_out === 1'bx) begin
                $display("FAIL: sample_out has X/Z");
                errors = errors + 1;
            end
            prev_sample = sample_out;
        end

        if (valid_count < 250) begin
            $display("FAIL: sample_valid not asserted often enough, count=%0d", valid_count);
            errors = errors + 1;
        end
        if (change_count < 10) begin
            $display("FAIL: sample_out did not change enough, count=%0d", change_count);
            errors = errors + 1;
        end
        if (positive_seen == 0 || negative_seen == 0) begin
            $display("FAIL: test mix did not include both polarities positive=%0d negative=%0d",
                     positive_seen, negative_seen);
            errors = errors + 1;
        end

        if (errors == 0)
            $display("PASS: test_mix_gen_tb");
        else
            $display("FAIL: test_mix_gen_tb errors=%0d", errors);

        $finish;
    end

endmodule
