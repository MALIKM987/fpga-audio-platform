module audio_tx_top (
    input  wire clk,
    input  wire rst,
    output wire bclk,
    output wire lrck,
    output wire sdata
);

    wire [15:0] sample;

    tone_gen u_tone_gen (
        .clk(clk),
        .rst(rst),
        .sample(sample)
    );

    i2s_tx #(
        .CLK_FREQ_HZ(27_000_000),
        .SAMPLE_RATE_HZ(48_000),
        .SAMPLE_WIDTH(16)
    ) u_i2s_tx (
        .clk(clk),
        .rst(rst),
        .sample_in(sample),
        .bclk(bclk),
        .lrck(lrck),
        .sdata(sdata)
    );

endmodule
