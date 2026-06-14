`timescale 1ns/1ps

module fft_ifft_pipeline_tb;

    localparam integer FFT_SIZE     = 256;
    localparam integer SAMPLE_WIDTH = 16;
    localparam integer GAIN_WIDTH   = 16;
    localparam integer INDEX_WIDTH  = 8;

    localparam signed [GAIN_WIDTH-1:0] GAIN_0_75 = 16'sd12288;
    localparam signed [GAIN_WIDTH-1:0] GAIN_1_00 = 16'sd16384;
    localparam signed [GAIN_WIDTH-1:0] GAIN_1_50 = 16'sd24576;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg sample_valid = 1'b0;
    reg signed [SAMPLE_WIDTH-1:0] sample_in = 16'sd0;
    reg signed [GAIN_WIDTH-1:0] bass_gain = GAIN_1_50;
    reg signed [GAIN_WIDTH-1:0] mid_gain = GAIN_1_00;
    reg signed [GAIN_WIDTH-1:0] treble_gain = GAIN_0_75;
    reg start_process = 1'b0;

    wire out_valid;
    wire [INDEX_WIDTH-1:0] out_index;
    wire signed [SAMPLE_WIDTH-1:0] sample_out;
    wire busy;
    wire done;
    wire overflow;

    integer errors = 0;
    integer output_count = 0;
    integer timeout_count = 0;
    integer collect_ok = 0;
    integer done_ok = 0;
    integer output_count_ok = 0;
    integer output_order_ok = 1;
    integer sample_1_ok = 0;
    integer sample_10_ok = 0;
    integer sample_40_ok = 0;
    integer overflow_ok = 1;
    integer i;
    integer vector_fd = 0;
    integer expected_fd = 0;
    integer scan_result = 0;
    integer csv_index = 0;
    integer csv_sample = 0;
    integer line_status = 0;
    reg [8*64-1:0] csv_header;
    reg signed [SAMPLE_WIDTH-1:0] input_samples [0:FFT_SIZE-1];
    reg signed [SAMPLE_WIDTH-1:0] expected_samples [0:FFT_SIZE-1];

    fft_ifft_pipeline #(
        .FFT_SIZE(FFT_SIZE),
        .SAMPLE_WIDTH(SAMPLE_WIDTH),
        .GAIN_WIDTH(GAIN_WIDTH),
        .INDEX_WIDTH(INDEX_WIDTH),
        .AUTO_START(1)
    ) dut (
        .clk(clk),
        .rst(rst),
        .sample_valid(sample_valid),
        .sample_in(sample_in),
        .bass_gain(bass_gain),
        .mid_gain(mid_gain),
        .treble_gain(treble_gain),
        .start_process(start_process),
        .out_valid(out_valid),
        .out_index(out_index),
        .sample_out(sample_out),
        .busy(busy),
        .done(done),
        .overflow(overflow)
    );

    always #5 clk = ~clk;

    task report_result;
        input [8*32-1:0] name;
        input pass;
        begin
            if (pass) begin
                $display("TEST %0s PASS", name);
            end else begin
                $display("TEST %0s FAIL", name);
                errors = errors + 1;
            end
        end
    endtask

    function signed [SAMPLE_WIDTH-1:0] expected_output;
        input integer index;
        begin
            expected_output = expected_samples[index];
        end
    endfunction

    initial begin
        for (i = 0; i < FFT_SIZE; i = i + 1) begin
            input_samples[i] = 16'sd0;
            expected_samples[i] = 16'sd0;
        end

        vector_fd = $fopen("sim/vectors/impulse.csv", "r");
        if (vector_fd != 0) begin
            line_status = $fgets(csv_header, vector_fd);
            for (i = 0; i < FFT_SIZE; i = i + 1) begin
                scan_result = $fscanf(vector_fd, "%d,%d\n", csv_index, csv_sample);
                if (scan_result == 2 && csv_index >= 0 && csv_index < FFT_SIZE) begin
                    input_samples[csv_index] = csv_sample;
                end else begin
                    errors = errors + 1;
                    $display("TEST input_vector_read FAIL at row %0d", i);
                end
            end
            $fclose(vector_fd);
            $display("INPUT_VECTOR=sim/vectors/impulse.csv");

            expected_fd = $fopen(
                "sim/vectors/impulse_expected_rtl_fft_ifft_normalized.csv",
                "r"
            );
            if (expected_fd != 0) begin
                line_status = $fgets(csv_header, expected_fd);
                for (i = 0; i < FFT_SIZE; i = i + 1) begin
                    scan_result = $fscanf(expected_fd, "%d,%d\n", csv_index, csv_sample);
                    if (scan_result == 2 && csv_index >= 0 && csv_index < FFT_SIZE) begin
                        expected_samples[csv_index] = csv_sample;
                    end else begin
                        errors = errors + 1;
                        $display("TEST expected_vector_read FAIL at row %0d", i);
                    end
                end
                $fclose(expected_fd);
                $display("EXPECTED_VECTOR=sim/vectors/impulse_expected_rtl_fft_ifft_normalized.csv");
            end else begin
                errors = errors + 1;
                $display("TEST expected_vector_open FAIL");
            end
        end else begin
            $display("INPUT_VECTOR=default_zero_frame");
            $display("NOTE=sim/vectors/impulse.csv not found, using built-in zero frame.");
        end

        $display("=== FFT/IFFT PIPELINE MODEL TEST ===");
        $display("FFT_SIZE=%0d", FFT_SIZE);
        $display("MODE=FFT_CORE_PLUS_NORMALIZED_IFFT");
        $display("NOTE=IFFT normalization uses one arithmetic shift per inverse stage.");
        $display("");

        repeat (3) @(posedge clk);
        #1;
        report_result("reset",
                      (busy === 1'b0) &&
                      (done === 1'b0) &&
                      (out_valid === 1'b0) &&
                      (overflow === 1'b0));

        @(negedge clk);
        rst = 1'b0;

        for (i = 0; i < FFT_SIZE; i = i + 1) begin
            @(negedge clk);
            sample_valid = 1'b1;
            sample_in = input_samples[i];
        end

        @(negedge clk);
        sample_valid = 1'b0;
        sample_in = 16'sd0;

        while (!done_ok && timeout_count < 25000) begin
            @(posedge clk);
            #1;
            timeout_count = timeout_count + 1;

            if (busy) begin
                collect_ok = 1;
            end

            if (overflow) begin
                overflow_ok = 0;
                $display("  overflow error during normal pipeline run");
            end

            if (out_valid) begin
                if (out_index !== output_count[INDEX_WIDTH-1:0]) begin
                    output_order_ok = 0;
                    $display("  order error: out_index=%0d expected=%0d",
                             out_index, output_count);
                end

                if (sample_out !== expected_output(output_count)) begin
                    output_order_ok = 0;
                    $display("  data error at index %0d sample_out=%0d expected=%0d",
                             output_count, sample_out, expected_output(output_count));
                end

                if ((out_index == 8'd1) && (sample_out === expected_output(1))) begin
                    sample_1_ok = 1;
                end

                if ((out_index == 8'd10) && (sample_out === expected_output(10))) begin
                    sample_10_ok = 1;
                end

                if ((out_index == 8'd40) && (sample_out === expected_output(40))) begin
                    sample_40_ok = 1;
                end

                output_count = output_count + 1;
            end

            if (done) begin
                done_ok = 1;
            end
        end

        output_count_ok = (output_count == FFT_SIZE);

        report_result("collect_frame", collect_ok);
        report_result("pipeline_done", done_ok);
        report_result("output_count", output_count_ok);
        report_result("output_order", output_order_ok);
        report_result("sample_1_match", sample_1_ok);
        report_result("sample_10_match", sample_10_ok);
        report_result("sample_40_match", sample_40_ok);
        report_result("overflow", overflow_ok);

        $display("");
        if (errors == 0) begin
            $display("STATUS=PASS");
        end else begin
            $display("STATUS=FAIL errors=%0d", errors);
        end

        $finish;
    end

endmodule
