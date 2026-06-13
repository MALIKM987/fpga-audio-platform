module tang_cpu_owned_frame_uart_top #(
    parameter integer CLK_FREQ_HZ = 27_000_000,
    parameter integer BAUD_RATE = 115_200,
    parameter integer RESET_COUNT_MAX = 65535,
    parameter integer BLINK_COUNTER_WIDTH = 24,
    parameter integer LED_ACTIVE_LOW = 1,
    parameter integer MAX_PAYLOAD_LEN = 128,
    parameter integer PAYLOAD_ADDR_WIDTH = 8
) (
    input  wire clk,
    input  wire uart_rx,
    output wire uart_tx,
    output wire led
);

    localparam integer FAST_BLINK_BIT = (BLINK_COUNTER_WIDTH > 4) ?
                                        (BLINK_COUNTER_WIDTH - 4) : 0;
    localparam integer SLOW_BLINK_BIT = BLINK_COUNTER_WIDTH - 1;

    localparam [7:0] STATUS_CPU_BUSY = 8'h02;
    localparam [7:0] STATUS_DONE     = 8'h04;
    localparam [7:0] STATUS_ERROR    = 8'h08;
    localparam [7:0] STATUS_TIMEOUT  = 8'h10;

    reg [31:0] rst_cnt = 32'd0;
    reg rst = 1'b1;
    reg [BLINK_COUNTER_WIDTH-1:0] blink_counter =
        {BLINK_COUNTER_WIDTH{1'b0}};
    reg pass_latched = 1'b0;
    reg error_latched = 1'b0;

    wire [7:0] rx_byte_data;
    wire rx_byte_valid;
    wire rx_frame_error;

    wire packet_valid;
    wire [7:0] packet_cmd;
    wire [7:0] packet_seq;
    wire [15:0] packet_payload_len;
    wire [PAYLOAD_ADDR_WIDTH-1:0] packet_payload_rd_addr;
    wire [7:0] packet_payload_rd_data;
    wire packet_error_bad_checksum;
    wire packet_error_bad_eof;
    wire packet_error_length_too_large;
    wire packet_error_malformed;

    wire backend_tx_start;
    wire [7:0] backend_tx_cmd;
    wire [7:0] backend_tx_seq;
    wire [15:0] backend_tx_payload_len;
    wire [PAYLOAD_ADDR_WIDTH-1:0] backend_tx_payload_rd_addr;
    wire [7:0] backend_tx_payload_rd_data;
    wire backend_ack_pulse;
    wire backend_error_pulse;
    wire frame_loaded;
    wire frame_done;
    wire [15:0] bass_gain_q2_14;
    wire [15:0] mid_gain_q2_14;
    wire [15:0] treble_gain_q2_14;
    wire [7:0] status_debug;
    wire signed [15:0] debug_input_sample;
    wire signed [15:0] debug_result_sample;

    wire packet_tx_valid;
    wire [7:0] packet_tx_data;
    wire packet_tx_busy;
    wire packet_tx_done;
    wire packet_tx_error_length_too_large;

    wire uart_tx_busy;
    reg uart_tx_byte_pending = 1'b0;
    reg [7:0] uart_tx_byte_buffer = 8'd0;
    wire uart_tx_ready = !uart_tx_byte_pending && !uart_tx_busy &&
                         !packet_tx_valid;
    wire uart_tx_byte_valid = uart_tx_byte_pending && !uart_tx_busy;

    wire frame_cpu_wr_en;
    wire frame_cpu_rd_en;
    wire [15:0] frame_cpu_addr;
    wire [15:0] frame_cpu_wdata;
    wire [15:0] frame_cpu_rdata;
    wire frame_cpu_ready;

    wire [15:0] gpio_result;
    wire cpu_halted;
    wire fft_busy;
    wire fft_done;
    wire fft_overflow;
    wire fft_error;
    wire [15:0] bus_addr_debug;
    wire [15:0] bus_wdata_debug;
    wire bus_we_debug;
    wire bus_re_debug;
    wire [15:0] debug_pc;
    wire debug_zero_flag;
    wire [15:0] debug_reg0;
    wire [15:0] debug_reg1;
    wire [15:0] debug_reg2;
    wire [15:0] debug_reg3;
    wire [15:0] debug_reg4;
    wire [15:0] debug_reg5;
    wire [15:0] debug_reg6;
    wire [15:0] debug_reg7;
    wire debug_saw_frame_request;
    wire debug_fft_start_written;
    wire [15:0] debug_fft_bass_gain_written;
    wire [15:0] debug_fft_mid_gain_written;
    wire [15:0] debug_fft_treble_gain_written;
    wire [15:0] debug_fft_input0_written;
    wire [15:0] debug_fft_input1_written;
    wire [15:0] debug_fft_input2_written;
    wire [15:0] debug_fft_input16_written;
    wire [15:0] debug_fft_input64_written;
    wire [15:0] debug_fft_input128_written;
    wire [15:0] debug_fft_input255_written;
    wire debug_frame_result0_written;

    wire fast_blink = blink_counter[FAST_BLINK_BIT];
    wire slow_blink = blink_counter[SLOW_BLINK_BIT];
    wire activity = rx_byte_valid | packet_valid | backend_ack_pulse |
                    backend_tx_start | packet_tx_busy | uart_tx_busy |
                    bus_we_debug | bus_re_debug | fft_busy |
                    ((status_debug & STATUS_CPU_BUSY) != 8'd0);
    wire status_done_ok = ((status_debug & STATUS_DONE) != 8'd0) &&
                          ((status_debug & (STATUS_ERROR | STATUS_TIMEOUT)) == 8'd0);
    wire status_error = ((status_debug & (STATUS_ERROR | STATUS_TIMEOUT)) != 8'd0);
    wire rx_error = rx_frame_error | packet_error_bad_checksum |
                    packet_error_bad_eof | packet_error_length_too_large |
                    packet_error_malformed | packet_tx_error_length_too_large;
    wire led_raw;

    assign led_raw = error_latched ? fast_blink :
                     pass_latched ? 1'b1 :
                     activity ? fast_blink :
                     slow_blink;

    assign led = LED_ACTIVE_LOW ? ~led_raw : led_raw;

    uart_rx #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE(BAUD_RATE)
    ) uart_rx_inst (
        .clk(clk),
        .rst(rst),
        .rx(uart_rx),
        .data(rx_byte_data),
        .valid(rx_byte_valid),
        .frame_error(rx_frame_error)
    );

    uart_frame_packet_rx #(
        .MAX_PAYLOAD_LEN(MAX_PAYLOAD_LEN),
        .PAYLOAD_ADDR_WIDTH(PAYLOAD_ADDR_WIDTH)
    ) packet_rx_inst (
        .clk(clk),
        .rst(rst),
        .rx_valid(rx_byte_valid),
        .rx_data(rx_byte_data),
        .packet_valid(packet_valid),
        .cmd(packet_cmd),
        .seq(packet_seq),
        .payload_len(packet_payload_len),
        .payload_rd_addr(packet_payload_rd_addr),
        .payload_rd_data(packet_payload_rd_data),
        .error_bad_checksum(packet_error_bad_checksum),
        .error_bad_eof(packet_error_bad_eof),
        .error_length_too_large(packet_error_length_too_large),
        .error_malformed(packet_error_malformed)
    );

    uart_frame_buffer_backend #(
        .FRAME_SAMPLES(256),
        .MAX_PAYLOAD_LEN(MAX_PAYLOAD_LEN),
        .PAYLOAD_ADDR_WIDTH(PAYLOAD_ADDR_WIDTH),
        .MAX_CHUNK_SAMPLES(32)
    ) frame_backend_inst (
        .clk(clk),
        .rst(rst),
        .packet_valid(packet_valid),
        .packet_cmd(packet_cmd),
        .packet_seq(packet_seq),
        .packet_payload_len(packet_payload_len),
        .packet_payload_rd_addr(packet_payload_rd_addr),
        .packet_payload_rd_data(packet_payload_rd_data),
        .tx_start(backend_tx_start),
        .tx_cmd(backend_tx_cmd),
        .tx_seq(backend_tx_seq),
        .tx_payload_len(backend_tx_payload_len),
        .tx_payload_rd_addr(backend_tx_payload_rd_addr),
        .tx_payload_rd_data(backend_tx_payload_rd_data),
        .tx_busy(packet_tx_busy),
        .ack_pulse(backend_ack_pulse),
        .error_pulse(backend_error_pulse),
        .frame_loaded(frame_loaded),
        .frame_done(frame_done),
        .bass_gain_q2_14(bass_gain_q2_14),
        .mid_gain_q2_14(mid_gain_q2_14),
        .treble_gain_q2_14(treble_gain_q2_14),
        .status_debug(status_debug),
        .debug_sample_rd_addr(8'd0),
        .debug_input_sample(debug_input_sample),
        .debug_result_sample(debug_result_sample),
        .cpu_wr_en(frame_cpu_wr_en),
        .cpu_rd_en(frame_cpu_rd_en),
        .cpu_addr(frame_cpu_addr),
        .cpu_wdata(frame_cpu_wdata),
        .cpu_rdata(frame_cpu_rdata),
        .cpu_ready(frame_cpu_ready)
    );

    mini_cpu_uart_frame_system cpu_frame_system_inst (
        .clk(clk),
        .rst(rst),
        .frame_cpu_wr_en(frame_cpu_wr_en),
        .frame_cpu_rd_en(frame_cpu_rd_en),
        .frame_cpu_addr(frame_cpu_addr),
        .frame_cpu_wdata(frame_cpu_wdata),
        .frame_cpu_rdata(frame_cpu_rdata),
        .frame_cpu_ready(frame_cpu_ready),
        .gpio_result(gpio_result),
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
        .debug_reg7(debug_reg7),
        .debug_saw_frame_request(debug_saw_frame_request),
        .debug_fft_start_written(debug_fft_start_written),
        .debug_fft_bass_gain_written(debug_fft_bass_gain_written),
        .debug_fft_mid_gain_written(debug_fft_mid_gain_written),
        .debug_fft_treble_gain_written(debug_fft_treble_gain_written),
        .debug_fft_input0_written(debug_fft_input0_written),
        .debug_fft_input1_written(debug_fft_input1_written),
        .debug_fft_input2_written(debug_fft_input2_written),
        .debug_fft_input16_written(debug_fft_input16_written),
        .debug_fft_input64_written(debug_fft_input64_written),
        .debug_fft_input128_written(debug_fft_input128_written),
        .debug_fft_input255_written(debug_fft_input255_written),
        .debug_frame_result0_written(debug_frame_result0_written)
    );

    uart_frame_packet_tx #(
        .MAX_PAYLOAD_LEN(MAX_PAYLOAD_LEN),
        .PAYLOAD_ADDR_WIDTH(PAYLOAD_ADDR_WIDTH)
    ) packet_tx_inst (
        .clk(clk),
        .rst(rst),
        .start(backend_tx_start),
        .cmd(backend_tx_cmd),
        .seq(backend_tx_seq),
        .payload_len(backend_tx_payload_len),
        .payload_rd_addr(backend_tx_payload_rd_addr),
        .payload_rd_data(backend_tx_payload_rd_data),
        .tx_ready(uart_tx_ready),
        .tx_valid(packet_tx_valid),
        .tx_data(packet_tx_data),
        .busy(packet_tx_busy),
        .done(packet_tx_done),
        .error_length_too_large(packet_tx_error_length_too_large)
    );

    uart_tx #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE(BAUD_RATE)
    ) uart_tx_inst (
        .clk(clk),
        .rst(rst),
        .data(uart_tx_byte_buffer),
        .valid(uart_tx_byte_valid),
        .tx(uart_tx),
        .busy(uart_tx_busy)
    );

    always @(posedge clk) begin
        blink_counter <= blink_counter + 1'b1;

        if (rst_cnt < RESET_COUNT_MAX) begin
            rst_cnt <= rst_cnt + 32'd1;
            rst <= 1'b1;
        end else begin
            rst <= 1'b0;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            pass_latched <= 1'b0;
            error_latched <= 1'b0;
            uart_tx_byte_pending <= 1'b0;
            uart_tx_byte_buffer <= 8'd0;
        end else begin
            if (!uart_tx_byte_pending && packet_tx_valid) begin
                uart_tx_byte_buffer <= packet_tx_data;
                uart_tx_byte_pending <= 1'b1;
            end else if (uart_tx_byte_valid) begin
                uart_tx_byte_pending <= 1'b0;
            end

            if (status_done_ok) begin
                pass_latched <= 1'b1;
            end

            if (backend_error_pulse | rx_error | status_error |
                fft_overflow | fft_error) begin
                error_latched <= 1'b1;
                pass_latched <= 1'b0;
            end
        end
    end

endmodule
