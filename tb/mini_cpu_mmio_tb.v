`timescale 1ns/1ps
`include "rtl/cpu/mini_cpu_defs.vh"

module mini_cpu_mmio_tb;

    localparam integer DATA_WIDTH = 16;
    localparam integer ADDR_WIDTH = 16;
    localparam integer TIMEOUT_CYCLES = 300;

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
    integer write_count = 0;
    integer read_count = 0;
    integer strobe_ok = 1;
    reg prev_bus_we = 1'b0;
    reg prev_bus_re = 1'b0;

    mini_cpu_system #(
        .PROGRAM_ID(`MINI_CPU_PROGRAM_MMIO),
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

    always @(posedge clk) begin
        #1;
        if (!rst) begin
            if (bus_we_debug) begin
                write_count = write_count + 1;

                if (prev_bus_we) begin
                    strobe_ok = 0;
                    $display("  write strobe lasted more than one sampled cycle");
                end

                if (write_count == 1) begin
                    if (bus_addr_debug !== 16'h8010 ||
                        bus_wdata_debug !== 16'h1234) begin
                        strobe_ok = 0;
                        $display("  write0 mismatch addr=%h data=%h",
                                 bus_addr_debug, bus_wdata_debug);
                    end
                end

                if (write_count == 2) begin
                    if (bus_addr_debug !== 16'h8012 ||
                        bus_wdata_debug !== 16'h1235) begin
                        strobe_ok = 0;
                        $display("  write1 mismatch addr=%h data=%h",
                                 bus_addr_debug, bus_wdata_debug);
                    end
                end
            end

            if (bus_re_debug) begin
                read_count = read_count + 1;

                if (prev_bus_re) begin
                    strobe_ok = 0;
                    $display("  read strobe lasted more than one sampled cycle");
                end

                if (bus_addr_debug !== 16'h8010) begin
                    strobe_ok = 0;
                    $display("  read mismatch addr=%h", bus_addr_debug);
                end
            end

            prev_bus_we = bus_we_debug;
            prev_bus_re = bus_re_debug;
        end
    end

    initial begin
        $display("=== MINI CPU MMIO TEST ===");
        $display("");

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        while (!cpu_halted && timeout_count < TIMEOUT_CYCLES) begin
            @(posedge clk);
            #1;
            timeout_count = timeout_count + 1;
        end

        report_result("halted", cpu_halted === 1'b1);
        report_result("st_writes_test_reg0", test_reg0 === 16'h1234);
        report_result("ld_reads_test_reg0", debug_reg1 === 16'h1235);
        report_result("st_writes_test_reg1", test_reg1 === 16'h1235);
        report_result("bus_strobes_single_cycle", strobe_ok);
        report_result("bus_transaction_counts",
                      (write_count == 2) && (read_count == 1));
        report_result("cpu_status_halted", cpu_status[0] === 1'b1);

        $display("");
        if (errors == 0) begin
            $display("STATUS=PASS");
        end else begin
            $display("STATUS=FAIL errors=%0d", errors);
        end

        $finish;
    end

endmodule
