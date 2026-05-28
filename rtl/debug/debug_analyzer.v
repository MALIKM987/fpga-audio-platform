module debug_analyzer #(
    parameter integer WINDOW_SAMPLES = 1024
)(
    input  wire clk,
    input  wire rst,
    input  wire signed [15:0] sample_in,
    input  wire signed [15:0] sample_out,
    input  wire sample_valid,
    input  wire clip,
    output reg  signed [15:0] in_min,
    output reg  signed [15:0] in_max,
    output reg  signed [15:0] out_min,
    output reg  signed [15:0] out_max,
    output reg  clip_seen,
    output reg  report_valid
);

    reg [31:0] sample_count;
    reg signed [15:0] cur_in_min;
    reg signed [15:0] cur_in_max;
    reg signed [15:0] cur_out_min;
    reg signed [15:0] cur_out_max;
    reg cur_clip_seen;

    wire signed [15:0] next_in_min;
    wire signed [15:0] next_in_max;
    wire signed [15:0] next_out_min;
    wire signed [15:0] next_out_max;
    wire next_clip_seen;

    assign next_in_min    = (sample_in < cur_in_min) ? sample_in : cur_in_min;
    assign next_in_max    = (sample_in > cur_in_max) ? sample_in : cur_in_max;
    assign next_out_min   = (sample_out < cur_out_min) ? sample_out : cur_out_min;
    assign next_out_max   = (sample_out > cur_out_max) ? sample_out : cur_out_max;
    assign next_clip_seen = cur_clip_seen | clip;

    always @(posedge clk) begin
        if (rst) begin
            sample_count  <= 32'd0;
            cur_in_min    <= 16'sd32767;
            cur_in_max    <= 16'sh8000;
            cur_out_min   <= 16'sd32767;
            cur_out_max   <= 16'sh8000;
            cur_clip_seen <= 1'b0;
            in_min        <= 16'sd0;
            in_max        <= 16'sd0;
            out_min       <= 16'sd0;
            out_max       <= 16'sd0;
            clip_seen     <= 1'b0;
            report_valid  <= 1'b0;
        end else begin
            report_valid <= 1'b0;

            if (sample_valid) begin
                if (sample_count == WINDOW_SAMPLES - 1) begin
                    in_min        <= next_in_min;
                    in_max        <= next_in_max;
                    out_min       <= next_out_min;
                    out_max       <= next_out_max;
                    clip_seen     <= next_clip_seen;
                    report_valid  <= 1'b1;
                    sample_count  <= 32'd0;
                    cur_in_min    <= 16'sd32767;
                    cur_in_max    <= 16'sh8000;
                    cur_out_min   <= 16'sd32767;
                    cur_out_max   <= 16'sh8000;
                    cur_clip_seen <= 1'b0;
                end else begin
                    cur_in_min    <= next_in_min;
                    cur_in_max    <= next_in_max;
                    cur_out_min   <= next_out_min;
                    cur_out_max   <= next_out_max;
                    cur_clip_seen <= next_clip_seen;
                    sample_count  <= sample_count + 32'd1;
                end
            end
        end
    end

endmodule
