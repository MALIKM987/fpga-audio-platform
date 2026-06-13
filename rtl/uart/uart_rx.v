module uart_rx #(
    parameter integer CLK_FREQ_HZ = 27_000_000,
    parameter integer BAUD_RATE   = 115_200
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       rx,
    output reg  [7:0] data,
    output reg        valid,
    output reg        frame_error
);

    localparam integer CLKS_PER_BIT = (CLK_FREQ_HZ / BAUD_RATE) > 0 ?
                                      (CLK_FREQ_HZ / BAUD_RATE) : 1;
    localparam integer HALF_BIT = CLKS_PER_BIT / 2;

    localparam [1:0] STATE_IDLE  = 2'd0;
    localparam [1:0] STATE_START = 2'd1;
    localparam [1:0] STATE_DATA  = 2'd2;
    localparam [1:0] STATE_STOP  = 2'd3;

    reg [1:0] state = STATE_IDLE;
    reg [31:0] baud_cnt = 32'd0;
    reg [2:0] bit_index = 3'd0;
    reg [7:0] data_reg = 8'd0;

    always @(posedge clk) begin
        if (rst) begin
            state <= STATE_IDLE;
            baud_cnt <= 32'd0;
            bit_index <= 3'd0;
            data_reg <= 8'd0;
            data <= 8'd0;
            valid <= 1'b0;
            frame_error <= 1'b0;
        end else begin
            valid <= 1'b0;
            frame_error <= 1'b0;

            case (state)
                STATE_IDLE: begin
                    baud_cnt <= 32'd0;
                    bit_index <= 3'd0;

                    if (rx == 1'b0) begin
                        baud_cnt <= HALF_BIT;
                        state <= STATE_START;
                    end
                end

                STATE_START: begin
                    if (baud_cnt == 32'd0) begin
                        if (rx == 1'b0) begin
                            baud_cnt <= CLKS_PER_BIT - 1;
                            state <= STATE_DATA;
                        end else begin
                            state <= STATE_IDLE;
                        end
                    end else begin
                        baud_cnt <= baud_cnt - 32'd1;
                    end
                end

                STATE_DATA: begin
                    if (baud_cnt == 32'd0) begin
                        data_reg[bit_index] <= rx;
                        baud_cnt <= CLKS_PER_BIT - 1;

                        if (bit_index == 3'd7) begin
                            state <= STATE_STOP;
                        end else begin
                            bit_index <= bit_index + 3'd1;
                        end
                    end else begin
                        baud_cnt <= baud_cnt - 32'd1;
                    end
                end

                STATE_STOP: begin
                    if (baud_cnt == 32'd0) begin
                        if (rx == 1'b1) begin
                            data <= data_reg;
                            valid <= 1'b1;
                        end else begin
                            frame_error <= 1'b1;
                        end

                        state <= STATE_IDLE;
                    end else begin
                        baud_cnt <= baud_cnt - 32'd1;
                    end
                end

                default: begin
                    state <= STATE_IDLE;
                end
            endcase
        end
    end

endmodule
