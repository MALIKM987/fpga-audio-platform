`timescale 1ns/1ps

module uart_tx_tb;

    localparam integer CLK_FREQ_HZ = 1_000_000;
    localparam integer BAUD_RATE = 100_000;
    localparam integer CLKS_PER_BIT = CLK_FREQ_HZ / BAUD_RATE;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg [7:0] data = 8'hA6;
    reg valid = 1'b0;
    wire tx;
    wire busy;

    integer errors = 0;
    integer i;
    reg [7:0] received_byte;
    reg stop_bit;
    integer busy_seen = 0;

    uart_tx #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE(BAUD_RATE)
    ) dut (
        .clk(clk),
        .rst(rst),
        .data(data),
        .valid(valid),
        .tx(tx),
        .busy(busy)
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

    task receive_tx_byte;
        output [7:0] byte_value;
        output stop_value;
        begin
            wait (tx == 1'b0);
            repeat (CLKS_PER_BIT + (CLKS_PER_BIT / 2)) @(posedge clk);

            for (i = 0; i < 8; i = i + 1) begin
                byte_value[i] = tx;
                repeat (CLKS_PER_BIT) @(posedge clk);
            end

            stop_value = tx;
            repeat (CLKS_PER_BIT) @(posedge clk);
        end
    endtask

    initial begin
        $display("=== UART TX TEST ===");
        $display("FORMAT=8N1");
        $display("");

        repeat (4) @(posedge clk);
        report_result("reset_idle_high", (tx === 1'b1) && (busy === 1'b0));

        @(negedge clk);
        rst = 1'b0;
        valid = 1'b1;

        @(negedge clk);
        valid = 1'b0;

        fork
            begin
                receive_tx_byte(received_byte, stop_bit);
            end

            begin
                repeat (CLKS_PER_BIT * 12) begin
                    @(posedge clk);
                    #1;
                    if (busy) begin
                        busy_seen = 1;
                    end
                end
            end
        join

        report_result("start_and_data_bits", received_byte === 8'hA6);
        report_result("stop_bit_high", stop_bit === 1'b1);
        report_result("busy_asserted", busy_seen == 1);

        repeat (CLKS_PER_BIT * 2) @(posedge clk);
        #1;
        report_result("returns_idle", (tx === 1'b1) && (busy === 1'b0));

        $display("");
        if (errors == 0) begin
            $display("STATUS=PASS");
        end else begin
            $display("STATUS=FAIL errors=%0d", errors);
        end

        $finish;
    end

endmodule
