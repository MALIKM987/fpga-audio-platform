module i2s_tx #(
    parameter integer CLK_FREQ_HZ    = 27_000_000,
    parameter integer SAMPLE_RATE_HZ = 48_000,
    parameter integer SAMPLE_WIDTH   = 16
)(
    input  wire                         clk,
    input  wire                         rst,
    input  wire signed [SAMPLE_WIDTH-1:0] sample_in,

    output reg                          bclk,
    output reg                          lrck,
    output reg                          sdata
);

    localparam integer BCLK_FREQ_HZ = SAMPLE_RATE_HZ * SAMPLE_WIDTH * 2;
    localparam integer BCLK_DIV     = CLK_FREQ_HZ / (BCLK_FREQ_HZ * 2);

    reg [31:0] bclk_div_cnt;
    reg [5:0]  bit_cnt;
    reg signed [SAMPLE_WIDTH-1:0] shreg;

    always @(posedge clk) begin
        if (rst) begin
            bclk         <= 1'b0;
            lrck         <= 1'b0;
            sdata        <= 1'b0;
            bclk_div_cnt <= 32'd0;
            bit_cnt      <= 6'd0;
            shreg        <= {SAMPLE_WIDTH{1'b0}};
        end else begin
            if (bclk_div_cnt == BCLK_DIV-1) begin
                bclk_div_cnt <= 32'd0;
                bclk <= ~bclk;

                if (bclk == 1'b0) begin
                    if (bit_cnt == 0) begin
                        shreg <= sample_in;
                        sdata <= sample_in[SAMPLE_WIDTH-1];
                        bit_cnt <= bit_cnt + 1'b1;
                    end else if (bit_cnt < SAMPLE_WIDTH) begin
                        shreg <= {shreg[SAMPLE_WIDTH-2:0], 1'b0};
                        sdata <= shreg[SAMPLE_WIDTH-2];
                        bit_cnt <= bit_cnt + 1'b1;
                    end else if (bit_cnt == SAMPLE_WIDTH) begin
                        lrck <= ~lrck;
                        shreg <= sample_in;
                        sdata <= sample_in[SAMPLE_WIDTH-1];
                        bit_cnt <= 6'd1;
                    end
                end
            end else begin
                bclk_div_cnt <= bclk_div_cnt + 1'b1;
            end
        end
    end

endmodule
