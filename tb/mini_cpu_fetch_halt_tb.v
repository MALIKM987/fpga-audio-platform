`timescale 1ns/1ps
`include "rtl/cpu/mini_cpu_defs.vh"

module mini_cpu_fetch_halt_tb;

    localparam integer DATA_WIDTH = 16;
    localparam integer ADDR_WIDTH = 16;
    localparam integer TIMEOUT_CYCLES = 100;

    reg clk = 1'b0;
    reg rst = 1'b1;
    wire [ADDR_WIDTH-1:0] rom_addr;
    wire [DATA_WIDTH-1:0] rom_data;
    wire [ADDR_WIDTH-1:0] bus_addr;
    wire [DATA_WIDTH-1:0] bus_wdata;
    wire [DATA_WIDTH-1:0] bus_rdata;
    wire bus_we;
    wire bus_re;
    wire halted;
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
    reg [ADDR_WIDTH-1:0] halted_pc;

    assign bus_rdata = {DATA_WIDTH{1'b0}};

    mini_cpu_program_rom #(
        .PROGRAM_ID(`MINI_CPU_PROGRAM_FETCH_HALT),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) rom_inst (
        .addr(rom_addr),
        .data(rom_data)
    );

    mini_cpu_core #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .rom_addr(rom_addr),
        .rom_data(rom_data),
        .bus_addr(bus_addr),
        .bus_wdata(bus_wdata),
        .bus_rdata(bus_rdata),
        .bus_we(bus_we),
        .bus_re(bus_re),
        .bus_ready(1'b1),
        .halted(halted),
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
        $display("=== MINI CPU FETCH/HALT TEST ===");
        $display("");

        repeat (2) @(posedge clk);
        #1;
        report_result("starts_from_pc0",
                      (debug_pc === 16'd0) &&
                      (rom_addr === 16'd0) &&
                      (halted === 1'b0));

        @(negedge clk);
        rst = 1'b0;

        while (!halted && timeout_count < TIMEOUT_CYCLES) begin
            @(posedge clk);
            #1;
            timeout_count = timeout_count + 1;
        end

        halted_pc = debug_pc;
        report_result("fetches_and_halts", halted === 1'b1);
        report_result("pc_after_sequential_fetch", halted_pc === 16'd3);
        report_result("no_mmio_on_fetch_halt",
                      (bus_we === 1'b0) && (bus_re === 1'b0));

        repeat (4) @(posedge clk);
        #1;
        report_result("halt_stops_pc", debug_pc === halted_pc);
        report_result("halted_status", halted === 1'b1);

        $display("");
        if (errors == 0) begin
            $display("STATUS=PASS");
        end else begin
            $display("STATUS=FAIL errors=%0d", errors);
        end

        $finish;
    end

endmodule
