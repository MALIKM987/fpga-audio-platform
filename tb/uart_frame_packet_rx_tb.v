`timescale 1ns/1ps

module uart_frame_packet_rx_tb;

    localparam integer MAX_PAYLOAD_LEN = 16;
    localparam integer PAYLOAD_ADDR_WIDTH = 4;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg rx_valid = 1'b0;
    reg [7:0] rx_data = 8'd0;
    reg [PAYLOAD_ADDR_WIDTH-1:0] payload_rd_addr = 4'd0;

    wire packet_valid;
    wire [7:0] cmd;
    wire [7:0] seq;
    wire [15:0] payload_len;
    wire [7:0] payload_rd_data;
    wire error_bad_checksum;
    wire error_bad_eof;
    wire error_length_too_large;
    wire error_malformed;

    integer errors = 0;
    integer packet_count = 0;
    integer bad_checksum_count = 0;
    integer bad_eof_count = 0;
    integer length_error_count = 0;
    integer malformed_count = 0;
    reg [7:0] captured_cmd = 8'd0;
    reg [7:0] captured_seq = 8'd0;
    reg [15:0] captured_len = 16'd0;

    uart_frame_packet_rx #(
        .MAX_PAYLOAD_LEN(MAX_PAYLOAD_LEN),
        .PAYLOAD_ADDR_WIDTH(PAYLOAD_ADDR_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .rx_valid(rx_valid),
        .rx_data(rx_data),
        .packet_valid(packet_valid),
        .cmd(cmd),
        .seq(seq),
        .payload_len(payload_len),
        .payload_rd_addr(payload_rd_addr),
        .payload_rd_data(payload_rd_data),
        .error_bad_checksum(error_bad_checksum),
        .error_bad_eof(error_bad_eof),
        .error_length_too_large(error_length_too_large),
        .error_malformed(error_malformed)
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

    task reset_counters;
        begin
            packet_count = 0;
            bad_checksum_count = 0;
            bad_eof_count = 0;
            length_error_count = 0;
            malformed_count = 0;
        end
    endtask

    task pulse_reset;
        begin
            @(negedge clk);
            rst = 1'b1;
            rx_valid = 1'b0;
            repeat (3) @(negedge clk);
            rst = 1'b0;
            repeat (2) @(negedge clk);
            reset_counters();
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

    always @(posedge clk) begin
        #1;
        if (packet_valid) begin
            packet_count = packet_count + 1;
            captured_cmd = cmd;
            captured_seq = seq;
            captured_len = payload_len;
        end

        if (error_bad_checksum) begin
            bad_checksum_count = bad_checksum_count + 1;
        end

        if (error_bad_eof) begin
            bad_eof_count = bad_eof_count + 1;
        end

        if (error_length_too_large) begin
            length_error_count = length_error_count + 1;
        end

        if (error_malformed) begin
            malformed_count = malformed_count + 1;
        end
    end

    initial begin
        $display("=== UART FRAME PACKET RX TEST ===");
        $display("FORMAT=SOF CMD SEQ LEN_L LEN_H PAYLOAD CHK EOF");
        $display("");

        pulse_reset();
        report_result("reset", packet_valid === 1'b0);

        send_byte(8'hA5);
        send_byte(8'h10);
        send_byte(8'h02);
        send_byte(8'h00);
        send_byte(8'h00);
        send_byte(8'h12);
        send_byte(8'h5A);
        repeat (2) @(posedge clk);

        report_result("valid_ping_decoded", packet_count == 1);
        report_result("valid_ping_fields",
                      captured_cmd == 8'h10 &&
                      captured_seq == 8'h02 &&
                      captured_len == 16'd0);

        pulse_reset();
        send_byte(8'hA5);
        send_byte(8'h12);
        send_byte(8'h09);
        send_byte(8'h06);
        send_byte(8'h00);
        send_byte(8'hA5);
        send_byte(8'h5A);
        send_byte(8'h00);
        send_byte(8'hFF);
        send_byte(8'hA5);
        send_byte(8'h5A);
        send_byte(8'h1E);
        send_byte(8'h5A);
        repeat (2) @(posedge clk);

        payload_rd_addr = 4'd0;
        #1;
        report_result("payload_byte_a5", payload_rd_data == 8'hA5);
        payload_rd_addr = 4'd1;
        #1;
        report_result("payload_byte_5a", payload_rd_data == 8'h5A);
        report_result("payload_packet_fields",
                      packet_count == 1 &&
                      captured_cmd == 8'h12 &&
                      captured_seq == 8'h09 &&
                      captured_len == 16'd6);

        pulse_reset();
        send_byte(8'hA5);
        send_byte(8'h10);
        send_byte(8'h03);
        send_byte(8'h00);
        send_byte(8'h00);
        send_byte(8'h00);
        send_byte(8'h5A);
        repeat (2) @(posedge clk);
        report_result("bad_checksum_rejected",
                      packet_count == 0 && bad_checksum_count == 1);

        pulse_reset();
        send_byte(8'hA5);
        send_byte(8'h10);
        send_byte(8'h04);
        send_byte(8'h00);
        send_byte(8'h00);
        send_byte(8'h14);
        send_byte(8'h00);
        repeat (2) @(posedge clk);
        report_result("bad_eof_rejected", packet_count == 0 && bad_eof_count == 1);

        pulse_reset();
        send_byte(8'hA5);
        send_byte(8'h10);
        send_byte(8'h05);
        send_byte(8'h11);
        send_byte(8'h00);
        repeat (2) @(posedge clk);
        report_result("length_too_large_rejected",
                      packet_count == 0 && length_error_count == 1);

        pulse_reset();
        send_byte(8'h00);
        repeat (2) @(posedge clk);
        report_result("malformed_non_sof_recovery",
                      packet_count == 0 && malformed_count == 1);

        $display("");
        if (errors == 0) begin
            $display("STATUS=PASS");
        end else begin
            $display("STATUS=FAIL errors=%0d", errors);
        end

        $finish;
    end

endmodule
