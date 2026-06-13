`timescale 1ns/1ps
`include "rtl/cpu/mini_cpu_defs.vh"

module mini_cpu_branch_tb;

    localparam integer DATA_WIDTH = 16;
    localparam integer ADDR_WIDTH = 16;
    localparam integer TIMEOUT_CYCLES = 300;

    reg clk = 1'b0;
    reg rst = 1'b1;
    wire [ADDR_WIDTH-1:0] rom_addr;
    wire [DATA_WIDTH-1:0] rom_data;
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

    mini_cpu_program_rom #(
        .PROGRAM_ID(`MINI_CPU_PROGRAM_BRANCH),
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
        .bus_addr(),
        .bus_wdata(),
        .bus_rdata({DATA_WIDTH{1'b0}}),
        .bus_we(),
        .bus_re(),
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
        $display("=== MINI CPU BRANCH TEST ===");
        $display("");

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        while (!halted && timeout_count < TIMEOUT_CYCLES) begin
            @(posedge clk);
            #1;
            timeout_count = timeout_count + 1;
        end

        report_result("halted", halted === 1'b1);
        report_result("jz_taken", debug_reg1 === 16'h1111);
        report_result("jz_not_taken", debug_reg3 === 16'h2222);
        report_result("jnz_taken", debug_reg3 !== 16'h0BAD);
        report_result("jnz_not_taken", debug_reg5 === 16'h5555);
        report_result("jmp_taken", debug_reg5 !== 16'h0BAD);

        $display("");
        if (errors == 0) begin
            $display("STATUS=PASS");
        end else begin
            $display("STATUS=FAIL errors=%0d", errors);
        end

        $finish;
    end

endmodule
