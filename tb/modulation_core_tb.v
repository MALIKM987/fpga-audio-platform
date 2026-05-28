`timescale 1ns/1ps

module modulation_core_tb;
    reg clk;
    reg rst;
    reg signed [15:0] sample_in;
    reg sample_valid;
    reg [3:0] volume_gain_level;
    reg signed [4:0] bass_gain_level;
    reg signed [4:0] mid_gain_level;
    reg signed [4:0] treble_gain_level;
    wire signed [15:0] sample_out;
    wire sample_out_valid;
    wire clip;

    integer fail;

    modulation_core dut (
        .clk(clk),
        .rst(rst),
        .sample_in(sample_in),
        .sample_valid(sample_valid),
        .volume_gain_level(volume_gain_level),
        .bass_gain_level(bass_gain_level),
        .mid_gain_level(mid_gain_level),
        .treble_gain_level(treble_gain_level),
        .sample_out(sample_out),
        .sample_out_valid(sample_out_valid),
        .clip(clip)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task send_sample;
        input signed [15:0] value;
        begin
            @(negedge clk);
            sample_in = value;
            sample_valid = 1'b1;
            @(posedge clk);
            #1;
            sample_valid = 1'b0;
        end
    endtask

    initial begin
        rst = 1'b1;
        sample_in = 16'sd0;
        sample_valid = 1'b0;
        volume_gain_level = 4'd8;
        bass_gain_level = 5'sd0;
        mid_gain_level = 5'sd0;
        treble_gain_level = 5'sd0;
        fail = 0;

        repeat (4) @(posedge clk);
        rst = 1'b0;

        send_sample(16'sd1000);
        if (!sample_out_valid || sample_out != 16'sd1000 || clip) begin
            $display("FAIL: unity modulation expected 1000, got %0d clip=%0d", sample_out, clip);
            fail = 1;
        end

        volume_gain_level = 4'd15;
        bass_gain_level = 5'sd3;
        mid_gain_level = 5'sd3;
        treble_gain_level = 5'sd3;
        send_sample(16'sd12000);
        if (!sample_out_valid || sample_out <= 16'sd12000) begin
            $display("FAIL: boosted modulation did not increase positive sample");
            fail = 1;
        end

        send_sample(16'sd32767);
        if (!clip || sample_out != 16'sd32767) begin
            $display("FAIL: positive saturation not detected, out=%0d clip=%0d", sample_out, clip);
            fail = 1;
        end

        send_sample(16'sh8000);
        if (!clip || sample_out != 16'sh8000) begin
            $display("FAIL: negative saturation not detected, out=%0d clip=%0d", sample_out, clip);
            fail = 1;
        end

        if (fail) begin
            $display("modulation_core_tb FAIL");
        end else begin
            $display("modulation_core_tb PASS");
        end
        $finish;
    end
endmodule
