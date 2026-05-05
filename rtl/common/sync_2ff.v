module sync_2ff #(
    parameter RESET_VALUE = 1'b0
)(
    input  wire clk,
    input  wire rst,
    input  wire async_in,
    output reg  sync_out
);

    reg sync_meta;

    always @(posedge clk) begin
        if (rst) begin
            sync_meta <= RESET_VALUE;
            sync_out  <= RESET_VALUE;
        end else begin
            sync_meta <= async_in;
            sync_out  <= sync_meta;
        end
    end

endmodule
