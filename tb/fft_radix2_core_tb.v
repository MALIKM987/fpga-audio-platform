`timescale 1ns/1ps

module fft_radix2_core_tb;

    localparam integer FFT_SIZE    = 256;
    localparam integer DATA_WIDTH  = 16;
    localparam integer INDEX_WIDTH = 8;
    localparam integer MAX_MISMATCH_PRINTS = 8;
    localparam integer OUTPUT_WAIT_LIMIT = 9000;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg start = 1'b0;
    reg inverse = 1'b0;
    reg in_valid = 1'b0;
    reg [INDEX_WIDTH-1:0] in_index = {INDEX_WIDTH{1'b0}};
    reg signed [DATA_WIDTH-1:0] real_in = {DATA_WIDTH{1'b0}};
    reg signed [DATA_WIDTH-1:0] imag_in = {DATA_WIDTH{1'b0}};

    wire out_valid;
    wire [INDEX_WIDTH-1:0] out_index;
    wire signed [DATA_WIDTH-1:0] real_out;
    wire signed [DATA_WIDTH-1:0] imag_out;
    wire busy;
    wire done;

    reg signed [DATA_WIDTH-1:0] input_real [0:FFT_SIZE-1];
    reg signed [DATA_WIDTH-1:0] input_imag [0:FFT_SIZE-1];
    reg signed [DATA_WIDTH-1:0] expected_real [0:FFT_SIZE-1];
    reg signed [DATA_WIDTH-1:0] expected_imag [0:FFT_SIZE-1];

    integer errors = 0;
    integer i;

    fft_radix2_core #(
        .FFT_SIZE(FFT_SIZE),
        .DATA_WIDTH(DATA_WIDTH),
        .INDEX_WIDTH(INDEX_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .inverse(inverse),
        .in_valid(in_valid),
        .in_index(in_index),
        .real_in(real_in),
        .imag_in(imag_in),
        .out_valid(out_valid),
        .out_index(out_index),
        .real_out(real_out),
        .imag_out(imag_out),
        .busy(busy),
        .done(done)
    );

    always #5 clk = ~clk;

    task load_vector_file;
        input [8*96-1:0] vector_path;
        output integer load_ok;
        integer fd;
        integer scan_count;
        integer sample_index;
        begin
            load_ok = 1;
            fd = $fopen(vector_path, "r");
            if (fd == 0) begin
                load_ok = 0;
                $display("  could not open vector file: %0s", vector_path);
            end else begin
                for (sample_index = 0; sample_index < FFT_SIZE; sample_index = sample_index + 1) begin
                    scan_count = $fscanf(
                        fd,
                        "%d %d %d %d\n",
                        input_real[sample_index],
                        input_imag[sample_index],
                        expected_real[sample_index],
                        expected_imag[sample_index]
                    );
                    if (scan_count != 4) begin
                        load_ok = 0;
                        $display("  malformed vector file %0s at sample %0d",
                                 vector_path, sample_index);
                    end
                end
                $fclose(fd);
            end
        end
    endtask

    task apply_reset;
        output integer reset_ok;
        begin
            @(negedge clk);
            rst = 1'b1;
            start = 1'b0;
            inverse = 1'b0;
            in_valid = 1'b0;
            in_index = {INDEX_WIDTH{1'b0}};
            real_in = {DATA_WIDTH{1'b0}};
            imag_in = {DATA_WIDTH{1'b0}};

            repeat (3) @(posedge clk);
            #1;
            reset_ok =
                (busy === 1'b0) &&
                (done === 1'b0) &&
                (out_valid === 1'b0);
        end
    endtask

    task run_frame_test;
        input [8*32-1:0] test_name;
        input [8*96-1:0] vector_path;
        integer case_errors;
        integer load_ok;
        integer reset_ok;
        integer start_busy_ok;
        integer busy_seen;
        integer done_seen;
        integer early_out_valid_seen;
        integer output_order_ok;
        integer output_data_ok;
        integer output_count;
        integer mismatch_print_count;
        integer cycle_guard;
        integer done_guard;
        begin
            case_errors = 0;
            load_vector_file(vector_path, load_ok);
            if (!load_ok) begin
                case_errors = case_errors + 1;
            end

            apply_reset(reset_ok);
            if (!reset_ok) begin
                case_errors = case_errors + 1;
                $display("  %0s reset check failed", test_name);
            end

            busy_seen = 0;
            done_seen = 0;
            early_out_valid_seen = 0;
            output_order_ok = 1;
            output_data_ok = 1;
            output_count = 0;
            mismatch_print_count = 0;
            cycle_guard = 0;
            done_guard = 0;

            @(negedge clk);
            rst = 1'b0;
            start = 1'b1;
            inverse = 1'b0;

            @(posedge clk);
            #1;
            start_busy_ok = (busy === 1'b1);
            busy_seen = (busy === 1'b1);
            if (!start_busy_ok) begin
                case_errors = case_errors + 1;
                $display("  %0s start_busy check failed", test_name);
            end

            @(negedge clk);
            start = 1'b0;

            for (i = 0; i < FFT_SIZE; i = i + 1) begin
                @(negedge clk);
                in_valid = 1'b1;
                in_index = i[INDEX_WIDTH-1:0];
                real_in = input_real[i];
                imag_in = input_imag[i];

                @(posedge clk);
                #1;
                if (busy === 1'b1) begin
                    busy_seen = 1;
                end
                if (out_valid === 1'b1) begin
                    early_out_valid_seen = 1;
                    $display("  %0s early out_valid during input sample %0d",
                             test_name, i);
                end
            end

            @(negedge clk);
            in_valid = 1'b0;
            in_index = {INDEX_WIDTH{1'b0}};
            real_in = {DATA_WIDTH{1'b0}};
            imag_in = {DATA_WIDTH{1'b0}};

            while (output_count < FFT_SIZE && cycle_guard < OUTPUT_WAIT_LIMIT) begin
                @(posedge clk);
                #1;
                cycle_guard = cycle_guard + 1;

                if (busy === 1'b1) begin
                    busy_seen = 1;
                end
                if (done === 1'b1) begin
                    done_seen = 1;
                end

                if (out_valid === 1'b1) begin
                    if (out_index !== output_count[INDEX_WIDTH-1:0]) begin
                        output_order_ok = 0;
                        if (mismatch_print_count < MAX_MISMATCH_PRINTS) begin
                            mismatch_print_count = mismatch_print_count + 1;
                            $display("  %0s order error index=%0d expected=%0d",
                                     test_name, out_index, output_count);
                        end
                    end

                    if ((real_out !== expected_real[out_index]) ||
                        (imag_out !== expected_imag[out_index])) begin
                        output_data_ok = 0;
                        if (mismatch_print_count < MAX_MISMATCH_PRINTS) begin
                            mismatch_print_count = mismatch_print_count + 1;
                            $display("  %0s data error output=%0d real=%0d expected=%0d",
                                     test_name, output_count, real_out,
                                     expected_real[out_index]);
                            $display("  %0s data error output=%0d imag=%0d expected=%0d",
                                     test_name, output_count, imag_out,
                                     expected_imag[out_index]);
                        end
                    end

                    output_count = output_count + 1;
                end
            end

            while (done_seen == 0 && done_guard < 16) begin
                @(posedge clk);
                #1;
                done_guard = done_guard + 1;
                if (done === 1'b1) begin
                    done_seen = 1;
                end
            end

            if (!busy_seen) begin
                case_errors = case_errors + 1;
                $display("  %0s busy was not observed", test_name);
            end
            if (early_out_valid_seen) begin
                case_errors = case_errors + 1;
            end
            if (output_count != FFT_SIZE) begin
                case_errors = case_errors + 1;
                $display("  %0s output_count=%0d expected=%0d",
                         test_name, output_count, FFT_SIZE);
            end
            if (!output_order_ok) begin
                case_errors = case_errors + 1;
            end
            if (!output_data_ok) begin
                case_errors = case_errors + 1;
            end
            if (!done_seen) begin
                case_errors = case_errors + 1;
                $display("  %0s done pulse was not observed", test_name);
            end

            @(posedge clk);
            #1;
            if (busy !== 1'b0) begin
                case_errors = case_errors + 1;
                $display("  %0s busy did not return low", test_name);
            end

            if (case_errors == 0) begin
                $display("TEST %0s PASS", test_name);
            end else begin
                errors = errors + 1;
                $display("TEST %0s FAIL errors=%0d", test_name, case_errors);
            end
        end
    endtask

    initial begin
        $display("=== FFT RADIX-2 CORE VECTOR COMPARISON TEST ===");
        $display("FFT_SIZE=%0d", FFT_SIZE);
        $display("MODE=RTL_VS_BIT_EXACT_PYTHON_MODEL");
        $display("");

        run_frame_test("zero_frame", "tb/generated/fft_radix2_core_zero_frame.mem");
        run_frame_test("impulse0", "tb/generated/fft_radix2_core_impulse0.mem");
        run_frame_test("impulse1", "tb/generated/fft_radix2_core_impulse1.mem");
        run_frame_test("two_sample", "tb/generated/fft_radix2_core_two_sample.mem");

        $display("");
        if (errors == 0) begin
            $display("STATUS=PASS");
        end else begin
            $display("STATUS=FAIL errors=%0d", errors);
        end

        $finish;
    end

endmodule
