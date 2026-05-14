module tang_audio_top (
    input  wire clk,
    output wire I2S_BCLK,
    output wire I2S_LRCK,
    output wire I2S_DIN,
    output wire PA_SD,
    output wire led
);

    wire [15:0] sample;
    reg  [25:0] cnt = 26'd0;

    always @(posedge clk) begin
        cnt <= cnt + 1'b1;
    end

    assign PA_SD = 1'b1;
    assign led   = cnt[25];   // debug: heartbeat

    tone_gen u_tone_gen (
        .clk(clk),
        .rst(1'b0),
        .sample(sample)
    );

    i2s_tx #(
        .CLK_FREQ_HZ(27_000_000),
        .SAMPLE_RATE_HZ(48_000),
        .SAMPLE_WIDTH(16)
    ) u_i2s_tx (
        .clk(clk),
        .rst(1'b0),
        .sample_in(sample),
        .bclk(I2S_BCLK),
        .lrck(I2S_LRCK),
        .sdata(I2S_DIN)
    );

endmodule