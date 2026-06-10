`timescale 1ns/1ps

module fft_accel_wrapper_tb;

    localparam integer FFT_SIZE    = 256;
    localparam integer DATA_WIDTH  = 16;
    localparam integer INDEX_WIDTH = 8;

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
    integer input_ok = 1;
    integer output_ok = 1;
    integer order_ok = 1;
    integer busy_ok = 1;
    integer done_ok = 0;
    integer i;

    fft_accel_wrapper #(
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

    function signed [DATA_WIDTH-1:0] expected_real;
        input integer index;
        begin
            expected_real = 16'sd1000 + index;
        end
    endfunction

    function signed [DATA_WIDTH-1:0] expected_imag;
        input integer index;
        begin
            expected_imag = -16'sd2000 - index;
        end
    endfunction

    initial begin
        $display("=== FFT ACCEL WRAPPER TEST ===");
        $display("FFT_SIZE=%0d", FFT_SIZE);
        $display("MODE=MODEL_PASSTHROUGH");
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

        @(posedge clk);
        #1;
        report_result("start", busy === 1'b1);

        @(negedge clk);
        start = 1'b0;

        for (i = 0; i < FFT_SIZE; i = i + 1) begin
            @(negedge clk);
            in_valid = 1'b1;
            in_index = i[INDEX_WIDTH-1:0];
            real_in = expected_real(i);
            imag_in = expected_imag(i);

            @(posedge clk);
            #1;

            if (busy !== 1'b1) begin
                busy_ok = 0;
                $display("  busy error during input at index %0d", i);
            end

            if (out_valid !== 1'b0) begin
                input_ok = 0;
                $display("  input error: out_valid asserted during input at index %0d", i);
            end
        end

        @(negedge clk);
        in_valid = 1'b0;
        in_index = {INDEX_WIDTH{1'b0}};
        real_in = 16'sd0;
        imag_in = 16'sd0;

        for (i = 0; i < FFT_SIZE; i = i + 1) begin
            @(posedge clk);
            #1;

            if (busy !== 1'b1) begin
                busy_ok = 0;
                $display("  busy error during output at index %0d", i);
            end

            if (out_valid !== 1'b1) begin
                output_ok = 0;
                $display("  output error: out_valid=0 at index %0d", i);
            end

            if (out_index !== i[INDEX_WIDTH-1:0]) begin
                order_ok = 0;
                $display("  order error: out_index=%0d expected=%0d", out_index, i);
            end

            if ((real_out !== expected_real(i)) || (imag_out !== expected_imag(i))) begin
                output_ok = 0;
                $display("  data error at index %0d real=%0d expected=%0d imag=%0d expected=%0d",
                         i, real_out, expected_real(i), imag_out, expected_imag(i));
            end
        end

        @(posedge clk);
        #1;
        done_ok = (done === 1'b1) && (busy === 1'b0) && (out_valid === 1'b0);

        report_result("input_frame", input_ok);
        report_result("busy", busy_ok);
        report_result("output_frame", output_ok);
        report_result("output_order", order_ok);
        report_result("done", done_ok);

        $display("");
        if (errors == 0) begin
            $display("STATUS=PASS");
        end else begin
            $display("STATUS=FAIL errors=%0d", errors);
        end

        $finish;
    end

endmodule
