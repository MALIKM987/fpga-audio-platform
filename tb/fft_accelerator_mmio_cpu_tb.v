`timescale 1ns/1ps

module fft_accelerator_mmio_cpu_tb;

    localparam integer FFT_SIZE     = 256;
    localparam integer SAMPLE_WIDTH = 16;
    localparam integer ADDR_WIDTH   = 16;
    localparam integer DATA_WIDTH   = 32;
    localparam integer GAIN_WIDTH   = 16;
    localparam integer INDEX_WIDTH  = 8;

    localparam [ADDR_WIDTH-1:0] CONTROL_REG        = 16'h0000;
    localparam [ADDR_WIDTH-1:0] STATUS_REG         = 16'h0001;
    localparam [ADDR_WIDTH-1:0] BASS_GAIN_REG      = 16'h0003;
    localparam [ADDR_WIDTH-1:0] MID_GAIN_REG       = 16'h0004;
    localparam [ADDR_WIDTH-1:0] TREBLE_GAIN_REG    = 16'h0005;
    localparam [ADDR_WIDTH-1:0] INPUT_SAMPLE_BASE  = 16'h0100;
    localparam [ADDR_WIDTH-1:0] OUTPUT_SAMPLE_BASE = 16'h0200;

    localparam signed [GAIN_WIDTH-1:0] GAIN_1_00 = 16'sd16384;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg wr_en = 1'b0;
    reg [ADDR_WIDTH-1:0] wr_addr = {ADDR_WIDTH{1'b0}};
    reg [DATA_WIDTH-1:0] wr_data = {DATA_WIDTH{1'b0}};
    reg rd_en = 1'b0;
    reg [ADDR_WIDTH-1:0] rd_addr = {ADDR_WIDTH{1'b0}};

    wire [DATA_WIDTH-1:0] rd_data;
    wire busy;
    wire done;
    wire overflow;
    wire error;

    integer errors = 0;
    integer i;
    integer timeout_count = 0;
    integer selected_index [0:6];
    reg [DATA_WIDTH-1:0] status_value;
    reg [DATA_WIDTH-1:0] read_value;
    reg output_ok;

    fft_accelerator_mmio #(
        .FFT_SIZE(FFT_SIZE),
        .SAMPLE_WIDTH(SAMPLE_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .GAIN_WIDTH(GAIN_WIDTH),
        .INDEX_WIDTH(INDEX_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .wr_en(wr_en),
        .wr_addr(wr_addr),
        .wr_data(wr_data),
        .rd_en(rd_en),
        .rd_addr(rd_addr),
        .rd_data(rd_data),
        .busy(busy),
        .done(done),
        .overflow(overflow),
        .error(error)
    );

    always #5 clk = ~clk;

    task report_result;
        input [8*48-1:0] name;
        input pass;
        begin
            if (pass) begin
                $display("TEST %0s PASS", name);
            end else begin
                $display("TEST %0s FAIL", name);
                errors = errors + 1;
            end
        end
    endtask

    task write_word;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] data;
        begin
            @(negedge clk);
            wr_en = 1'b1;
            wr_addr = addr;
            wr_data = data;

            @(posedge clk);
            #1;

            @(negedge clk);
            wr_en = 1'b0;
            wr_addr = {ADDR_WIDTH{1'b0}};
            wr_data = {DATA_WIDTH{1'b0}};
        end
    endtask

    task read_word;
        input [ADDR_WIDTH-1:0] addr;
        output [DATA_WIDTH-1:0] data;
        begin
            @(negedge clk);
            rd_en = 1'b1;
            rd_addr = addr;

            @(posedge clk);
            #1;
            data = rd_data;

            @(negedge clk);
            rd_en = 1'b0;
            rd_addr = {ADDR_WIDTH{1'b0}};
        end
    endtask

    function [DATA_WIDTH-1:0] sample_word;
        input signed [SAMPLE_WIDTH-1:0] sample;
        begin
            sample_word = {{(DATA_WIDTH-SAMPLE_WIDTH)
                           {sample[SAMPLE_WIDTH-1]}}, sample};
        end
    endfunction

    function integer abs_diff_ok;
        input signed [SAMPLE_WIDTH-1:0] actual;
        input signed [SAMPLE_WIDTH-1:0] expected;
        reg signed [SAMPLE_WIDTH:0] diff;
        begin
            diff = {actual[SAMPLE_WIDTH-1], actual} -
                   {expected[SAMPLE_WIDTH-1], expected};
            abs_diff_ok = (diff <= 17'sd2) && (diff >= -17'sd2);
        end
    endfunction

    function signed [SAMPLE_WIDTH-1:0] low_sample;
        input [DATA_WIDTH-1:0] word_value;
        begin
            low_sample = word_value[SAMPLE_WIDTH-1:0];
        end
    endfunction

    initial begin
        selected_index[0] = 0;
        selected_index[1] = 1;
        selected_index[2] = 2;
        selected_index[3] = 16;
        selected_index[4] = 64;
        selected_index[5] = 128;
        selected_index[6] = 255;

        $display("=== FFT ACCELERATOR MMIO STAGE 3 CPU-LIKE TEST ===");
        $display("FRAME=impulse64");
        $display("GAINS=unity");
        $display("");

        repeat (3) @(posedge clk);
        #1;
        report_result("reset", (busy === 1'b0) &&
                               (done === 1'b0) &&
                               (overflow === 1'b0));

        @(negedge clk);
        rst = 1'b0;

        write_word(BASS_GAIN_REG, sample_word(GAIN_1_00));
        write_word(MID_GAIN_REG, sample_word(GAIN_1_00));
        write_word(TREBLE_GAIN_REG, sample_word(GAIN_1_00));
        report_result("write_unity_gains", 1);

        for (i = 0; i < FFT_SIZE; i = i + 1) begin
            if (i == 0) begin
                write_word(INPUT_SAMPLE_BASE + i[ADDR_WIDTH-1:0],
                           sample_word(16'sd64));
            end else begin
                write_word(INPUT_SAMPLE_BASE + i[ADDR_WIDTH-1:0],
                           sample_word(16'sd0));
            end
        end
        report_result("write_impulse_frame", 1);

        write_word(CONTROL_REG, 32'h00000001);

        status_value = 32'h00000000;
        while (timeout_count < 30000 && status_value[1] !== 1'b1) begin
            read_word(STATUS_REG, status_value);
            timeout_count = timeout_count + 1;
        end

        report_result("poll_until_done", status_value[1] === 1'b1);
        report_result("status_done_set", status_value[1] === 1'b1);
        report_result("status_no_overflow_error",
                      (status_value[2] === 1'b0) &&
                      (status_value[3] === 1'b0));

        output_ok = 1;
        for (i = 0; i < 7; i = i + 1) begin
            read_word(OUTPUT_SAMPLE_BASE + selected_index[i], read_value);

            if (selected_index[i] == 0) begin
                if (!abs_diff_ok(low_sample(read_value), 16'sd64)) begin
                    output_ok = 0;
                    $display("  output mismatch index=0 value=%0d",
                             low_sample(read_value));
                end
            end else begin
                if (!abs_diff_ok(low_sample(read_value), 16'sd0)) begin
                    output_ok = 0;
                    $display("  output mismatch index=%0d value=%0d",
                             selected_index[i], low_sample(read_value));
                end
            end
        end
        report_result("selected_output_samples", output_ok);

        $display("");
        if (errors == 0) begin
            $display("STATUS=PASS");
        end else begin
            $display("STATUS=FAIL errors=%0d", errors);
        end

        $finish;
    end

endmodule
