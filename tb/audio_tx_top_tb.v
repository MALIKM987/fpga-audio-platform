`timescale 1ns/1ps

module audio_tx_top_tb;

    reg clk = 1'b0;
    reg rst = 1'b1;

    wire bclk;
    wire lrck;
    wire sdata;

    audio_tx_top dut (
        .clk(clk),
        .rst(rst),
        .bclk(bclk),
        .lrck(lrck),
        .sdata(sdata)
    );

    always #18.5 clk = ~clk; // ~27 MHz

    initial begin
        #200;
        rst = 1'b0;

        #2000000;
        ;
    end

endmodule
