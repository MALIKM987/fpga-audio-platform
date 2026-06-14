`timescale 1ns/1ps

module spectral_processor_tb;

    localparam integer FFT_SIZE   = 256;
    localparam integer BIN_WIDTH  = 8;
    localparam integer DATA_WIDTH = 16;
    localparam integer GAIN_WIDTH = 16;

    localparam [1:0] BAND_BASS   = 2'd0;
    localparam [1:0] BAND_MID    = 2'd1;
    localparam [1:0] BAND_TREBLE = 2'd2;

    localparam signed [15:0] GAIN_0_75 = 16'sd12288;
    localparam signed [15:0] GAIN_1_00 = 16'sd16384;
    localparam signed [15:0] GAIN_1_50 = 16'sd24576;
    localparam signed [15:0] INT_MAX   = 16'sd32767;
    localparam signed [15:0] INT_MIN   = -16'sd32768;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg in_valid = 1'b0;
    reg [BIN_WIDTH-1:0] bin_index = {BIN_WIDTH{1'b0}};
    reg signed [DATA_WIDTH-1:0] real_in = 16'sd0;
    reg signed [DATA_WIDTH-1:0] imag_in = 16'sd0;
    reg signed [GAIN_WIDTH-1:0] bass_gain = GAIN_1_50;
    reg signed [GAIN_WIDTH-1:0] mid_gain = GAIN_1_00;
    reg signed [GAIN_WIDTH-1:0] treble_gain = GAIN_0_75;

    wire out_valid;
    wire signed [DATA_WIDTH-1:0] real_out;
    wire signed [DATA_WIDTH-1:0] imag_out;
    wire signed [GAIN_WIDTH-1:0] selected_gain;
    wire [1:0] band_id;

    integer errors = 0;

    spectral_processor #(
        .FFT_SIZE(FFT_SIZE),
        .BIN_WIDTH(BIN_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .GAIN_WIDTH(GAIN_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .in_valid(in_valid),
        .bin_index(bin_index),
        .real_in(real_in),
        .imag_in(imag_in),
        .bass_gain(bass_gain),
        .mid_gain(mid_gain),
        .treble_gain(treble_gain),
        .out_valid(out_valid),
        .real_out(real_out),
        .imag_out(imag_out),
        .selected_gain(selected_gain),
        .band_id(band_id)
    );

    always #5 clk = ~clk;

    task run_valid_case;
        input [BIN_WIDTH-1:0] test_bin;
        input [1:0] expected_band;
        input signed [GAIN_WIDTH-1:0] expected_gain;
        input signed [DATA_WIDTH-1:0] expected_real;
        input signed [DATA_WIDTH-1:0] expected_imag;
        input [8*24-1:0] label;
        input [8*8-1:0] band_label;
        input [8*8-1:0] gain_label;
        begin
            @(negedge clk);
            bin_index = test_bin;
            real_in = 16'sd1000;
            imag_in = -16'sd2000;
            in_valid = 1'b1;

            @(posedge clk);
            #1;

            if ((out_valid !== 1'b1) ||
                (band_id !== expected_band) ||
                (selected_gain !== expected_gain) ||
                (real_out !== expected_real) ||
                (imag_out !== expected_imag)) begin
                errors = errors + 1;
                $display("TEST %0s band=%0s real_in=%0d gain=%0s real_out=%0d FAIL",
                         label, band_label, real_in, gain_label, real_out);
                $display("  expected: out_valid=1 band_id=%0d gain=%0d real=%0d imag=%0d",
                         expected_band, expected_gain, expected_real, expected_imag);
                $display("  actual:   out_valid=%0d band_id=%0d gain=%0d real=%0d imag=%0d",
                         out_valid, band_id, selected_gain, real_out, imag_out);
            end else begin
                $display("TEST %0s band=%0s real_in=%0d gain=%0s real_out=%0d PASS",
                         label, band_label, real_in, gain_label, real_out);
            end

            @(negedge clk);
            in_valid = 1'b0;
        end
    endtask

    task run_saturation_case;
        begin
            @(negedge clk);
            bin_index = 8'd1;
            real_in = 16'sd30000;
            imag_in = -16'sd30000;
            in_valid = 1'b1;

            @(posedge clk);
            #1;

            if ((out_valid !== 1'b1) ||
                (band_id !== BAND_BASS) ||
                (selected_gain !== GAIN_1_50) ||
                (real_out !== INT_MAX) ||
                (imag_out !== INT_MIN)) begin
                errors = errors + 1;
                $display("TEST saturation_gain FAIL");
                $display("  expected: out_valid=1 band_id=%0d gain=%0d real=%0d imag=%0d",
                         BAND_BASS, GAIN_1_50, INT_MAX, INT_MIN);
                $display("  actual:   out_valid=%0d band_id=%0d gain=%0d real=%0d imag=%0d",
                         out_valid, band_id, selected_gain, real_out, imag_out);
            end else begin
                $display("TEST saturation_gain real_out=%0d imag_out=%0d PASS",
                         real_out, imag_out);
            end

            @(negedge clk);
            in_valid = 1'b0;
        end
    endtask

    task run_invalid_case;
        begin
            @(negedge clk);
            bin_index = 8'd1;
            real_in = 16'sd1000;
            imag_in = -16'sd2000;
            in_valid = 1'b0;

            @(posedge clk);
            #1;

            if (out_valid !== 1'b0) begin
                errors = errors + 1;
                $display("TEST in_valid=0 out_valid=%0d FAIL", out_valid);
            end else begin
                $display("TEST in_valid=0 out_valid=0 PASS");
            end
        end
    endtask

    initial begin
        $display("=== SPECTRAL PROCESSOR TEST ===");
        $display("FFT_SIZE=%0d", FFT_SIZE);
        $display("GAIN_FORMAT=Q2.14");
        $display("");

        repeat (3) @(posedge clk);
        rst = 1'b0;

        run_valid_case(8'd1,   BAND_BASS,   GAIN_1_50, 16'sd1500, -16'sd3000,
                       "bin=1",          "BASS",   "1.50");
        run_valid_case(8'd10,  BAND_MID,    GAIN_1_00, 16'sd1000, -16'sd2000,
                       "bin=10",         "MID",    "1.00");
        run_valid_case(8'd40,  BAND_TREBLE, GAIN_0_75, 16'sd750,  -16'sd1500,
                       "bin=40",         "TREBLE", "0.75");
        run_valid_case(8'd255, BAND_BASS,   GAIN_1_50, 16'sd1500, -16'sd3000,
                       "mirror_bin=255", "BASS",   "1.50");
        run_valid_case(8'd246, BAND_MID,    GAIN_1_00, 16'sd1000, -16'sd2000,
                       "mirror_bin=246", "MID",    "1.00");
        run_valid_case(8'd216, BAND_TREBLE, GAIN_0_75, 16'sd750,  -16'sd1500,
                       "mirror_bin=216", "TREBLE", "0.75");
        run_saturation_case();
        run_invalid_case();

        $display("");
        if (errors == 0) begin
            $display("STATUS=PASS");
        end else begin
            $display("STATUS=FAIL errors=%0d", errors);
        end

        $finish;
    end

endmodule
