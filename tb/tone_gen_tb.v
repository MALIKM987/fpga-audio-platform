	imescale 1ns/1ps

module tone_gen_tb;

    reg clk = 1'b0;
    reg rst = 1'b1;
    wire [15:0] sample;

    tone_gen dut (
        .clk(clk),
        .rst(rst),
        .sample(sample)
    );

    always #10 clk = ~clk;

    initial begin
        #100;
        rst = 1'b0;

        #2000;
        $finish;
    end

endmodule
