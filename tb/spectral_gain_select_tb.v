`timescale 1ns/1ps

// Sanity test for spectral_gain_select:
// checks DC, bass, mid, treble and mirrored FFT bin mapping.
module spectral_gain_select_tb;

    reg [8:0] bin_index;
    reg signed [4:0] bass_gain;
    reg signed [4:0] mid_gain;
    reg signed [4:0] treble_gain;

    wire [15:0] selected_gain_q2_14;

    integer errors;

    spectral_gain_select dut (
        .bin_index(bin_index),
        .bass_gain(bass_gain),
        .mid_gain(mid_gain),
        .treble_gain(treble_gain),
        .selected_gain_q2_14(selected_gain_q2_14)
    );

    task expect_gain_q2_14;
        input [15:0] expected;
        input [255:0] message;
        begin
            #1;
            if (selected_gain_q2_14 !== expected) begin
                $display("FAIL: %0s bin=%0d actual=%0d expected=%0d",
                         message, bin_index, selected_gain_q2_14, expected);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        errors = 0;
        bass_gain = -5'sd3;
        mid_gain = 5'sd2;
        treble_gain = 5'sd5;

        bin_index = 9'd0;
        expect_gain_q2_14(16'd16384, "bin 0 keeps unity gain");

        bin_index = 9'd1;
        expect_gain_q2_14(16'd12288, "bin 1 selects bass gain");

        bin_index = 9'd10;
        expect_gain_q2_14(16'd19115, "bin 10 selects mid gain");

        bin_index = 9'd100;
        expect_gain_q2_14(16'd23211, "bin 100 selects treble gain");

        bin_index = 9'd511;
        expect_gain_q2_14(16'd12288, "mirror bin 511 selects bass gain");

        bin_index = 9'd502;
        expect_gain_q2_14(16'd19115, "mirror bin 502 has abs_bin 10 and selects mid gain");

        bin_index = 9'd412;
        expect_gain_q2_14(16'd23211, "mirror bin 412 has abs_bin 100 and selects treble gain");

        if (errors == 0)
            $display("PASS: spectral_gain_select_tb");
        else
            $display("FAIL: spectral_gain_select_tb errors=%0d", errors);

        $finish;
    end

endmodule
