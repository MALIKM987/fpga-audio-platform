module button_onepulse #(
    parameter integer CLK_HZ              = 27000000,
    parameter integer DEBOUNCE_MS         = 20,
    parameter         BUTTON_ACTIVE_LEVEL = 1'b1
)(
    input  wire clk,
    input  wire rst,
    input  wire button_raw,
    output wire pulse
);

    wire button_sync_raw;
    wire button_pressed;
    wire button_clean;
    reg  button_clean_d;

    sync_2ff #(
        .RESET_VALUE(~BUTTON_ACTIVE_LEVEL)
    ) u_sync_2ff (
        .clk(clk),
        .rst(rst),
        .async_in(button_raw),
        .sync_out(button_sync_raw)
    );

    assign button_pressed = (button_sync_raw == BUTTON_ACTIVE_LEVEL) ? 1'b1 : 1'b0;

    debounce #(
        .CLK_HZ(CLK_HZ),
        .DEBOUNCE_MS(DEBOUNCE_MS)
    ) u_debounce (
        .clk(clk),
        .rst(rst),
        .noisy_in(button_pressed),
        .clean_out(button_clean)
    );

    always @(posedge clk) begin
        if (rst)
            button_clean_d <= 1'b0;
        else
            button_clean_d <= button_clean;
    end

    assign pulse = button_clean & ~button_clean_d;

endmodule
