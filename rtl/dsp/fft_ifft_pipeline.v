module fft_ifft_pipeline #(
    parameter integer FFT_SIZE     = 256,
    parameter integer SAMPLE_WIDTH = 16,
    parameter integer INTERNAL_WIDTH = 24,
    parameter integer GAIN_WIDTH   = 16,
    parameter integer INDEX_WIDTH  = 8,
    parameter integer AUTO_START   = 1
) (
    input  wire                              clk,
    input  wire                              rst,
    input  wire                              sample_valid,
    input  wire signed [SAMPLE_WIDTH-1:0]    sample_in,
    input  wire signed [GAIN_WIDTH-1:0]      bass_gain,
    input  wire signed [GAIN_WIDTH-1:0]      mid_gain,
    input  wire signed [GAIN_WIDTH-1:0]      treble_gain,
    input  wire                              start_process,

    output wire                              out_valid,
    output wire [INDEX_WIDTH-1:0]            out_index,
    output wire signed [SAMPLE_WIDTH-1:0]    sample_out,
    output wire                              busy,
    output wire                              done,
    output wire                              overflow
);

    localparam [0:0] STATE_COLLECT = 1'b0;
    localparam [0:0] STATE_PROCESS = 1'b1;
    localparam integer OUTPUT_GUARD_WIDTH = INTERNAL_WIDTH - SAMPLE_WIDTH + 1;

    reg state;
    reg consume_frame;
    reg fft_start;
    reg ifft_started;

    wire buffer_frame_ready;
    wire buffer_frame_valid;
    wire buffer_frame_start;
    wire buffer_frame_end;
    wire [INDEX_WIDTH-1:0] buffer_frame_index;
    wire signed [SAMPLE_WIDTH-1:0] buffer_frame_sample;
    wire buffer_overflow;

    reg fft_in_valid;
    reg [INDEX_WIDTH-1:0] fft_in_index;
    reg signed [INTERNAL_WIDTH-1:0] fft_real_in;
    reg signed [INTERNAL_WIDTH-1:0] fft_imag_in;

    wire fft_out_valid;
    wire [INDEX_WIDTH-1:0] fft_out_index;
    wire signed [INTERNAL_WIDTH-1:0] fft_real_out;
    wire signed [INTERNAL_WIDTH-1:0] fft_imag_out;
    wire fft_busy;
    wire fft_done;

    wire spectral_out_valid;
    wire signed [INTERNAL_WIDTH-1:0] spectral_real_out;
    wire signed [INTERNAL_WIDTH-1:0] spectral_imag_out;
    wire signed [GAIN_WIDTH-1:0] spectral_selected_gain;
    wire [1:0] spectral_band_id;
    reg [INDEX_WIDTH-1:0] spectral_index;

    wire ifft_start;
    wire ifft_out_valid;
    wire [INDEX_WIDTH-1:0] ifft_out_index;
    wire signed [INTERNAL_WIDTH-1:0] ifft_real_out;
    wire signed [INTERNAL_WIDTH-1:0] ifft_imag_out;
    wire ifft_busy;
    wire ifft_done;

    wire start_request;

    assign start_request = (AUTO_START != 0) ?
                           buffer_frame_ready :
                           (buffer_frame_ready && start_process);
    assign ifft_start = (state == STATE_PROCESS) && fft_out_valid && !ifft_started;

    assign out_valid = ifft_out_valid;
    assign out_index = ifft_out_index;
    function signed [SAMPLE_WIDTH-1:0] saturate_to_sample_width;
        input signed [INTERNAL_WIDTH-1:0] value;
        reg [OUTPUT_GUARD_WIDTH-1:0] guard_bits;
        begin
            guard_bits = value[INTERNAL_WIDTH-1:SAMPLE_WIDTH-1];
            if (guard_bits == {OUTPUT_GUARD_WIDTH{value[SAMPLE_WIDTH-1]}}) begin
                saturate_to_sample_width = value[SAMPLE_WIDTH-1:0];
            end else if (value[INTERNAL_WIDTH-1]) begin
                saturate_to_sample_width = {1'b1, {(SAMPLE_WIDTH-1){1'b0}}};
            end else begin
                saturate_to_sample_width = {1'b0, {(SAMPLE_WIDTH-1){1'b1}}};
            end
        end
    endfunction

    assign sample_out = saturate_to_sample_width(ifft_real_out);
    assign done = ifft_done;
    assign overflow = buffer_overflow;
    assign busy = (((state == STATE_PROCESS) && !ifft_done) ||
                   buffer_frame_ready ||
                   fft_busy ||
                   ifft_busy);

    sample_block_buffer #(
        .FFT_SIZE(FFT_SIZE),
        .SAMPLE_WIDTH(SAMPLE_WIDTH),
        .ADDR_WIDTH(INDEX_WIDTH)
    ) sample_buffer_inst (
        .clk(clk),
        .rst(rst),
        .sample_valid(sample_valid),
        .sample_in(sample_in),
        .consume_frame(consume_frame),
        .frame_ready(buffer_frame_ready),
        .frame_valid(buffer_frame_valid),
        .frame_start(buffer_frame_start),
        .frame_end(buffer_frame_end),
        .frame_index(buffer_frame_index),
        .frame_sample(buffer_frame_sample),
        .overflow(buffer_overflow)
    );

    fft_accel_wrapper #(
        .FFT_SIZE(FFT_SIZE),
        .DATA_WIDTH(INTERNAL_WIDTH),
        .INDEX_WIDTH(INDEX_WIDTH)
    ) fft_inst (
        .clk(clk),
        .rst(rst),
        .start(fft_start),
        .in_valid(fft_in_valid),
        .in_index(fft_in_index),
        .real_in(fft_real_in),
        .imag_in(fft_imag_in),
        .out_valid(fft_out_valid),
        .out_index(fft_out_index),
        .real_out(fft_real_out),
        .imag_out(fft_imag_out),
        .busy(fft_busy),
        .done(fft_done)
    );

    spectral_processor #(
        .FFT_SIZE(FFT_SIZE),
        .BIN_WIDTH(INDEX_WIDTH),
        .DATA_WIDTH(INTERNAL_WIDTH),
        .GAIN_WIDTH(GAIN_WIDTH)
    ) spectral_processor_inst (
        .clk(clk),
        .rst(rst),
        .in_valid(fft_out_valid),
        .bin_index(fft_out_index),
        .real_in(fft_real_out),
        .imag_in(fft_imag_out),
        .bass_gain(bass_gain),
        .mid_gain(mid_gain),
        .treble_gain(treble_gain),
        .out_valid(spectral_out_valid),
        .real_out(spectral_real_out),
        .imag_out(spectral_imag_out),
        .selected_gain(spectral_selected_gain),
        .band_id(spectral_band_id)
    );

    ifft_accel_wrapper #(
        .FFT_SIZE(FFT_SIZE),
        .DATA_WIDTH(INTERNAL_WIDTH),
        .INDEX_WIDTH(INDEX_WIDTH)
    ) ifft_inst (
        .clk(clk),
        .rst(rst),
        .start(ifft_start),
        .in_valid(spectral_out_valid),
        .in_index(spectral_index),
        .real_in(spectral_real_out),
        .imag_in(spectral_imag_out),
        .out_valid(ifft_out_valid),
        .out_index(ifft_out_index),
        .real_out(ifft_real_out),
        .imag_out(ifft_imag_out),
        .busy(ifft_busy),
        .done(ifft_done)
    );

    always @(posedge clk) begin
        if (rst) begin
            state          <= STATE_COLLECT;
            consume_frame  <= 1'b0;
            fft_start      <= 1'b0;
            ifft_started   <= 1'b0;
            fft_in_valid   <= 1'b0;
            fft_in_index   <= {INDEX_WIDTH{1'b0}};
            fft_real_in    <= {INTERNAL_WIDTH{1'b0}};
            fft_imag_in    <= {INTERNAL_WIDTH{1'b0}};
            spectral_index <= {INDEX_WIDTH{1'b0}};
        end else begin
            consume_frame <= 1'b0;
            fft_start     <= 1'b0;

            fft_in_valid <= buffer_frame_valid;
            fft_in_index <= buffer_frame_index;
            fft_real_in  <= {{(INTERNAL_WIDTH-SAMPLE_WIDTH)
                              {buffer_frame_sample[SAMPLE_WIDTH-1]}},
                              buffer_frame_sample};
            fft_imag_in  <= {INTERNAL_WIDTH{1'b0}};

            if (fft_out_valid) begin
                spectral_index <= fft_out_index;
            end

            case (state)
                STATE_COLLECT: begin
                    ifft_started <= 1'b0;

                    if (start_request) begin
                        consume_frame <= 1'b1;
                        fft_start     <= 1'b1;
                        state         <= STATE_PROCESS;
                    end
                end

                STATE_PROCESS: begin
                    if (ifft_start) begin
                        ifft_started <= 1'b1;
                    end

                    if (ifft_done) begin
                        state <= STATE_COLLECT;
                    end
                end

                default: begin
                    state <= STATE_COLLECT;
                end
            endcase
        end
    end

endmodule
