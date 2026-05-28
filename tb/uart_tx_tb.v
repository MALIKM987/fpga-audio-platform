`timescale 1ns/1ps

module uart_tx_tb;
    reg clk;
    reg rst;
    reg [7:0] data;
    reg valid;
    wire tx;
    wire busy;

    integer fail;
    integer low_seen;
    integer high_seen_after_start;
    integer i;

    uart_tx #(
        .CLK_FREQ_HZ(1000),
        .BAUD_RATE(100)
    ) dut (
        .clk(clk),
        .rst(rst),
        .data(data),
        .valid(valid),
        .tx(tx),
        .busy(busy)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst = 1'b1;
        data = 8'h55;
        valid = 1'b0;
        fail = 0;
        low_seen = 0;
        high_seen_after_start = 0;

        repeat (4) @(posedge clk);
        rst = 1'b0;

        @(negedge clk);
        valid = 1'b1;
        @(negedge clk);
        valid = 1'b0;

        repeat (5) @(posedge clk);
        if (!busy) begin
            $display("FAIL: uart_tx did not become busy");
            fail = 1;
        end

        for (i = 0; i < 150; i = i + 1) begin
            @(posedge clk);
            #1;
            if (tx == 1'b0) low_seen = 1;
            if (low_seen && tx == 1'b1) high_seen_after_start = 1;
        end

        if (busy || tx != 1'b1 || !low_seen || !high_seen_after_start) begin
            $display("FAIL: uart_tx did not complete a visible 8N1 frame");
            fail = 1;
        end

        if (fail) begin
            $display("uart_tx_tb FAIL");
        end else begin
            $display("uart_tx_tb PASS");
        end
        $finish;
    end
endmodule
