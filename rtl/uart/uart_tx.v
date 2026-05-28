module uart_tx #(
    parameter integer CLK_FREQ_HZ = 27_000_000,
    parameter integer BAUD_RATE   = 115_200
)(
    input  wire clk,
    input  wire rst,
    input  wire [7:0] data,
    input  wire valid,
    output reg  tx,
    output reg  busy
);

    localparam integer CLKS_PER_BIT = (CLK_FREQ_HZ / BAUD_RATE) > 0 ?
                                      (CLK_FREQ_HZ / BAUD_RATE) : 1;

    reg [31:0] baud_cnt;
    reg [3:0]  bit_index;
    reg [7:0]  data_reg;

    always @(posedge clk) begin
        if (rst) begin
            tx        <= 1'b1;
            busy      <= 1'b0;
            baud_cnt  <= 32'd0;
            bit_index <= 4'd0;
            data_reg  <= 8'd0;
        end else begin
            if (!busy) begin
                tx        <= 1'b1;
                baud_cnt  <= 32'd0;
                bit_index <= 4'd0;

                if (valid) begin
                    busy     <= 1'b1;
                    data_reg <= data;
                    tx       <= 1'b0;
                end
            end else begin
                if (baud_cnt == CLKS_PER_BIT - 1) begin
                    baud_cnt <= 32'd0;

                    if (bit_index < 4'd8) begin
                        tx        <= data_reg[bit_index];
                        bit_index <= bit_index + 4'd1;
                    end else if (bit_index == 4'd8) begin
                        tx        <= 1'b1;
                        bit_index <= 4'd9;
                    end else begin
                        tx        <= 1'b1;
                        busy      <= 1'b0;
                        bit_index <= 4'd0;
                    end
                end else begin
                    baud_cnt <= baud_cnt + 32'd1;
                end
            end
        end
    end

endmodule
