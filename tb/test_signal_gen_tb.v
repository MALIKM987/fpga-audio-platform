`timescale 1ns/1ps

module test_signal_gen_tb;
    reg clk;
    reg rst;
    wire signed [15:0] sample_out;
    wire sample_valid;

    integer valid_count;
    integer pos_seen;
    integer neg_seen;
    integer change_seen;
    integer fail;
    reg signed [15:0] prev_sample;

    test_signal_gen #(
        .CLK_FREQ_HZ(1000),
        .SAMPLE_RATE_HZ(100),
        .AMPLITUDE(12000)
    ) dut (
        .clk(clk),
        .rst(rst),
        .sample_out(sample_out),
        .sample_valid(sample_valid)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst = 1'b1;
        valid_count = 0;
        pos_seen = 0;
        neg_seen = 0;
        change_seen = 0;
        fail = 0;
        prev_sample = 16'sd0;

        repeat (5) @(posedge clk);
        rst = 1'b0;

        repeat (3000) begin
            @(posedge clk);
            #1;
            if (sample_valid) begin
                valid_count = valid_count + 1;
                if (sample_out > 0) pos_seen = 1;
                if (sample_out < 0) neg_seen = 1;
                if (valid_count > 1 && sample_out != prev_sample) change_seen = 1;
                prev_sample = sample_out;
            end
        end

        if (valid_count < 10) begin
            $display("FAIL: test_signal_gen did not produce enough valid samples");
            fail = 1;
        end
        if (!pos_seen || !neg_seen) begin
            $display("FAIL: test_signal_gen did not produce positive and negative samples");
            fail = 1;
        end
        if (!change_seen) begin
            $display("FAIL: test_signal_gen output did not change");
            fail = 1;
        end

        if (fail) begin
            $display("test_signal_gen_tb FAIL");
        end else begin
            $display("test_signal_gen_tb PASS");
        end
        $finish;
    end
endmodule
