`timescale 1ns/1ps
`include "rtl/cpu/mini_cpu_defs.vh"

module mini_cpu_gpio_program_tb;

    localparam integer DATA_WIDTH = 16;
    localparam integer ADDR_WIDTH = 16;
    localparam integer TIMEOUT_CYCLES = 120;

    reg clk = 1'b0;
    reg rst = 1'b1;
    wire [DATA_WIDTH-1:0] gpio_led;
    wire [DATA_WIDTH-1:0] test_reg0;
    wire [DATA_WIDTH-1:0] test_reg1;
    wire [DATA_WIDTH-1:0] cpu_status;
    wire cpu_halted;
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

    mini_cpu_system #(
        .PROGRAM_ID(`MINI_CPU_PROGRAM_GPIO),
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .gpio_led(gpio_led),
        .test_reg0(test_reg0),
        .test_reg1(test_reg1),
        .cpu_status(cpu_status),
        .cpu_halted(cpu_halted),
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
        input [8*48-1:0] name;
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
        $display("=== MINI CPU GPIO PROGRAM TEST ===");
        $display("");

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        while (!cpu_halted && timeout_count < TIMEOUT_CYCLES) begin
            @(posedge clk);
            #1;
            timeout_count = timeout_count + 1;
        end

        report_result("program_halted", cpu_halted === 1'b1);
        report_result("gpio_led_pass_value", gpio_led === 16'h00A5);
        report_result("cpu_status_halted", cpu_status[0] === 1'b1);
        report_result("no_unexpected_test_reg_writes",
                      (test_reg0 === 16'h0000) &&
                      (test_reg1 === 16'h0000));

        $display("");
        if (errors == 0) begin
            $display("STATUS=PASS");
        end else begin
            $display("STATUS=FAIL errors=%0d", errors);
        end

        $finish;
    end

endmodule
