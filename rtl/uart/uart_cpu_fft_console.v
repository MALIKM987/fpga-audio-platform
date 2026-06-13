`include "rtl/cpu/mini_cpu_defs.vh"

module uart_cpu_fft_console #(
    parameter integer CLK_FREQ_HZ = 27_000_000,
    parameter integer BAUD_RATE   = 115_200,
    parameter integer TIMEOUT_CYCLES = 500_000
) (
    input  wire clk,
    input  wire rst,
    input  wire uart_rx,
    output wire uart_tx,

    output wire console_busy,
    output reg  command_accepted,
    output reg  command_ignored,
    output wire response_active,
    output wire cpu_halted_debug,
    output wire [15:0] gpio_result_debug,
    output wire [15:0] debug_out0,
    output wire [15:0] debug_out1,
    output wire [15:0] debug_out2,
    output wire [15:0] debug_out16,
    output wire [15:0] debug_out64,
    output wire [15:0] debug_out128,
    output wire [15:0] debug_out255
);

    localparam [7:0] START_BYTE = 8'hA5;
    localparam [7:0] END_BYTE = 8'h5A;
    localparam [7:0] CMD_RUN_IMPULSE = 8'h01;
    localparam [7:0] RSP_RUN_IMPULSE = 8'h81;

    localparam [2:0] CMD_WAIT_START = 3'd0;
    localparam [2:0] CMD_WAIT_ID    = 3'd1;
    localparam [2:0] CMD_WAIT_END   = 3'd2;

    localparam [2:0] STATE_IDLE       = 3'd0;
    localparam [2:0] STATE_RESET_CPU  = 3'd1;
    localparam [2:0] STATE_RUN_CPU    = 3'd2;
    localparam [2:0] STATE_SEND_BYTE  = 3'd3;
    localparam [2:0] STATE_WAIT_BUSY  = 3'd4;
    localparam [2:0] STATE_WAIT_DONE  = 3'd5;

    localparam integer RESET_CYCLES = 8;
    localparam integer RESPONSE_LEN = 18;

    wire [7:0] rx_data;
    wire rx_valid;
    wire rx_frame_error;
    wire tx_busy;

    reg [2:0] cmd_state = CMD_WAIT_START;
    reg [2:0] state = STATE_IDLE;
    reg [31:0] run_counter = 32'd0;
    reg [3:0] reset_counter = 4'd0;
    reg [4:0] tx_index = 5'd0;
    reg [7:0] tx_data = 8'd0;
    reg tx_valid = 1'b0;
    reg cpu_rst_local = 1'b1;
    reg done_latched = 1'b0;
    reg overflow_latched = 1'b0;
    reg error_latched = 1'b0;
    reg timeout_latched = 1'b0;

    wire cpu_halted;
    wire fft_busy;
    wire fft_done;
    wire fft_overflow;
    wire fft_error;
    wire [15:0] gpio_result;
    wire [15:0] unused_test_bus_rdata;
    wire unused_test_bus_ready;
    wire [15:0] unused_bus_addr_debug;
    wire [15:0] unused_bus_wdata_debug;
    wire unused_bus_we_debug;
    wire unused_bus_re_debug;
    wire [15:0] unused_debug_pc;
    wire unused_debug_zero_flag;
    wire [15:0] unused_debug_reg0;
    wire [15:0] unused_debug_reg1;
    wire [15:0] unused_debug_reg2;
    wire [15:0] unused_debug_reg3;
    wire [15:0] unused_debug_reg4;
    wire [15:0] unused_debug_reg5;
    wire [15:0] unused_debug_reg6;
    wire [15:0] unused_debug_reg7;

    assign console_busy = (state != STATE_IDLE);
    assign response_active = (state == STATE_SEND_BYTE) ||
                             (state == STATE_WAIT_BUSY) ||
                             (state == STATE_WAIT_DONE);
    assign cpu_halted_debug = cpu_halted;
    assign gpio_result_debug = gpio_result;

    uart_rx #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE(BAUD_RATE)
    ) uart_rx_inst (
        .clk(clk),
        .rst(rst),
        .rx(uart_rx),
        .data(rx_data),
        .valid(rx_valid),
        .frame_error(rx_frame_error)
    );

    uart_tx #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE(BAUD_RATE)
    ) uart_tx_inst (
        .clk(clk),
        .rst(rst),
        .data(tx_data),
        .valid(tx_valid),
        .tx(uart_tx),
        .busy(tx_busy)
    );

    mini_cpu_fft_system #(
        .PROGRAM_ID(`MINI_CPU_PROGRAM_FFT_IMPULSE)
    ) cpu_fft_system_inst (
        .clk(clk),
        .rst(rst | cpu_rst_local),
        .test_bus_en(1'b0),
        .test_bus_addr(16'd0),
        .test_bus_wdata(16'd0),
        .test_bus_we(1'b0),
        .test_bus_re(1'b0),
        .test_bus_rdata(unused_test_bus_rdata),
        .test_bus_ready(unused_test_bus_ready),
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
        .bus_addr_debug(unused_bus_addr_debug),
        .bus_wdata_debug(unused_bus_wdata_debug),
        .bus_we_debug(unused_bus_we_debug),
        .bus_re_debug(unused_bus_re_debug),
        .debug_pc(unused_debug_pc),
        .debug_zero_flag(unused_debug_zero_flag),
        .debug_reg0(unused_debug_reg0),
        .debug_reg1(unused_debug_reg1),
        .debug_reg2(unused_debug_reg2),
        .debug_reg3(unused_debug_reg3),
        .debug_reg4(unused_debug_reg4),
        .debug_reg5(unused_debug_reg5),
        .debug_reg6(unused_debug_reg6),
        .debug_reg7(unused_debug_reg7)
    );

    function [7:0] status_byte;
        begin
            status_byte = {3'b000,
                           timeout_latched,
                           error_latched,
                           overflow_latched,
                           done_latched,
                           (gpio_result == 16'h00A5) &&
                           done_latched &&
                           !overflow_latched &&
                           !error_latched &&
                           !timeout_latched};
        end
    endfunction

    function [7:0] response_byte;
        input [4:0] index;
        begin
            case (index)
                5'd0:  response_byte = START_BYTE;
                5'd1:  response_byte = RSP_RUN_IMPULSE;
                5'd2:  response_byte = status_byte();
                5'd3:  response_byte = debug_out0[7:0];
                5'd4:  response_byte = debug_out0[15:8];
                5'd5:  response_byte = debug_out1[7:0];
                5'd6:  response_byte = debug_out1[15:8];
                5'd7:  response_byte = debug_out2[7:0];
                5'd8:  response_byte = debug_out2[15:8];
                5'd9:  response_byte = debug_out16[7:0];
                5'd10: response_byte = debug_out16[15:8];
                5'd11: response_byte = debug_out64[7:0];
                5'd12: response_byte = debug_out64[15:8];
                5'd13: response_byte = debug_out128[7:0];
                5'd14: response_byte = debug_out128[15:8];
                5'd15: response_byte = debug_out255[7:0];
                5'd16: response_byte = debug_out255[15:8];
                5'd17: response_byte = END_BYTE;
                default: response_byte = 8'd0;
            endcase
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            cmd_state <= CMD_WAIT_START;
            state <= STATE_IDLE;
            run_counter <= 32'd0;
            reset_counter <= 4'd0;
            tx_index <= 5'd0;
            tx_data <= 8'd0;
            tx_valid <= 1'b0;
            cpu_rst_local <= 1'b1;
            done_latched <= 1'b0;
            overflow_latched <= 1'b0;
            error_latched <= 1'b0;
            timeout_latched <= 1'b0;
            command_accepted <= 1'b0;
            command_ignored <= 1'b0;
        end else begin
            command_accepted <= 1'b0;
            command_ignored <= 1'b0;
            tx_valid <= 1'b0;

            if (fft_done) begin
                done_latched <= 1'b1;
            end

            if (fft_overflow) begin
                overflow_latched <= 1'b1;
            end

            if (fft_error) begin
                error_latched <= 1'b1;
            end

            if (rx_valid) begin
                case (cmd_state)
                    CMD_WAIT_START: begin
                        if (rx_data == START_BYTE) begin
                            cmd_state <= CMD_WAIT_ID;
                        end
                    end

                    CMD_WAIT_ID: begin
                        if (rx_data == CMD_RUN_IMPULSE) begin
                            cmd_state <= CMD_WAIT_END;
                        end else if (rx_data == START_BYTE) begin
                            cmd_state <= CMD_WAIT_ID;
                            command_ignored <= 1'b1;
                        end else begin
                            cmd_state <= CMD_WAIT_START;
                            command_ignored <= 1'b1;
                        end
                    end

                    CMD_WAIT_END: begin
                        cmd_state <= CMD_WAIT_START;

                        if (rx_data == END_BYTE) begin
                            if (state == STATE_IDLE) begin
                                command_accepted <= 1'b1;
                                state <= STATE_RESET_CPU;
                                reset_counter <= 4'd0;
                                run_counter <= 32'd0;
                                cpu_rst_local <= 1'b1;
                                done_latched <= 1'b0;
                                overflow_latched <= 1'b0;
                                error_latched <= 1'b0;
                                timeout_latched <= 1'b0;
                            end else begin
                                command_ignored <= 1'b1;
                            end
                        end else begin
                            command_ignored <= 1'b1;
                        end
                    end

                    default: begin
                        cmd_state <= CMD_WAIT_START;
                    end
                endcase
            end

            case (state)
                STATE_IDLE: begin
                    cpu_rst_local <= 1'b1;
                end

                STATE_RESET_CPU: begin
                    cpu_rst_local <= 1'b1;

                    if (reset_counter == RESET_CYCLES - 1) begin
                        reset_counter <= 4'd0;
                        run_counter <= 32'd0;
                        cpu_rst_local <= 1'b0;
                        state <= STATE_RUN_CPU;
                    end else begin
                        reset_counter <= reset_counter + 4'd1;
                    end
                end

                STATE_RUN_CPU: begin
                    cpu_rst_local <= 1'b0;
                    run_counter <= run_counter + 32'd1;

                    if (cpu_halted) begin
                        tx_index <= 5'd0;
                        state <= STATE_SEND_BYTE;
                    end else if (run_counter >= TIMEOUT_CYCLES - 1) begin
                        timeout_latched <= 1'b1;
                        tx_index <= 5'd0;
                        state <= STATE_SEND_BYTE;
                    end
                end

                STATE_SEND_BYTE: begin
                    tx_data <= response_byte(tx_index);
                    tx_valid <= 1'b1;
                    state <= STATE_WAIT_BUSY;
                end

                STATE_WAIT_BUSY: begin
                    if (tx_busy) begin
                        state <= STATE_WAIT_DONE;
                    end
                end

                STATE_WAIT_DONE: begin
                    if (!tx_busy) begin
                        if (tx_index == RESPONSE_LEN - 1) begin
                            state <= STATE_IDLE;
                        end else begin
                            tx_index <= tx_index + 5'd1;
                            state <= STATE_SEND_BYTE;
                        end
                    end
                end

                default: begin
                    state <= STATE_IDLE;
                    cpu_rst_local <= 1'b1;
                end
            endcase
        end
    end

endmodule
