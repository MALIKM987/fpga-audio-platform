`timescale 1ns/1ps

module uart_frame_packet_tx_tb;

    localparam integer MAX_PAYLOAD_LEN = 16;
    localparam integer PAYLOAD_ADDR_WIDTH = 4;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg start = 1'b0;
    reg [7:0] cmd = 8'h12;
    reg [7:0] seq = 8'h09;
    reg [15:0] payload_len = 16'd4;
    reg tx_ready = 1'b1;

    wire [PAYLOAD_ADDR_WIDTH-1:0] payload_rd_addr;
    wire [7:0] payload_rd_data;
    wire tx_valid;
    wire [7:0] tx_data;
    wire busy;
    wire done;
    wire error_length_too_large;

    reg [7:0] payload_mem [0:MAX_PAYLOAD_LEN-1];
    reg [7:0] captured [0:31];
    integer captured_count = 0;
    integer errors = 0;
    integer i;
    integer length_error_count = 0;

    assign payload_rd_data = payload_mem[payload_rd_addr];

    uart_frame_packet_tx #(
        .MAX_PAYLOAD_LEN(MAX_PAYLOAD_LEN),
        .PAYLOAD_ADDR_WIDTH(PAYLOAD_ADDR_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .cmd(cmd),
        .seq(seq),
        .payload_len(payload_len),
        .payload_rd_addr(payload_rd_addr),
        .payload_rd_data(payload_rd_data),
        .tx_ready(tx_ready),
        .tx_valid(tx_valid),
        .tx_data(tx_data),
        .busy(busy),
        .done(done),
        .error_length_too_large(error_length_too_large)
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

    task pulse_start;
        begin
            @(negedge clk);
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;
        end
    endtask

    always @(posedge clk) begin
        #1;
        if (tx_valid) begin
            captured[captured_count] = tx_data;
            captured_count = captured_count + 1;
        end

        if (error_length_too_large) begin
            length_error_count = length_error_count + 1;
        end
    end

    initial begin
        $display("=== UART FRAME PACKET TX TEST ===");
        $display("FORMAT=SOF CMD SEQ LEN_L LEN_H PAYLOAD CHK EOF");
        $display("");

        payload_mem[0] = 8'hA5;
        payload_mem[1] = 8'h5A;
        payload_mem[2] = 8'h00;
        payload_mem[3] = 8'hFF;

        repeat (4) @(posedge clk);
        report_result("reset", busy === 1'b0 && tx_valid === 1'b0);

        @(negedge clk);
        rst = 1'b0;

        pulse_start();
        wait (done == 1'b1);
        repeat (2) @(posedge clk);

        report_result("byte_count", captured_count == 11);
        report_result("packet_sof_eof",
                      captured[0] == 8'hA5 && captured[10] == 8'h5A);
        report_result("packet_header",
                      captured[1] == 8'h12 &&
                      captured[2] == 8'h09 &&
                      captured[3] == 8'h04 &&
                      captured[4] == 8'h00);
        report_result("payload_bytes_preserved",
                      captured[5] == 8'hA5 &&
                      captured[6] == 8'h5A &&
                      captured[7] == 8'h00 &&
                      captured[8] == 8'hFF);
        report_result("checksum", captured[9] == 8'h1D);
        report_result("done_and_idle", done === 1'b0 && busy === 1'b0);

        captured_count = 0;
        payload_len = 16'd17;
        pulse_start();
        repeat (4) @(posedge clk);
        report_result("length_too_large_rejected",
                      captured_count == 0 && length_error_count == 1);

        $display("");
        if (errors == 0) begin
            $display("STATUS=PASS");
        end else begin
            $display("STATUS=FAIL errors=%0d", errors);
        end

        $finish;
    end

endmodule
