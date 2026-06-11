`timescale 1ns/1ps

module fft_radix2_core_tb;

    localparam integer FFT_SIZE    = 256;
    localparam integer DATA_WIDTH  = 16;
    localparam integer INDEX_WIDTH = 8;

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

    integer errors = 0;
    integer output_count = 0;
    integer busy_seen = 0;
    integer done_seen = 0;
    integer early_out_valid_seen = 0;
    integer first_output_seen = 0;
    integer compute_wait_cycles = 0;
    integer compute_walk_delay_ok = 0;
    integer output_order_ok = 1;
    integer output_data_ok = 1;
    integer busy_low_after_done_ok = 0;
    integer cycle_guard = 0;
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

    function [INDEX_WIDTH-1:0] bit_reverse8;
        input [INDEX_WIDTH-1:0] value;
        integer bit_idx;
        begin
            for (bit_idx = 0; bit_idx < INDEX_WIDTH; bit_idx = bit_idx + 1) begin
                bit_reverse8[INDEX_WIDTH-1-bit_idx] = value[bit_idx];
            end
        end
    endfunction

    function signed [DATA_WIDTH-1:0] expected_real_sample;
        input [INDEX_WIDTH-1:0] value;
        begin
            expected_real_sample =
                {{(DATA_WIDTH-INDEX_WIDTH){1'b0}}, bit_reverse8(value)};
        end
    endfunction

    function signed [DATA_WIDTH-1:0] expected_imag_sample;
        input [INDEX_WIDTH-1:0] value;
        begin
            expected_imag_sample = -expected_real_sample(value);
        end
    endfunction

    task report_result;
        input [8*32-1:0] name;
        input pass;
        begin
            if (pass) begin
                $display("TEST %0s PASS", name);
            end else begin
                errors = errors + 1;
                $display("TEST %0s FAIL", name);
            end
        end
    endtask

    task check_no_early_out_valid;
        begin
            @(posedge clk);
            #1;
            if (busy === 1'b1) begin
                busy_seen = 1;
            end
            if (out_valid === 1'b1) begin
                early_out_valid_seen = 1;
                $display("  early out_valid observed before OUTPUT phase");
            end
        end
    endtask

    initial begin
        $display("=== FFT RADIX-2 CORE SKELETON TEST ===");
        $display("FFT_SIZE=%0d", FFT_SIZE);
        $display("MODE=STAGE_WALK_REORDER_SKELETON_NO_BUTTERFLY");
        $display("");

        repeat (3) @(posedge clk);
        #1;
        report_result("reset",
                      (busy === 1'b0) &&
                      (done === 1'b0) &&
                      (out_valid === 1'b0));

        @(negedge clk);
        rst = 1'b0;
        start = 1'b1;
        inverse = 1'b0;

        @(posedge clk);
        #1;
        if (busy === 1'b1) begin
            busy_seen = 1;
        end
        report_result("start_busy", busy === 1'b1);

        @(negedge clk);
        start = 1'b0;

        for (i = 0; i < FFT_SIZE; i = i + 1) begin
            @(negedge clk);
            in_valid = 1'b1;
            in_index = i[INDEX_WIDTH-1:0];
            real_in = i[DATA_WIDTH-1:0];
            imag_in = -i[DATA_WIDTH-1:0];
            check_no_early_out_valid();
        end

        @(negedge clk);
        in_valid = 1'b0;
        in_index = {INDEX_WIDTH{1'b0}};
        real_in = {DATA_WIDTH{1'b0}};
        imag_in = {DATA_WIDTH{1'b0}};

        while (output_count < FFT_SIZE && cycle_guard < 1600) begin
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
                if (!first_output_seen) begin
                    first_output_seen = 1;
                    compute_walk_delay_ok = (compute_wait_cycles >= 1024);
                    if (!compute_walk_delay_ok) begin
                        $display("  first output too early after %0d compute cycles",
                                 compute_wait_cycles);
                    end
                end

                if (out_index !== output_count[INDEX_WIDTH-1:0]) begin
                    output_order_ok = 0;
                    $display("  order error index=%0d expected=%0d",
                             out_index, output_count);
                end

                if ((real_out !== expected_real_sample(output_count[INDEX_WIDTH-1:0])) ||
                    (imag_out !== expected_imag_sample(output_count[INDEX_WIDTH-1:0]))) begin
                    output_data_ok = 0;
                    $display("  data error output=%0d real=%0d expected=%0d",
                             output_count,
                             real_out,
                             expected_real_sample(output_count[INDEX_WIDTH-1:0]));
                    $display("  imag=%0d expected=%0d",
                             imag_out,
                             expected_imag_sample(output_count[INDEX_WIDTH-1:0]));
                end

                output_count = output_count + 1;
            end else if (!first_output_seen) begin
                compute_wait_cycles = compute_wait_cycles + 1;
            end
        end

        while (done_seen == 0 && cycle_guard < 1100) begin
            @(posedge clk);
            #1;
            cycle_guard = cycle_guard + 1;
            if (done === 1'b1) begin
                done_seen = 1;
                busy_low_after_done_ok = (busy === 1'b0);
            end
        end

        if (done_seen) begin
            @(posedge clk);
            #1;
            if (busy === 1'b0) begin
                busy_low_after_done_ok = 1;
            end
        end

        report_result("busy_seen", busy_seen);
        report_result("no_early_out_valid", !early_out_valid_seen);
        report_result("compute_walk_delay", compute_walk_delay_ok);
        report_result("output_count", output_count == FFT_SIZE);
        report_result("output_order", output_order_ok);
        report_result("output_data", output_data_ok);
        report_result("done_pulse", done_seen);
        report_result("busy_low_after_done", busy_low_after_done_ok);

        $display("");
        if (errors == 0) begin
            $display("STATUS=PASS");
        end else begin
            $display("STATUS=FAIL errors=%0d", errors);
        end

        $finish;
    end

endmodule
