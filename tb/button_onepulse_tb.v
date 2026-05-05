`timescale 1ns/1ps

// Sanity test for button_onepulse:
// checks debounce plus a single-cycle press pulse for each stable press.
module button_onepulse_tb;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg button_raw = 1'b0;

    wire pulse;

    integer pulse_count;
    integer errors;

    button_onepulse #(
        .CLK_HZ(1000),
        .DEBOUNCE_MS(2),
        .BUTTON_ACTIVE_LEVEL(1'b1)
    ) dut (
        .clk(clk),
        .rst(rst),
        .button_raw(button_raw),
        .pulse(pulse)
    );

    always #1 clk = ~clk;

    always @(posedge clk) begin
        if (pulse)
            pulse_count = pulse_count + 1;
    end

    task expect_count;
        input integer expected;
        input [255:0] message;
        begin
            if (pulse_count !== expected) begin
                $display("FAIL: %0s actual=%0d expected=%0d", message, pulse_count, expected);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        pulse_count = 0;
        errors = 0;

        repeat (4) @(negedge clk);
        rst = 1'b0;
        repeat (4) @(negedge clk);

        button_raw = 1'b1;
        repeat (1) @(negedge clk);
        button_raw = 1'b0;
        repeat (1) @(negedge clk);
        button_raw = 1'b1;
        repeat (1) @(negedge clk);
        button_raw = 1'b0;
        repeat (1) @(negedge clk);
        expect_count(0, "bounce before debounce does not create a pulse");

        button_raw = 1'b1;
        repeat (10) @(negedge clk);
        expect_count(1, "stable press creates exactly one pulse");

        repeat (20) @(negedge clk);
        expect_count(1, "held button does not create multiple pulses");

        button_raw = 1'b0;
        repeat (10) @(negedge clk);
        expect_count(1, "release does not create a press pulse");

        button_raw = 1'b1;
        repeat (10) @(negedge clk);
        expect_count(2, "second stable press creates one additional pulse");

        if (errors == 0)
            $display("PASS: button_onepulse_tb");
        else
            $display("FAIL: button_onepulse_tb errors=%0d", errors);

        $finish;
    end

endmodule
