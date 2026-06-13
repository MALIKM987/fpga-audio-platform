`timescale 1ns/1ps
`include "rtl/cpu/mini_cpu_defs.vh"

module mini_cpu_fft_bus_decode_tb;

    localparam integer DATA_WIDTH = 16;
    localparam integer ADDR_WIDTH = 16;

    localparam [ADDR_WIDTH-1:0] GPIO_RESULT_ADDR = 16'h8000;
    localparam [ADDR_WIDTH-1:0] UNKNOWN_ADDR     = 16'h8800;
    localparam [ADDR_WIDTH-1:0] FFT_BASS_GAIN    = 16'h9003;
    localparam [ADDR_WIDTH-1:0] FFT_INPUT0       = 16'h9100;

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
    reg [DATA_WIDTH-1:0] read_value;

    mini_cpu_fft_system #(
        .PROGRAM_ID(`MINI_CPU_PROGRAM_FETCH_HALT)
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

    task host_write;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] data;
        begin
            @(negedge clk);
            test_bus_en = 1'b1;
            test_bus_we = 1'b1;
            test_bus_re = 1'b0;
            test_bus_addr = addr;
            test_bus_wdata = data;

            @(posedge clk);
            #1;

            @(negedge clk);
            test_bus_we = 1'b0;
            test_bus_addr = {ADDR_WIDTH{1'b0}};
            test_bus_wdata = {DATA_WIDTH{1'b0}};
            test_bus_en = 1'b0;
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

    initial begin
        $display("=== MINI CPU FFT BUS DECODE TEST ===");
        $display("");

        repeat (3) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        host_write(GPIO_RESULT_ADDR, 16'h00A5);
        host_read(GPIO_RESULT_ADDR, read_value);
        report_result("gpio_region_write_read",
                      (gpio_result === 16'h00A5) &&
                      (read_value === 16'h00A5));

        host_write(FFT_BASS_GAIN, 16'h1111);
        host_read(FFT_BASS_GAIN, read_value);
        report_result("fft_region_write_read", read_value === 16'h1111);
        report_result("fft_write_does_not_touch_gpio",
                      gpio_result === 16'h00A5);

        host_write(FFT_INPUT0, 16'h0040);
        host_read(FFT_INPUT0, read_value);
        report_result("fft_input_sample_decode", read_value === 16'h0040);

        host_read(UNKNOWN_ADDR, read_value);
        report_result("unknown_read_returns_zero", read_value === 16'h0000);

        host_write(UNKNOWN_ADDR, 16'h2222);
        host_read(FFT_BASS_GAIN, read_value);
        report_result("unknown_write_does_not_touch_fft",
                      read_value === 16'h1111);
        report_result("unknown_write_does_not_touch_gpio",
                      gpio_result === 16'h00A5);

        $display("");
        if (errors == 0) begin
            $display("STATUS=PASS");
        end else begin
            $display("STATUS=FAIL errors=%0d", errors);
        end

        $finish;
    end

endmodule
