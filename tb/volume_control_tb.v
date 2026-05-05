`timescale 1ns/1ps

// Sanity test for volume_control:
// checks Q2.14 scaling, signed 16-bit saturation and valid latency.
module volume_control_tb;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg signed [15:0] sample_in = 16'sd0;
    reg sample_valid = 1'b0;
    reg [3:0] volume_level = 4'd8;

    wire signed [15:0] sample_out;
    wire sample_out_valid;

    integer errors;

    volume_control dut (
        .clk(clk),
        .rst(rst),
        .sample_in(sample_in),
        .sample_valid(sample_valid),
        .volume_level(volume_level),
        .sample_out(sample_out),
        .sample_out_valid(sample_out_valid)
    );

    always #5 clk = ~clk;

    task expect_sample;
        input signed [15:0] expected_sample;
        input [255:0] message;
        begin
            if (sample_out_valid !== 1'b1) begin
                $display("FAIL: %0s sample_out_valid not asserted", message);
                errors = errors + 1;
            end else if (sample_out !== expected_sample) begin
                $display("FAIL: %0s actual=%0d expected=%0d",
                         message, sample_out, expected_sample);
                errors = errors + 1;
            end
        end
    endtask

    task drive_and_expect;
        input signed [15:0] sample_value;
        input [3:0] volume_value;
        input signed [15:0] expected_sample;
        input [255:0] message;
        begin
            @(negedge clk);
            sample_in = sample_value;
            volume_level = volume_value;
            sample_valid = 1'b1;
            @(negedge clk);
            sample_valid = 1'b0;

            if (sample_out_valid !== 1'b0) begin
                $display("FAIL: %0s valid asserted too early", message);
                errors = errors + 1;
            end

            @(negedge clk);
            expect_sample(expected_sample, message);
        end
    endtask

    initial begin
        errors = 0;

        repeat (4) @(negedge clk);
        rst = 1'b0;
        repeat (2) @(negedge clk);

        drive_and_expect(16'sd12345, 4'd0, 16'sd0, "volume 0 mutes the sample");
        drive_and_expect(16'sd12000, 4'd8, 16'sd12000, "volume 8 is nominal unity");
        drive_and_expect(16'sd8000, 4'd15, 16'sd15000, "volume 15 increases amplitude");
        drive_and_expect(16'sd30000, 4'd15, 16'sh7fff, "positive overflow saturates");
        drive_and_expect(-16'sd30000, 4'd15, 16'sh8000, "negative overflow saturates");

        if (errors == 0)
            $display("PASS: volume_control_tb");
        else
            $display("FAIL: volume_control_tb errors=%0d", errors);

        $finish;
    end

endmodule
