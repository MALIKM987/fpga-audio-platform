module tang_fft_ifft_selftest_top #(
    parameter integer FFT_SIZE            = 256,
    parameter integer SAMPLE_WIDTH        = 16,
    parameter integer GAIN_WIDTH          = 16,
    parameter integer INDEX_WIDTH         = 8,
    parameter integer RESET_COUNT_MAX     = 65535,
    parameter integer BLINK_COUNTER_WIDTH = 24,
    parameter integer TIMEOUT_MAX         = 200000
) (
    input  wire clk,
    output wire led
);

    localparam signed [SAMPLE_WIDTH-1:0] IMPULSE_SAMPLE = 16'sd64;
    localparam signed [GAIN_WIDTH-1:0]   UNITY_GAIN     = 16'sd16384;

    localparam [2:0] STATE_RESET_WAIT = 3'd0;
    localparam [2:0] STATE_FEED_FRAME = 3'd1;
    localparam [2:0] STATE_WAIT_DONE  = 3'd2;
    localparam [2:0] STATE_PASS       = 3'd3;
    localparam [2:0] STATE_FAIL       = 3'd4;

    localparam [6:0] CHECK_MASK_ALL = 7'b1111111;

    localparam integer FAST_BLINK_BIT = (BLINK_COUNTER_WIDTH > 3) ?
                                        (BLINK_COUNTER_WIDTH - 3) : 0;
    localparam integer SLOW_BLINK_BIT = BLINK_COUNTER_WIDTH - 1;

    reg [31:0] rst_cnt = 32'd0;
    reg rst = 1'b1;

    reg [BLINK_COUNTER_WIDTH-1:0] blink_counter =
        {BLINK_COUNTER_WIDTH{1'b0}};

    reg [2:0] state = STATE_RESET_WAIT;
    reg sample_valid = 1'b0;
    reg signed [SAMPLE_WIDTH-1:0] sample_in = {SAMPLE_WIDTH{1'b0}};
    reg [INDEX_WIDTH-1:0] feed_index = {INDEX_WIDTH{1'b0}};
    reg [31:0] timeout_counter = 32'd0;

    reg pass_latched = 1'b0;
    reg fail_latched = 1'b0;
    reg overflow_latched = 1'b0;
    reg timeout_latched = 1'b0;
    reg [6:0] check_mask = 7'd0;
    reg [INDEX_WIDTH:0] observed_output_count = {(INDEX_WIDTH + 1){1'b0}};

    wire out_valid;
    wire [INDEX_WIDTH-1:0] out_index;
    wire signed [SAMPLE_WIDTH-1:0] sample_out;
    wire busy;
    wire done;
    wire overflow;

    wire fast_blink;
    wire slow_blink;

    assign fast_blink = blink_counter[FAST_BLINK_BIT];
    assign slow_blink = blink_counter[SLOW_BLINK_BIT];

    assign led = pass_latched ? 1'b1 :
                 fail_latched ? slow_blink :
                 fast_blink;

    fft_ifft_pipeline #(
        .FFT_SIZE(FFT_SIZE),
        .SAMPLE_WIDTH(SAMPLE_WIDTH),
        .GAIN_WIDTH(GAIN_WIDTH),
        .INDEX_WIDTH(INDEX_WIDTH),
        .AUTO_START(1)
    ) pipeline_inst (
        .clk(clk),
        .rst(rst),
        .sample_valid(sample_valid),
        .sample_in(sample_in),
        .bass_gain(UNITY_GAIN),
        .mid_gain(UNITY_GAIN),
        .treble_gain(UNITY_GAIN),
        .start_process(1'b0),
        .out_valid(out_valid),
        .out_index(out_index),
        .sample_out(sample_out),
        .busy(busy),
        .done(done),
        .overflow(overflow)
    );

    function signed [SAMPLE_WIDTH-1:0] expected_sample;
        input [INDEX_WIDTH-1:0] index;
        begin
            if (index == {INDEX_WIDTH{1'b0}}) begin
                expected_sample = IMPULSE_SAMPLE;
            end else begin
                expected_sample = {SAMPLE_WIDTH{1'b0}};
            end
        end
    endfunction

    function within_tolerance;
        input signed [SAMPLE_WIDTH-1:0] actual;
        input signed [SAMPLE_WIDTH-1:0] expected;
        reg signed [SAMPLE_WIDTH:0] diff;
        begin
            diff = {actual[SAMPLE_WIDTH-1], actual} -
                   {expected[SAMPLE_WIDTH-1], expected};
            within_tolerance = (diff <= 17'sd2) && (diff >= -17'sd2);
        end
    endfunction

    function [6:0] checked_index_mask;
        input [INDEX_WIDTH-1:0] index;
        begin
            case (index)
                8'd0:   checked_index_mask = 7'b0000001;
                8'd1:   checked_index_mask = 7'b0000010;
                8'd2:   checked_index_mask = 7'b0000100;
                8'd16:  checked_index_mask = 7'b0001000;
                8'd64:  checked_index_mask = 7'b0010000;
                8'd128: checked_index_mask = 7'b0100000;
                8'd255: checked_index_mask = 7'b1000000;
                default: checked_index_mask = 7'b0000000;
            endcase
        end
    endfunction

    always @(posedge clk) begin
        blink_counter <= blink_counter + 1'b1;

        if (rst_cnt < RESET_COUNT_MAX) begin
            rst_cnt <= rst_cnt + 1'b1;
            rst <= 1'b1;
        end else begin
            rst <= 1'b0;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            state <= STATE_RESET_WAIT;
            sample_valid <= 1'b0;
            sample_in <= {SAMPLE_WIDTH{1'b0}};
            feed_index <= {INDEX_WIDTH{1'b0}};
            timeout_counter <= 32'd0;
            pass_latched <= 1'b0;
            fail_latched <= 1'b0;
            overflow_latched <= 1'b0;
            timeout_latched <= 1'b0;
            check_mask <= 7'd0;
            observed_output_count <= {(INDEX_WIDTH + 1){1'b0}};
        end else begin
            sample_valid <= 1'b0;
            sample_in <= {SAMPLE_WIDTH{1'b0}};

            case (state)
                STATE_RESET_WAIT: begin
                    state <= STATE_FEED_FRAME;
                end

                STATE_FEED_FRAME: begin
                    sample_valid <= 1'b1;
                    if (feed_index == {INDEX_WIDTH{1'b0}}) begin
                        sample_in <= IMPULSE_SAMPLE;
                    end else begin
                        sample_in <= {SAMPLE_WIDTH{1'b0}};
                    end

                    if (feed_index == FFT_SIZE - 1) begin
                        feed_index <= {INDEX_WIDTH{1'b0}};
                        timeout_counter <= 32'd0;
                        state <= STATE_WAIT_DONE;
                    end else begin
                        feed_index <= feed_index + 1'b1;
                    end
                end

                STATE_WAIT_DONE: begin
                    timeout_counter <= timeout_counter + 1'b1;

                    if (overflow) begin
                        overflow_latched <= 1'b1;
                        fail_latched <= 1'b1;
                    end

                    if (out_valid) begin
                        observed_output_count <= observed_output_count + 1'b1;

                        if (checked_index_mask(out_index) != 7'd0) begin
                            check_mask <= check_mask | checked_index_mask(out_index);

                            if (!within_tolerance(
                                    sample_out,
                                    expected_sample(out_index)
                                )) begin
                                fail_latched <= 1'b1;
                            end
                        end
                    end

                    if (timeout_counter >= TIMEOUT_MAX) begin
                        timeout_latched <= 1'b1;
                        fail_latched <= 1'b1;
                        state <= STATE_FAIL;
                    end else if (done) begin
                        if (fail_latched ||
                            overflow_latched ||
                            (check_mask != CHECK_MASK_ALL)) begin
                            fail_latched <= 1'b1;
                            state <= STATE_FAIL;
                        end else begin
                            pass_latched <= 1'b1;
                            state <= STATE_PASS;
                        end
                    end
                end

                STATE_PASS: begin
                    pass_latched <= 1'b1;
                end

                STATE_FAIL: begin
                    fail_latched <= 1'b1;
                end

                default: begin
                    fail_latched <= 1'b1;
                    state <= STATE_FAIL;
                end
            endcase
        end
    end

endmodule
