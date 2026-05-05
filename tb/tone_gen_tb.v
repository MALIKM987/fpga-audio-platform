`timescale 1ns/1ps

// Sanity test for tone_gen:
// uses faster parameters and checks that the output toggles after reset.
module tone_gen_tb;

    reg clk = 1'b0;
    reg rst = 1'b1;
    wire signed [15:0] sample;
    reg signed [15:0] prev_sample;
    integer sample_change_count;
    integer positive_sample_seen;
    integer negative_sample_seen;
    integer errors;

    tone_gen #(
        .CLK_FREQ_HZ(100),
        .TONE_FREQ_HZ(10)
    ) dut (
        .clk(clk),
        .rst(rst),
        .sample(sample)
    );

    always #10 clk = ~clk;

    always @(posedge clk) begin
        if (rst) begin
            prev_sample <= sample;
        end else begin
            if (sample !== prev_sample)
                sample_change_count = sample_change_count + 1;
            if (sample > 16'sd0)
                positive_sample_seen = 1;
            if (sample < 16'sd0)
                negative_sample_seen = 1;
            prev_sample <= sample;
        end
    end

    initial begin
        errors = 0;
        sample_change_count = 0;
        positive_sample_seen = 0;
        negative_sample_seen = 0;
        prev_sample = 16'sd0;

        #100;
        if (sample !== 16'sd0) begin
            $display("FAIL: sample is not zero during reset, sample=%0d", sample);
            errors = errors + 1;
        end

        rst = 1'b0;

        #2000;

        if (sample_change_count < 2) begin
            $display("FAIL: sample did not toggle enough, count=%0d", sample_change_count);
            errors = errors + 1;
        end

        if (positive_sample_seen == 0) begin
            $display("FAIL: sample never became positive");
            errors = errors + 1;
        end

        if (negative_sample_seen == 0) begin
            $display("FAIL: sample never became negative");
            errors = errors + 1;
        end

        if (errors == 0)
            $display("PASS: tone_gen_tb");
        else
            $display("FAIL: tone_gen_tb errors=%0d", errors);

        $finish;
    end

endmodule
