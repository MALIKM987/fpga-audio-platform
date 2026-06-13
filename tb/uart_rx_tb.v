`timescale 1ns/1ps

module uart_rx_tb;

    localparam integer CLK_FREQ_HZ = 1_000_000;
    localparam integer BAUD_RATE = 100_000;
    localparam integer CLKS_PER_BIT = CLK_FREQ_HZ / BAUD_RATE;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg rx = 1'b1;
    wire [7:0] data;
    wire valid;
    wire frame_error;

    integer errors = 0;
    integer i;
    integer valid_count = 0;
    reg [7:0] captured_data = 8'd0;

    uart_rx #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE(BAUD_RATE)
    ) dut (
        .clk(clk),
        .rst(rst),
        .rx(rx),
        .data(data),
        .valid(valid),
        .frame_error(frame_error)
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

    task send_rx_byte;
        input [7:0] byte_value;
        begin
            @(negedge clk);
            rx = 1'b0;
            repeat (CLKS_PER_BIT) @(posedge clk);

            for (i = 0; i < 8; i = i + 1) begin
                rx = byte_value[i];
                repeat (CLKS_PER_BIT) @(posedge clk);
            end

            rx = 1'b1;
            repeat (CLKS_PER_BIT * 2) @(posedge clk);
        end
    endtask

    always @(posedge clk) begin
        #1;
        if (valid) begin
            valid_count = valid_count + 1;
            captured_data = data;
        end
    end

    initial begin
        $display("=== UART RX TEST ===");
        $display("FORMAT=8N1");
        $display("");

        repeat (4) @(posedge clk);
        report_result("reset", (valid === 1'b0) && (frame_error === 1'b0));

        @(negedge clk);
        rst = 1'b0;

        send_rx_byte(8'h3C);

        report_result("valid_pulse", valid_count == 1);
        report_result("data_output", captured_data === 8'h3C);
        report_result("no_frame_error", frame_error === 1'b0);

        $display("");
        if (errors == 0) begin
            $display("STATUS=PASS");
        end else begin
            $display("STATUS=FAIL errors=%0d", errors);
        end

        $finish;
    end

endmodule
