`include "rtl/cpu/mini_cpu_defs.vh"

module mini_cpu_system #(
    parameter integer PROGRAM_ID = `MINI_CPU_PROGRAM_GPIO,
    parameter integer DATA_WIDTH = 16,
    parameter integer ADDR_WIDTH = 16
) (
    input  wire                  clk,
    input  wire                  rst,

    output reg  [DATA_WIDTH-1:0] gpio_led,
    output reg  [DATA_WIDTH-1:0] test_reg0,
    output reg  [DATA_WIDTH-1:0] test_reg1,
    output wire [DATA_WIDTH-1:0] cpu_status,
    output wire                  cpu_halted,

    output wire [ADDR_WIDTH-1:0] bus_addr_debug,
    output wire [DATA_WIDTH-1:0] bus_wdata_debug,
    output wire                  bus_we_debug,
    output wire                  bus_re_debug,
    output wire [ADDR_WIDTH-1:0] debug_pc,
    output wire                  debug_zero_flag,
    output wire [DATA_WIDTH-1:0] debug_reg0,
    output wire [DATA_WIDTH-1:0] debug_reg1,
    output wire [DATA_WIDTH-1:0] debug_reg2,
    output wire [DATA_WIDTH-1:0] debug_reg3,
    output wire [DATA_WIDTH-1:0] debug_reg4,
    output wire [DATA_WIDTH-1:0] debug_reg5,
    output wire [DATA_WIDTH-1:0] debug_reg6,
    output wire [DATA_WIDTH-1:0] debug_reg7
);

    localparam [ADDR_WIDTH-1:0] GPIO_LED_ADDR   = 16'h8000;
    localparam [ADDR_WIDTH-1:0] TEST_REG0_ADDR  = 16'h8010;
    localparam [ADDR_WIDTH-1:0] TEST_REG1_ADDR  = 16'h8012;
    localparam [ADDR_WIDTH-1:0] CPU_STATUS_ADDR = 16'h8020;

    wire [ADDR_WIDTH-1:0] rom_addr;
    wire [DATA_WIDTH-1:0] rom_data;
    wire [ADDR_WIDTH-1:0] bus_addr;
    wire [DATA_WIDTH-1:0] bus_wdata;
    reg  [DATA_WIDTH-1:0] bus_rdata;
    wire bus_we;
    wire bus_re;
    wire bus_ready;

    assign bus_ready = 1'b1;
    assign cpu_status = {{(DATA_WIDTH-1){1'b0}}, cpu_halted};
    assign bus_addr_debug = bus_addr;
    assign bus_wdata_debug = bus_wdata;
    assign bus_we_debug = bus_we;
    assign bus_re_debug = bus_re;

    mini_cpu_program_rom #(
        .PROGRAM_ID(PROGRAM_ID),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) program_rom_inst (
        .addr(rom_addr),
        .data(rom_data)
    );

    mini_cpu_core #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) cpu_inst (
        .clk(clk),
        .rst(rst),
        .rom_addr(rom_addr),
        .rom_data(rom_data),
        .bus_addr(bus_addr),
        .bus_wdata(bus_wdata),
        .bus_rdata(bus_rdata),
        .bus_we(bus_we),
        .bus_re(bus_re),
        .bus_ready(bus_ready),
        .halted(cpu_halted),
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

    always @* begin
        case (bus_addr)
            GPIO_LED_ADDR: begin
                bus_rdata = gpio_led;
            end

            TEST_REG0_ADDR: begin
                bus_rdata = test_reg0;
            end

            TEST_REG1_ADDR: begin
                bus_rdata = test_reg1;
            end

            CPU_STATUS_ADDR: begin
                bus_rdata = cpu_status;
            end

            default: begin
                bus_rdata = {DATA_WIDTH{1'b0}};
            end
        endcase
    end

    always @(posedge clk) begin
        if (rst) begin
            gpio_led <= {DATA_WIDTH{1'b0}};
            test_reg0 <= {DATA_WIDTH{1'b0}};
            test_reg1 <= {DATA_WIDTH{1'b0}};
        end else if (bus_we) begin
            case (bus_addr)
                GPIO_LED_ADDR: begin
                    gpio_led <= bus_wdata;
                end

                TEST_REG0_ADDR: begin
                    test_reg0 <= bus_wdata;
                end

                TEST_REG1_ADDR: begin
                    test_reg1 <= bus_wdata;
                end

                default: begin
                end
            endcase
        end
    end

endmodule
