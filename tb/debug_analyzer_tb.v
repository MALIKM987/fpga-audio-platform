`timescale 1ns/1ps

module debug_analyzer_tb;
    reg clk;
    reg rst;
    reg signed [15:0] sample_in;
    reg signed [15:0] sample_out;
    reg sample_valid;
    reg clip;
    wire signed [15:0] in_min;
    wire signed [15:0] in_max;
    wire signed [15:0] out_min;
    wire signed [15:0] out_max;
    wire clip_seen;
    wire report_valid;

    integer fail;

    debug_analyzer #(
        .WINDOW_SAMPLES(4)
    ) dut (
        .clk(clk),
        .rst(rst),
        .sample_in(sample_in),
        .sample_out(sample_out),
        .sample_valid(sample_valid),
        .clip(clip),
        .in_min(in_min),
        .in_max(in_max),
        .out_min(out_min),
        .out_max(out_max),
        .clip_seen(clip_seen),
        .report_valid(report_valid)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task feed_sample;
        input signed [15:0] in_value;
        input signed [15:0] out_value;
        input clip_value;
        begin
            @(negedge clk);
            sample_in = in_value;
            sample_out = out_value;
            clip = clip_value;
            sample_valid = 1'b1;
            @(posedge clk);
            #1;
            sample_valid = 1'b0;
            clip = 1'b0;
        end
    endtask

    initial begin
        rst = 1'b1;
        sample_in = 16'sd0;
        sample_out = 16'sd0;
        sample_valid = 1'b0;
        clip = 1'b0;
        fail = 0;

        repeat (3) @(posedge clk);
        rst = 1'b0;

        feed_sample(16'sd10, 16'sd20, 1'b0);
        if (report_valid) fail = 1;
        feed_sample(-16'sd5, -16'sd10, 1'b0);
        feed_sample(16'sd40, 16'sd80, 1'b1);
        feed_sample(-16'sd30, -16'sd60, 1'b0);

        if (!report_valid) begin
            $display("FAIL: report_valid missing");
            fail = 1;
        end
        if (in_min != -16'sd30 || in_max != 16'sd40 ||
            out_min != -16'sd60 || out_max != 16'sd80 || !clip_seen) begin
            $display("FAIL: analyzer stats incorrect");
            fail = 1;
        end

        if (fail) begin
            $display("debug_analyzer_tb FAIL");
        end else begin
            $display("debug_analyzer_tb PASS");
        end
        $finish;
    end
endmodule
