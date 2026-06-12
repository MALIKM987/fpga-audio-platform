`timescale 1ns/1ps

module tang_fft_ifft_selftest_top_tb;

    localparam integer RESET_COUNT_MAX     = 4;
    localparam integer BLINK_COUNTER_WIDTH = 8;
    localparam integer TIMEOUT_MAX         = 20000;
    localparam integer TEST_TIMEOUT_CYCLES = 30000;

    reg clk = 1'b0;
    wire led;

    integer errors = 0;
    integer timeout_count = 0;
    integer completed = 0;

    tang_fft_ifft_selftest_top #(
        .RESET_COUNT_MAX(RESET_COUNT_MAX),
        .BLINK_COUNTER_WIDTH(BLINK_COUNTER_WIDTH),
        .TIMEOUT_MAX(TIMEOUT_MAX)
    ) dut (
        .clk(clk),
        .led(led)
    );

    always #5 clk = ~clk;

    task report_result;
        input [8*40-1:0] name;
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

    initial begin
        $display("=== TANG FFT/IFFT SELFTEST TOP TEST ===");
        $display("FFT_SIZE=256");
        $display("MODE=HARDWARE_SELFTEST_IMPULSE_UNITY_GAIN");
        $display("INPUT_FRAME=index0_64_all_other_zero");
        $display("CHECKED_INDICES=0,1,2,16,64,128,255");
        $display("");

        repeat (2) @(posedge clk);
        #1;
        report_result("power_on_reset", dut.rst === 1'b1);

        while (!completed && timeout_count < TEST_TIMEOUT_CYCLES) begin
            @(posedge clk);
            #1;
            timeout_count = timeout_count + 1;

            if (dut.pass_latched || dut.fail_latched) begin
                completed = 1;
            end
        end

        report_result("completed", completed);
        report_result("pass_latched", dut.pass_latched === 1'b1);
        report_result("fail_not_latched", dut.fail_latched === 1'b0);
        report_result("overflow_not_latched", dut.overflow_latched === 1'b0);
        report_result("timeout_not_latched", dut.timeout_latched === 1'b0);
        report_result("checked_outputs", dut.check_mask === 7'b1111111);
        report_result("output_count", dut.observed_output_count == 9'd256);
        report_result("led_pass_on", led === 1'b1);

        $display("");
        if (errors == 0) begin
            $display("STATUS=PASS");
        end else begin
            $display("STATUS=FAIL errors=%0d", errors);
        end

        $finish;
    end

endmodule
