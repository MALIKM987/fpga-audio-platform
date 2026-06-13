`timescale 1ns/1ps
`include "rtl/cpu/mini_cpu_defs.vh"

module mini_cpu_fft_impulse_program_tb;

    localparam integer DATA_WIDTH = 16;
    localparam integer ADDR_WIDTH = 16;
    localparam integer TIMEOUT_CYCLES = 500000;

    localparam [ADDR_WIDTH-1:0] FFT_STATUS = 16'h9001;
    localparam [DATA_WIDTH-1:0] GPIO_PASS  = 16'h00A5;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg test_bus_en = 1'b0;
    reg [ADDR_WIDTH-1:0] test_bus_addr = {ADDR_WIDTH{1'b0}};
    reg [DATA_WIDTH-1:0] test_bus_wdata = {DATA_WIDTH{1'b0}};
    reg test_bus_we = 1'b0;
    reg test_bus_re = 1'b0;

    wire [DATA_WIDTH-1:0] test_bus_rdata;
    wire test_bus_ready;
    wire [DATA_WIDTH-1:0] gpio_result;
    wire [DATA_WIDTH-1:0] debug_out0;
    wire [DATA_WIDTH-1:0] debug_out1;
    wire [DATA_WIDTH-1:0] debug_out2;
    wire [DATA_WIDTH-1:0] debug_out16;
    wire [DATA_WIDTH-1:0] debug_out64;
    wire [DATA_WIDTH-1:0] debug_out128;
    wire [DATA_WIDTH-1:0] debug_out255;
    wire cpu_halted;
    wire fft_busy;
    wire fft_done;
    wire fft_overflow;
    wire fft_error;
    wire [ADDR_WIDTH-1:0] bus_addr_debug;
    wire [DATA_WIDTH-1:0] bus_wdata_debug;
    wire bus_we_debug;
    wire bus_re_debug;
    wire [ADDR_WIDTH-1:0] debug_pc;
    wire debug_zero_flag;
    wire [DATA_WIDTH-1:0] debug_reg0;
    wire [DATA_WIDTH-1:0] debug_reg1;
    wire [DATA_WIDTH-1:0] debug_reg2;
    wire [DATA_WIDTH-1:0] debug_reg3;
    wire [DATA_WIDTH-1:0] debug_reg4;
    wire [DATA_WIDTH-1:0] debug_reg5;
    wire [DATA_WIDTH-1:0] debug_reg6;
    wire [DATA_WIDTH-1:0] debug_reg7;

    integer errors = 0;
    integer timeout_count = 0;
    reg [DATA_WIDTH-1:0] status_value;
    integer outputs_ok = 1;

    mini_cpu_fft_system #(
        .PROGRAM_ID(`MINI_CPU_PROGRAM_FFT_IMPULSE)
    ) dut (
        .clk(clk),
        .rst(rst),
        .test_bus_en(test_bus_en),
        .test_bus_addr(test_bus_addr),
        .test_bus_wdata(test_bus_wdata),
        .test_bus_we(test_bus_we),
        .test_bus_re(test_bus_re),
        .test_bus_rdata(test_bus_rdata),
        .test_bus_ready(test_bus_ready),
        .gpio_result(gpio_result),
        .debug_out0(debug_out0),
        .debug_out1(debug_out1),
        .debug_out2(debug_out2),
        .debug_out16(debug_out16),
        .debug_out64(debug_out64),
        .debug_out128(debug_out128),
        .debug_out255(debug_out255),
        .cpu_halted(cpu_halted),
        .fft_busy(fft_busy),
        .fft_done(fft_done),
        .fft_overflow(fft_overflow),
        .fft_error(fft_error),
        .bus_addr_debug(bus_addr_debug),
        .bus_wdata_debug(bus_wdata_debug),
        .bus_we_debug(bus_we_debug),
        .bus_re_debug(bus_re_debug),
        .debug_pc(debug_pc),
        .debug_zero_flag(debug_zero_flag),
        .debug_reg0(debug_reg0),
        .debug_reg1(debug_reg1),
        .debug_reg2(debug_reg2),
        .debug_reg3(debug_reg3),
        .debug_reg4(debug_reg4),
        .debug_reg5(debug_reg5),
        .debug_reg6(debug_reg6),
        .debug_reg7(debug_reg7)
    );

    always #5 clk = ~clk;

    task report_result;
        input [8*56-1:0] name;
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

    task host_read;
        input [ADDR_WIDTH-1:0] addr;
        output [DATA_WIDTH-1:0] data;
        begin
            @(negedge clk);
            test_bus_en = 1'b1;
            test_bus_we = 1'b0;
            test_bus_re = 1'b1;
            test_bus_addr = addr;
            #1;

            while (test_bus_ready !== 1'b1) begin
                @(posedge clk);
                #1;
            end

            data = test_bus_rdata;

            @(negedge clk);
            test_bus_re = 1'b0;
            test_bus_addr = {ADDR_WIDTH{1'b0}};
            test_bus_en = 1'b0;
        end
    endtask

    function integer sample_close;
        input signed [DATA_WIDTH-1:0] actual;
        input signed [DATA_WIDTH-1:0] expected;
        reg signed [DATA_WIDTH:0] diff;
        begin
            diff = {actual[DATA_WIDTH-1], actual} -
                   {expected[DATA_WIDTH-1], expected};
            sample_close = (diff <= 17'sd2) && (diff >= -17'sd2);
        end
    endfunction

    task check_sample;
        input [8*16-1:0] name;
        input signed [DATA_WIDTH-1:0] actual;
        input signed [DATA_WIDTH-1:0] expected;
        begin
            if (!sample_close(actual, expected)) begin
                outputs_ok = 0;
                $display("  %0s expected=%0d actual=%0d",
                         name, expected, actual);
            end
        end
    endtask

    initial begin
        $display("=== MINI CPU FFT IMPULSE PROGRAM TEST ===");
        $display("FRAME=impulse64");
        $display("EXPECTED=CPU writes PASS after DONE and readback");
        $display("");

        repeat (3) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        while (!cpu_halted && timeout_count < TIMEOUT_CYCLES) begin
            @(posedge clk);
            #1;
            timeout_count = timeout_count + 1;
        end

        host_read(FFT_STATUS, status_value);

        check_sample("output0", debug_out0, 16'sd64);
        check_sample("output1", debug_out1, 16'sd0);
        check_sample("output2", debug_out2, 16'sd0);
        check_sample("output16", debug_out16, 16'sd0);
        check_sample("output64", debug_out64, 16'sd0);
        check_sample("output128", debug_out128, 16'sd0);
        check_sample("output255", debug_out255, 16'sd0);

        report_result("cpu_program_halted", cpu_halted === 1'b1);
        report_result("gpio_result_pass", gpio_result === GPIO_PASS);
        report_result("status_done_latched", status_value[1] === 1'b1);
        report_result("status_no_overflow_error",
                      (status_value[2] === 1'b0) &&
                      (status_value[3] === 1'b0));
        report_result("cpu_readback_selected_outputs", outputs_ok);

        $display("");
        if (errors == 0) begin
            $display("STATUS=PASS");
        end else begin
            $display("STATUS=FAIL errors=%0d", errors);
        end

        $finish;
    end

endmodule
