`timescale 1ns/1ps

module uart_frame_packet_mock_backend_tb;

    localparam integer MAX_PAYLOAD_LEN = 32;
    localparam integer PAYLOAD_ADDR_WIDTH = 5;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg rx_valid = 1'b0;
    reg [7:0] rx_data = 8'd0;
    reg tx_ready = 1'b1;

    wire packet_valid;
    wire [7:0] packet_cmd;
    wire [7:0] packet_seq;
    wire [15:0] packet_payload_len;
    wire [PAYLOAD_ADDR_WIDTH-1:0] packet_payload_rd_addr;
    wire [7:0] packet_payload_rd_data;
    wire rx_error_bad_checksum;
    wire rx_error_bad_eof;
    wire rx_error_length_too_large;
    wire rx_error_malformed;

    wire tx_start;
    wire [7:0] tx_cmd;
    wire [7:0] tx_seq;
    wire [15:0] tx_payload_len;
    wire [PAYLOAD_ADDR_WIDTH-1:0] tx_payload_rd_addr;
    wire [7:0] tx_payload_rd_data;
    wire tx_valid;
    wire [7:0] tx_data;
    wire tx_busy;
    wire tx_done;
    wire tx_error_length_too_large;
    wire ack_pulse;
    wire error_pulse;

    reg [7:0] captured [0:63];
    integer captured_count = 0;
    integer errors = 0;
    integer bad_checksum_count = 0;
    integer i;

    uart_frame_packet_rx #(
        .MAX_PAYLOAD_LEN(MAX_PAYLOAD_LEN),
        .PAYLOAD_ADDR_WIDTH(PAYLOAD_ADDR_WIDTH)
    ) rx_inst (
        .clk(clk),
        .rst(rst),
        .rx_valid(rx_valid),
        .rx_data(rx_data),
        .packet_valid(packet_valid),
        .cmd(packet_cmd),
        .seq(packet_seq),
        .payload_len(packet_payload_len),
        .payload_rd_addr(packet_payload_rd_addr),
        .payload_rd_data(packet_payload_rd_data),
        .error_bad_checksum(rx_error_bad_checksum),
        .error_bad_eof(rx_error_bad_eof),
        .error_length_too_large(rx_error_length_too_large),
        .error_malformed(rx_error_malformed)
    );

    uart_frame_mock_backend #(
        .MAX_PAYLOAD_LEN(MAX_PAYLOAD_LEN),
        .PAYLOAD_ADDR_WIDTH(PAYLOAD_ADDR_WIDTH),
        .MAX_CHUNK_SAMPLES(32)
    ) backend_inst (
        .clk(clk),
        .rst(rst),
        .packet_valid(packet_valid),
        .packet_cmd(packet_cmd),
        .packet_seq(packet_seq),
        .packet_payload_len(packet_payload_len),
        .packet_payload_rd_addr(packet_payload_rd_addr),
        .packet_payload_rd_data(packet_payload_rd_data),
        .tx_start(tx_start),
        .tx_cmd(tx_cmd),
        .tx_seq(tx_seq),
        .tx_payload_len(tx_payload_len),
        .tx_payload_rd_addr(tx_payload_rd_addr),
        .tx_payload_rd_data(tx_payload_rd_data),
        .tx_busy(tx_busy),
        .ack_pulse(ack_pulse),
        .error_pulse(error_pulse)
    );

    uart_frame_packet_tx #(
        .MAX_PAYLOAD_LEN(MAX_PAYLOAD_LEN),
        .PAYLOAD_ADDR_WIDTH(PAYLOAD_ADDR_WIDTH)
    ) tx_inst (
        .clk(clk),
        .rst(rst),
        .start(tx_start),
        .cmd(tx_cmd),
        .seq(tx_seq),
        .payload_len(tx_payload_len),
        .payload_rd_addr(tx_payload_rd_addr),
        .payload_rd_data(tx_payload_rd_data),
        .tx_ready(tx_ready),
        .tx_valid(tx_valid),
        .tx_data(tx_data),
        .busy(tx_busy),
        .done(tx_done),
        .error_length_too_large(tx_error_length_too_large)
    );

    always #5 clk = ~clk;

    task report_result;
        input [8*64-1:0] name;
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

    task reset_system;
        begin
            @(negedge clk);
            rst = 1'b1;
            rx_valid = 1'b0;
            rx_data = 8'd0;
            captured_count = 0;
            bad_checksum_count = 0;
            repeat (4) @(negedge clk);
            rst = 1'b0;
            repeat (2) @(negedge clk);
        end
    endtask

    task send_byte;
        input [7:0] value;
        begin
            @(negedge clk);
            rx_data = value;
            rx_valid = 1'b1;
            @(negedge clk);
            rx_valid = 1'b0;
            rx_data = 8'd0;
        end
    endtask

    task wait_cycles;
        input integer cycles;
        begin
            for (i = 0; i < cycles; i = i + 1) begin
                @(posedge clk);
            end
        end
    endtask

    always @(posedge clk) begin
        #1;
        if (tx_valid) begin
            captured[captured_count] = tx_data;
            captured_count = captured_count + 1;
        end

        if (rx_error_bad_checksum) begin
            bad_checksum_count = bad_checksum_count + 1;
        end
    end

    initial begin
        $display("=== UART FRAME PACKET MOCK BACKEND TEST ===");
        $display("MODE=MOCK_BACKEND_ONLY");
        $display("");

        reset_system();
        send_byte(8'hA5);
        send_byte(8'h10);
        send_byte(8'h01);
        send_byte(8'h00);
        send_byte(8'h00);
        send_byte(8'h11);
        send_byte(8'h5A);
        wait_cycles(20);

        report_result("ping_response_count", captured_count == 7);
        report_result("ping_returns_pong",
                      captured[0] == 8'hA5 &&
                      captured[1] == 8'h90 &&
                      captured[2] == 8'h01 &&
                      captured[3] == 8'h00 &&
                      captured[4] == 8'h00 &&
                      captured[5] == 8'h91 &&
                      captured[6] == 8'h5A);

        reset_system();
        send_byte(8'hA5);
        send_byte(8'h55);
        send_byte(8'h02);
        send_byte(8'h00);
        send_byte(8'h00);
        send_byte(8'h57);
        send_byte(8'h5A);
        wait_cycles(20);

        report_result("unknown_response_count", captured_count == 8);
        report_result("unknown_returns_error",
                      captured[0] == 8'hA5 &&
                      captured[1] == 8'h7F &&
                      captured[2] == 8'h02 &&
                      captured[3] == 8'h01 &&
                      captured[4] == 8'h00 &&
                      captured[5] == 8'h55 &&
                      captured[6] == 8'hD7 &&
                      captured[7] == 8'h5A);

        reset_system();
        send_byte(8'hA5);
        send_byte(8'h12);
        send_byte(8'h03);
        send_byte(8'h07);
        send_byte(8'h00);
        send_byte(8'h10);
        send_byte(8'h00);
        send_byte(8'h02);
        send_byte(8'h01);
        send_byte(8'h00);
        send_byte(8'hFE);
        send_byte(8'hFF);
        send_byte(8'h2C);
        send_byte(8'h5A);
        wait_cycles(30);

        report_result("write_chunk_response_count", captured_count == 8);
        report_result("write_chunk_returns_status",
                      captured[0] == 8'hA5 &&
                      captured[1] == 8'h95 &&
                      captured[2] == 8'h03 &&
                      captured[3] == 8'h01 &&
                      captured[4] == 8'h00 &&
                      captured[5] == 8'h00 &&
                      captured[6] == 8'h99 &&
                      captured[7] == 8'h5A);

        reset_system();
        send_byte(8'hA5);
        send_byte(8'h10);
        send_byte(8'h04);
        send_byte(8'h00);
        send_byte(8'h00);
        send_byte(8'h00);
        send_byte(8'h5A);
        wait_cycles(20);

        report_result("bad_checksum_no_backend_response",
                      captured_count == 0 && bad_checksum_count == 1);

        reset_system();
        send_byte(8'hA5);
        send_byte(8'h01);
        send_byte(8'h5A);
        wait_cycles(20);

        report_result("legacy_packet_not_handled_by_new_backend",
                      captured_count == 0);

        $display("");
        if (errors == 0) begin
            $display("STATUS=PASS");
        end else begin
            $display("STATUS=FAIL errors=%0d", errors);
        end

        $finish;
    end

endmodule
