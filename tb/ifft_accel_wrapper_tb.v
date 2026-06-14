`timescale 1ns/1ps

module ifft_accel_wrapper_tb;

    localparam integer FFT_SIZE    = 256;
    localparam integer DATA_WIDTH  = 16;
    localparam integer INDEX_WIDTH = 8;
    localparam integer TIMEOUT_CYCLES = 10000;
    localparam integer MAX_MISMATCH_PRINTS = 8;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg start = 1'b0;
    reg in_valid = 1'b0;
    reg [INDEX_WIDTH-1:0] in_index = {INDEX_WIDTH{1'b0}};
    reg signed [DATA_WIDTH-1:0] real_in = 16'sd0;
    reg signed [DATA_WIDTH-1:0] imag_in = 16'sd0;

    wire out_valid;
    wire [INDEX_WIDTH-1:0] out_index;
    wire signed [DATA_WIDTH-1:0] real_out;
    wire signed [DATA_WIDTH-1:0] imag_out;
    wire busy;
    wire done;

    integer errors = 0;
    integer i;

    reg signed [DATA_WIDTH-1:0] input_real [0:FFT_SIZE-1];
    reg signed [DATA_WIDTH-1:0] input_imag [0:FFT_SIZE-1];
    reg signed [DATA_WIDTH-1:0] expected_real [0:FFT_SIZE-1];
    reg signed [DATA_WIDTH-1:0] expected_imag [0:FFT_SIZE-1];

    ifft_accel_wrapper #(
        .FFT_SIZE(FFT_SIZE),
        .DATA_WIDTH(DATA_WIDTH),
        .INDEX_WIDTH(INDEX_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
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

    task report_result;
        input [8*64-1:0] name;
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

    task load_vector_file;
        input [8*128-1:0] vector_path;
        output load_ok;
        integer fd;
        integer scan_result;
        integer row;
        begin
            load_ok = 1'b1;
            fd = $fopen(vector_path, "r");

            if (fd == 0) begin
                $display("  vector open error: %0s", vector_path);
                load_ok = 1'b0;
            end else begin
                for (row = 0; row < FFT_SIZE; row = row + 1) begin
                    scan_result = $fscanf(
                        fd,
                        "%d %d %d %d\n",
                        input_real[row],
                        input_imag[row],
                        expected_real[row],
                        expected_imag[row]
                    );

                    if (scan_result != 4) begin
                        $display("  vector parse error: %0s row=%0d", vector_path, row);
                        load_ok = 1'b0;
                    end
                end

                $fclose(fd);
            end
        end
    endtask

    task apply_reset;
        output reset_ok;
        begin
            @(negedge clk);
            rst = 1'b1;
            start = 1'b0;
            in_valid = 1'b0;
            in_index = {INDEX_WIDTH{1'b0}};
            real_in = 16'sd0;
            imag_in = 16'sd0;

            repeat (3) @(posedge clk);
            #1;
            reset_ok = (
                busy === 1'b0 &&
                done === 1'b0 &&
                out_valid === 1'b0
            );

            @(negedge clk);
            rst = 1'b0;
        end
    endtask

    task run_frame_test;
        input [8*32-1:0] test_name;
        input [8*128-1:0] vector_path;
        integer load_ok;
        integer reset_ok;
        integer input_ok;
        integer busy_ok;
        integer output_ok;
        integer order_ok;
        integer done_ok;
        integer output_count;
        integer timeout_count;
        integer mismatch_prints;
        begin
            input_ok = 1;
            busy_ok = 1;
            output_ok = 1;
            order_ok = 1;
            done_ok = 0;
            output_count = 0;
            timeout_count = 0;
            mismatch_prints = 0;

            $display("CASE %0s", test_name);
            load_vector_file(vector_path, load_ok);
            report_result({test_name, "_load"}, load_ok);

            apply_reset(reset_ok);
            report_result({test_name, "_reset"}, reset_ok);

            if (load_ok && reset_ok) begin
                @(negedge clk);
                start = 1'b1;

                @(posedge clk);
                #1;
                if (busy !== 1'b1) begin
                    busy_ok = 0;
                    $display("  busy error after start");
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

                    if (busy !== 1'b1) begin
                        busy_ok = 0;
                        if (mismatch_prints < MAX_MISMATCH_PRINTS) begin
                            $display("  busy error during input index=%0d", i);
                            mismatch_prints = mismatch_prints + 1;
                        end
                    end

                    if (out_valid !== 1'b0) begin
                        input_ok = 0;
                        if (mismatch_prints < MAX_MISMATCH_PRINTS) begin
                            $display("  early out_valid during input index=%0d", i);
                            mismatch_prints = mismatch_prints + 1;
                        end
                    end
                end

                @(negedge clk);
                in_valid = 1'b0;
                in_index = {INDEX_WIDTH{1'b0}};
                real_in = 16'sd0;
                imag_in = 16'sd0;

                while (output_count < FFT_SIZE && timeout_count < TIMEOUT_CYCLES) begin
                    @(posedge clk);
                    #1;
                    timeout_count = timeout_count + 1;

                    if (out_valid) begin
                        if (out_index !== output_count[INDEX_WIDTH-1:0]) begin
                            order_ok = 0;
                            if (mismatch_prints < MAX_MISMATCH_PRINTS) begin
                                $display(
                                    "  order error: out_index=%0d expected=%0d",
                                    out_index,
                                    output_count
                                );
                                mismatch_prints = mismatch_prints + 1;
                            end
                        end

                        if (real_out !== expected_real[output_count] ||
                            imag_out !== expected_imag[output_count]) begin
                            output_ok = 0;
                            if (mismatch_prints < MAX_MISMATCH_PRINTS) begin
                                $display(
                                    "  data error index=%0d real=%0d expected=%0d imag=%0d expected=%0d",
                                    output_count,
                                    real_out,
                                    expected_real[output_count],
                                    imag_out,
                                    expected_imag[output_count]
                                );
                                mismatch_prints = mismatch_prints + 1;
                            end
                        end

                        output_count = output_count + 1;
                    end
                end

                if (output_count != FFT_SIZE) begin
                    output_ok = 0;
                    $display("  output timeout count=%0d", output_count);
                end

                timeout_count = 0;
                while (!done_ok && timeout_count < 16) begin
                    @(posedge clk);
                    #1;
                    timeout_count = timeout_count + 1;
                    if (done) begin
                        done_ok = (busy === 1'b0) && (out_valid === 1'b0);
                    end
                end
            end else begin
                input_ok = 0;
                busy_ok = 0;
                output_ok = 0;
                order_ok = 0;
                done_ok = 0;
            end

            report_result({test_name, "_input_frame"}, input_ok);
            report_result({test_name, "_busy"}, busy_ok);
            report_result({test_name, "_output_frame"}, output_ok);
            report_result({test_name, "_output_order"}, order_ok);
            report_result({test_name, "_done"}, done_ok);
        end
    endtask

    initial begin
        $display("=== IFFT ACCEL WRAPPER TEST ===");
        $display("FFT_SIZE=%0d", FFT_SIZE);
        $display("MODE=RADIX2_INVERSE_CORE_NORMALIZED");
        $display("NOTE=1/N normalization is applied as one arithmetic shift per stage.");
        $display("");

        run_frame_test(
            "zero_frame",
            "tb/generated/ifft_radix2_core_zero_frame.mem"
        );

        run_frame_test(
            "impulse0",
            "tb/generated/ifft_radix2_core_impulse0.mem"
        );

        run_frame_test(
            "impulse1",
            "tb/generated/ifft_radix2_core_impulse1.mem"
        );

        run_frame_test(
            "two_sample",
            "tb/generated/ifft_radix2_core_two_sample.mem"
        );

        $display("");
        if (errors == 0) begin
            $display("STATUS=PASS");
        end else begin
            $display("STATUS=FAIL errors=%0d", errors);
        end

        $finish;
    end

endmodule
