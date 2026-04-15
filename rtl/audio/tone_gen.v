module tone_gen (
    input  wire        clk,
    input  wire        rst,
    output reg  [15:0] sample
);

    reg [31:0] phase_acc;

    always @(posedge clk) begin
        if (rst) begin
            phase_acc <= 32'd0;
            sample    <= 16'd0;
        end else begin
            phase_acc <= phase_acc + 32'd100000;
            sample    <= phase_acc[31:16];
        end
    end

endmodule
