module debounce #(
    parameter integer CLK_HZ      = 27000000,
    parameter integer DEBOUNCE_MS = 20
)(
    input  wire clk,
    input  wire rst,
    input  wire noisy_in,
    output reg  clean_out
);

    function integer clog2;
        input integer value;
        integer tmp;
        begin
            tmp = value - 1;
            for (clog2 = 0; tmp > 0; clog2 = clog2 + 1)
                tmp = tmp >> 1;

            if (clog2 == 0)
                clog2 = 1;
        end
    endfunction

    localparam integer RAW_DEBOUNCE_CYCLES = (CLK_HZ / 1000) * DEBOUNCE_MS;
    localparam integer DEBOUNCE_CYCLES     = (RAW_DEBOUNCE_CYCLES < 1) ? 1 : RAW_DEBOUNCE_CYCLES;
    localparam integer COUNT_WIDTH         = clog2(DEBOUNCE_CYCLES + 1);

    reg [COUNT_WIDTH-1:0] debounce_count;

    always @(posedge clk) begin
        if (rst) begin
            clean_out      <= 1'b0;
            debounce_count <= {COUNT_WIDTH{1'b0}};
        end else begin
            if (noisy_in == clean_out) begin
                debounce_count <= {COUNT_WIDTH{1'b0}};
            end else if (debounce_count == DEBOUNCE_CYCLES - 1) begin
                clean_out      <= noisy_in;
                debounce_count <= {COUNT_WIDTH{1'b0}};
            end else begin
                debounce_count <= debounce_count + 1'b1;
            end
        end
    end

endmodule
