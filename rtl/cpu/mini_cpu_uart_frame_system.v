`include "rtl/cpu/mini_cpu_defs.vh"

module mini_cpu_uart_frame_system #(
    parameter integer PROGRAM_ID     = `MINI_CPU_PROGRAM_UART_FRAME_ONCE,
    parameter integer FFT_SIZE       = 256,
    parameter integer SAMPLE_WIDTH   = 16,
    parameter integer DATA_WIDTH     = 16,
    parameter integer ADDR_WIDTH     = 16,
    parameter integer FFT_DATA_WIDTH = 32,
    parameter integer GAIN_WIDTH     = 16,
    parameter integer INDEX_WIDTH    = 8
) (
    input  wire                         clk,
    input  wire                         rst,

    output wire                         frame_cpu_wr_en,
    output wire                         frame_cpu_rd_en,
    output wire [ADDR_WIDTH-1:0]        frame_cpu_addr,
    output wire [DATA_WIDTH-1:0]        frame_cpu_wdata,
    input  wire [DATA_WIDTH-1:0]        frame_cpu_rdata,
    input  wire                         frame_cpu_ready,

    output reg  [DATA_WIDTH-1:0]        gpio_result,
    output wire                         cpu_halted,
    output wire                         fft_busy,
    output wire                         fft_done,
    output wire                         fft_overflow,
    output wire                         fft_error,

    output wire [ADDR_WIDTH-1:0]        bus_addr_debug,
    output wire [DATA_WIDTH-1:0]        bus_wdata_debug,
    output wire                         bus_we_debug,
    output wire                         bus_re_debug,
    output wire [ADDR_WIDTH-1:0]        debug_pc,
    output wire                         debug_zero_flag,
    output wire [DATA_WIDTH-1:0]        debug_reg0,
    output wire [DATA_WIDTH-1:0]        debug_reg1,
    output wire [DATA_WIDTH-1:0]        debug_reg2,
    output wire [DATA_WIDTH-1:0]        debug_reg3,
    output wire [DATA_WIDTH-1:0]        debug_reg4,
    output wire [DATA_WIDTH-1:0]        debug_reg5,
    output wire [DATA_WIDTH-1:0]        debug_reg6,
    output wire [DATA_WIDTH-1:0]        debug_reg7,

    output reg                          debug_saw_frame_request,
    output reg                          debug_fft_start_written,
    output reg  [DATA_WIDTH-1:0]        debug_fft_bass_gain_written,
    output reg  [DATA_WIDTH-1:0]        debug_fft_mid_gain_written,
    output reg  [DATA_WIDTH-1:0]        debug_fft_treble_gain_written,
    output reg  [DATA_WIDTH-1:0]        debug_fft_input0_written,
    output reg  [DATA_WIDTH-1:0]        debug_fft_input1_written,
    output reg  [DATA_WIDTH-1:0]        debug_fft_input2_written,
    output reg  [DATA_WIDTH-1:0]        debug_fft_input16_written,
    output reg  [DATA_WIDTH-1:0]        debug_fft_input64_written,
    output reg  [DATA_WIDTH-1:0]        debug_fft_input128_written,
    output reg  [DATA_WIDTH-1:0]        debug_fft_input255_written,
    output reg                          debug_frame_result0_written
);

    localparam [ADDR_WIDTH-1:0] GPIO_RESULT_ADDR = 16'h8000;
    localparam [ADDR_WIDTH-1:0] CPU_STATUS_ADDR  = 16'h8020;

    localparam [ADDR_WIDTH-1:0] FFT_REG_BASE     = 16'h9000;
    localparam [ADDR_WIDTH-1:0] FFT_REG_LAST     = 16'h9006;
    localparam [ADDR_WIDTH-1:0] FFT_INPUT_BASE   = 16'h9100;
    localparam [ADDR_WIDTH-1:0] FFT_OUTPUT_BASE  = 16'h9200;

    localparam [ADDR_WIDTH-1:0] FRAME_REG_BASE    = 16'hA000;
    localparam [ADDR_WIDTH-1:0] FRAME_REG_LAST    = 16'hA005;
    localparam [ADDR_WIDTH-1:0] FRAME_INPUT_BASE  = 16'hA100;
    localparam [ADDR_WIDTH-1:0] FRAME_RESULT_BASE = 16'hA200;

    wire [ADDR_WIDTH-1:0] rom_addr;
    wire [DATA_WIDTH-1:0] rom_data;

    wire [ADDR_WIDTH-1:0] cpu_bus_addr;
    wire [DATA_WIDTH-1:0] cpu_bus_wdata;
    wire [DATA_WIDTH-1:0] cpu_bus_rdata;
    wire cpu_bus_we;
    wire cpu_bus_re;
    wire cpu_bus_ready;

    wire fft_reg_hit;
    wire fft_input_hit;
    wire fft_output_hit;
    wire fft_hit;
    wire fft_read_hit;
    wire fft_write_hit;
    wire [ADDR_WIDTH-1:0] fft_addr;
    wire [FFT_DATA_WIDTH-1:0] fft_wr_data;
    wire [FFT_DATA_WIDTH-1:0] fft_rd_data;
    wire fft_wr_en;
    wire fft_rd_en;

    wire frame_reg_hit;
    wire frame_input_hit;
    wire frame_result_hit;
    wire frame_hit;

    reg fft_read_wait = 1'b0;

    assign bus_addr_debug = cpu_bus_addr;
    assign bus_wdata_debug = cpu_bus_wdata;
    assign bus_we_debug = cpu_bus_we;
    assign bus_re_debug = cpu_bus_re;

    assign fft_reg_hit = (cpu_bus_addr >= FFT_REG_BASE) &&
                         (cpu_bus_addr <= FFT_REG_LAST);
    assign fft_input_hit = (cpu_bus_addr >= FFT_INPUT_BASE) &&
                           (cpu_bus_addr < FFT_INPUT_BASE + FFT_SIZE);
    assign fft_output_hit = (cpu_bus_addr >= FFT_OUTPUT_BASE) &&
                            (cpu_bus_addr < FFT_OUTPUT_BASE + FFT_SIZE);
    assign fft_hit = fft_reg_hit | fft_input_hit | fft_output_hit;
    assign fft_read_hit = cpu_bus_re & fft_hit;
    assign fft_write_hit = cpu_bus_we & (fft_reg_hit | fft_input_hit);
    assign fft_wr_en = fft_write_hit;
    assign fft_rd_en = fft_read_hit & ~fft_read_wait;
    assign fft_wr_data = {{(FFT_DATA_WIDTH-DATA_WIDTH)
                          {cpu_bus_wdata[DATA_WIDTH-1]}},
                          cpu_bus_wdata};

    assign frame_reg_hit = (cpu_bus_addr >= FRAME_REG_BASE) &&
                           (cpu_bus_addr <= FRAME_REG_LAST);
    assign frame_input_hit = (cpu_bus_addr >= FRAME_INPUT_BASE) &&
                             (cpu_bus_addr < FRAME_INPUT_BASE + FFT_SIZE);
    assign frame_result_hit = (cpu_bus_addr >= FRAME_RESULT_BASE) &&
                              (cpu_bus_addr < FRAME_RESULT_BASE + FFT_SIZE);
    assign frame_hit = frame_reg_hit | frame_input_hit | frame_result_hit;

    assign frame_cpu_wr_en = cpu_bus_we & frame_hit;
    assign frame_cpu_rd_en = cpu_bus_re & frame_hit;
    assign frame_cpu_addr = cpu_bus_addr;
    assign frame_cpu_wdata = cpu_bus_wdata;

    assign cpu_bus_ready = fft_read_hit ? fft_read_wait :
                           frame_hit ? frame_cpu_ready :
                           1'b1;
    assign cpu_bus_rdata = fft_read_hit ? fft_rd_data[DATA_WIDTH-1:0] :
                           frame_hit ? frame_cpu_rdata :
                           local_read_data(cpu_bus_addr);

    function [ADDR_WIDTH-1:0] map_fft_addr;
        input [ADDR_WIDTH-1:0] cpu_addr;
        begin
            if (cpu_addr >= FFT_INPUT_BASE &&
                cpu_addr < FFT_INPUT_BASE + FFT_SIZE) begin
                map_fft_addr = 16'h0100 + cpu_addr[INDEX_WIDTH-1:0];
            end else if (cpu_addr >= FFT_OUTPUT_BASE &&
                         cpu_addr < FFT_OUTPUT_BASE + FFT_SIZE) begin
                map_fft_addr = 16'h0200 + cpu_addr[INDEX_WIDTH-1:0];
            end else begin
                map_fft_addr = cpu_addr - FFT_REG_BASE;
            end
        end
    endfunction

    function [DATA_WIDTH-1:0] local_read_data;
        input [ADDR_WIDTH-1:0] addr;
        begin
            if (addr == GPIO_RESULT_ADDR) begin
                local_read_data = gpio_result;
            end else if (addr == CPU_STATUS_ADDR) begin
                local_read_data = {{(DATA_WIDTH-1){1'b0}}, cpu_halted};
            end else begin
                local_read_data = {DATA_WIDTH{1'b0}};
            end
        end
    endfunction

    assign fft_addr = map_fft_addr(cpu_bus_addr);

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
        .bus_addr(cpu_bus_addr),
        .bus_wdata(cpu_bus_wdata),
        .bus_rdata(cpu_bus_rdata),
        .bus_we(cpu_bus_we),
        .bus_re(cpu_bus_re),
        .bus_ready(cpu_bus_ready),
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

    fft_accelerator_mmio #(
        .FFT_SIZE(FFT_SIZE),
        .SAMPLE_WIDTH(SAMPLE_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(FFT_DATA_WIDTH),
        .GAIN_WIDTH(GAIN_WIDTH),
        .INDEX_WIDTH(INDEX_WIDTH)
    ) fft_accel_inst (
        .clk(clk),
        .rst(rst),
        .wr_en(fft_wr_en),
        .wr_addr(fft_addr),
        .wr_data(fft_wr_data),
        .rd_en(fft_rd_en),
        .rd_addr(fft_addr),
        .rd_data(fft_rd_data),
        .busy(fft_busy),
        .done(fft_done),
        .overflow(fft_overflow),
        .error(fft_error)
    );

    always @(posedge clk) begin
        if (rst) begin
            fft_read_wait <= 1'b0;
            gpio_result <= {DATA_WIDTH{1'b0}};
            debug_saw_frame_request <= 1'b0;
            debug_fft_start_written <= 1'b0;
            debug_fft_bass_gain_written <= {DATA_WIDTH{1'b0}};
            debug_fft_mid_gain_written <= {DATA_WIDTH{1'b0}};
            debug_fft_treble_gain_written <= {DATA_WIDTH{1'b0}};
            debug_fft_input0_written <= {DATA_WIDTH{1'b0}};
            debug_fft_input1_written <= {DATA_WIDTH{1'b0}};
            debug_fft_input2_written <= {DATA_WIDTH{1'b0}};
            debug_fft_input16_written <= {DATA_WIDTH{1'b0}};
            debug_fft_input64_written <= {DATA_WIDTH{1'b0}};
            debug_fft_input128_written <= {DATA_WIDTH{1'b0}};
            debug_fft_input255_written <= {DATA_WIDTH{1'b0}};
            debug_frame_result0_written <= 1'b0;
        end else begin
            if (fft_read_wait) begin
                fft_read_wait <= 1'b0;
            end else if (fft_read_hit) begin
                fft_read_wait <= 1'b1;
            end

            if (cpu_bus_we && !fft_hit && !frame_hit) begin
                if (cpu_bus_addr == GPIO_RESULT_ADDR) begin
                    gpio_result <= cpu_bus_wdata;
                end
            end

            if (cpu_bus_re && cpu_bus_addr == FRAME_REG_BASE &&
                frame_cpu_rdata[0]) begin
                debug_saw_frame_request <= 1'b1;
            end

            if (fft_write_hit) begin
                if (cpu_bus_addr == 16'h9000 && cpu_bus_wdata[0]) begin
                    debug_fft_start_written <= 1'b1;
                end else if (cpu_bus_addr == 16'h9003) begin
                    debug_fft_bass_gain_written <= cpu_bus_wdata;
                end else if (cpu_bus_addr == 16'h9004) begin
                    debug_fft_mid_gain_written <= cpu_bus_wdata;
                end else if (cpu_bus_addr == 16'h9005) begin
                    debug_fft_treble_gain_written <= cpu_bus_wdata;
                end else if (cpu_bus_addr == 16'h9100) begin
                    debug_fft_input0_written <= cpu_bus_wdata;
                end else if (cpu_bus_addr == 16'h9101) begin
                    debug_fft_input1_written <= cpu_bus_wdata;
                end else if (cpu_bus_addr == 16'h9102) begin
                    debug_fft_input2_written <= cpu_bus_wdata;
                end else if (cpu_bus_addr == 16'h9110) begin
                    debug_fft_input16_written <= cpu_bus_wdata;
                end else if (cpu_bus_addr == 16'h9140) begin
                    debug_fft_input64_written <= cpu_bus_wdata;
                end else if (cpu_bus_addr == 16'h9180) begin
                    debug_fft_input128_written <= cpu_bus_wdata;
                end else if (cpu_bus_addr == 16'h91FF) begin
                    debug_fft_input255_written <= cpu_bus_wdata;
                end
            end

            if (frame_cpu_wr_en && cpu_bus_addr == FRAME_RESULT_BASE) begin
                debug_frame_result0_written <= 1'b1;
            end
        end
    end

endmodule
