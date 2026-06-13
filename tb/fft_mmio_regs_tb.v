`timescale 1ns/1ps

module fft_mmio_regs_tb;

    localparam integer FFT_SIZE     = 256;
    localparam integer SAMPLE_WIDTH = 16;
    localparam integer ADDR_WIDTH   = 16;
    localparam integer DATA_WIDTH   = 32;
    localparam integer GAIN_WIDTH   = 16;
    localparam integer INDEX_WIDTH  = 8;

    localparam [ADDR_WIDTH-1:0] CONTROL_REG        = 16'h0000;
    localparam [ADDR_WIDTH-1:0] STATUS_REG         = 16'h0001;
    localparam [ADDR_WIDTH-1:0] MODE_REG           = 16'h0002;
    localparam [ADDR_WIDTH-1:0] BASS_GAIN_REG      = 16'h0003;
    localparam [ADDR_WIDTH-1:0] MID_GAIN_REG       = 16'h0004;
    localparam [ADDR_WIDTH-1:0] TREBLE_GAIN_REG    = 16'h0005;
    localparam [ADDR_WIDTH-1:0] INPUT_SAMPLE_BASE  = 16'h0100;
    localparam [ADDR_WIDTH-1:0] OUTPUT_SAMPLE_BASE = 16'h0200;

    localparam signed [GAIN_WIDTH-1:0] GAIN_0_75 = 16'sd12288;
    localparam signed [GAIN_WIDTH-1:0] GAIN_1_00 = 16'sd16384;
    localparam signed [GAIN_WIDTH-1:0] GAIN_1_25 = 16'sd20480;
    localparam signed [GAIN_WIDTH-1:0] GAIN_1_50 = 16'sd24576;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg wr_en = 1'b0;
    reg [ADDR_WIDTH-1:0] wr_addr = {ADDR_WIDTH{1'b0}};
    reg [DATA_WIDTH-1:0] wr_data = {DATA_WIDTH{1'b0}};
    reg rd_en = 1'b0;
    reg [ADDR_WIDTH-1:0] rd_addr = {ADDR_WIDTH{1'b0}};
    reg pipeline_busy = 1'b0;
    reg pipeline_done = 1'b0;
    reg pipeline_overflow = 1'b0;
    reg pipeline_error = 1'b0;
    reg output_sample_we = 1'b0;
    reg [INDEX_WIDTH-1:0] output_sample_index = {INDEX_WIDTH{1'b0}};
    reg signed [SAMPLE_WIDTH-1:0] output_sample_data = 16'sd0;
    reg [INDEX_WIDTH-1:0] input_sample_read_index = {INDEX_WIDTH{1'b0}};

    wire [DATA_WIDTH-1:0] rd_data;
    wire signed [SAMPLE_WIDTH-1:0] input_sample_read_data;
    wire start_pulse;
    wire clear_pulse;
    wire [DATA_WIDTH-1:0] mode_reg;
    wire signed [GAIN_WIDTH-1:0] bass_gain;
    wire signed [GAIN_WIDTH-1:0] mid_gain;
    wire signed [GAIN_WIDTH-1:0] treble_gain;

    integer errors = 0;
    integer i;
    reg [DATA_WIDTH-1:0] read_value;
    reg sample_mem_ok;
    integer selected_index [0:6];

    fft_mmio_regs #(
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
        .pipeline_busy(pipeline_busy),
        .pipeline_done(pipeline_done),
        .pipeline_overflow(pipeline_overflow),
        .pipeline_error(pipeline_error),
        .output_sample_we(output_sample_we),
        .output_sample_index(output_sample_index),
        .output_sample_data(output_sample_data),
        .input_sample_read_index(input_sample_read_index),
        .input_sample_read_data(input_sample_read_data),
        .start_pulse(start_pulse),
        .clear_pulse(clear_pulse),
        .mode_reg(mode_reg),
        .bass_gain(bass_gain),
        .mid_gain(mid_gain),
        .treble_gain(treble_gain)
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

    task write_output_sample;
        input [INDEX_WIDTH-1:0] index;
        input signed [SAMPLE_WIDTH-1:0] sample;
        begin
            @(negedge clk);
            output_sample_we = 1'b1;
            output_sample_index = index;
            output_sample_data = sample;

            @(posedge clk);
            #1;

            @(negedge clk);
            output_sample_we = 1'b0;
            output_sample_index = {INDEX_WIDTH{1'b0}};
            output_sample_data = 16'sd0;
        end
    endtask

    function [DATA_WIDTH-1:0] sign_extend_sample;
        input signed [SAMPLE_WIDTH-1:0] sample;
        begin
            sign_extend_sample = {{(DATA_WIDTH-SAMPLE_WIDTH)
                                  {sample[SAMPLE_WIDTH-1]}}, sample};
        end
    endfunction

    function signed [SAMPLE_WIDTH-1:0] expected_input_sample;
        input integer index;
        begin
            expected_input_sample = index + 16'sd7;
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

        $display("=== FFT MMIO REGS STAGE 1 TEST ===");
        $display("REGISTER_LAYER_ONLY=1");
        $display("");

        repeat (3) @(posedge clk);
        #1;

        report_result("status_reset_default",
                      (start_pulse === 1'b0) &&
                      (clear_pulse === 1'b0) &&
                      (mode_reg === 32'h00000000) &&
                      (bass_gain === GAIN_1_00) &&
                      (mid_gain === GAIN_1_00) &&
                      (treble_gain === GAIN_1_00));

        @(negedge clk);
        rst = 1'b0;

        read_word(STATUS_REG, read_value);
        report_result("status_read_default", read_value === 32'h00000000);

        @(negedge clk);
        wr_en = 1'b1;
        wr_addr = CONTROL_REG;
        wr_data = 32'h00000001;

        @(posedge clk);
        #1;
        report_result("ctrl_start_pulse", start_pulse === 1'b1);

        @(negedge clk);
        wr_en = 1'b0;
        wr_addr = {ADDR_WIDTH{1'b0}};
        wr_data = {DATA_WIDTH{1'b0}};

        @(posedge clk);
        #1;
        report_result("ctrl_start_one_cycle", start_pulse === 1'b0);

        read_word(CONTROL_REG, read_value);
        report_result("ctrl_read_zero", read_value === 32'h00000000);

        write_word(MODE_REG, 32'h00000003);
        read_word(MODE_REG, read_value);
        report_result("mode_write_read",
                      (read_value === 32'h00000003) &&
                      (mode_reg === 32'h00000003));

        write_word(BASS_GAIN_REG, sign_extend_sample(GAIN_1_50));
        write_word(MID_GAIN_REG, sign_extend_sample(GAIN_1_25));
        write_word(TREBLE_GAIN_REG, sign_extend_sample(GAIN_0_75));

        read_word(BASS_GAIN_REG, read_value);
        if (read_value !== sign_extend_sample(GAIN_1_50)) begin
            report_result("gain_write_read", 0);
        end else begin
            read_word(MID_GAIN_REG, read_value);
            if (read_value !== sign_extend_sample(GAIN_1_25)) begin
                report_result("gain_write_read", 0);
            end else begin
                read_word(TREBLE_GAIN_REG, read_value);
                report_result("gain_write_read",
                              (read_value === sign_extend_sample(GAIN_0_75)) &&
                              (bass_gain === GAIN_1_50) &&
                              (mid_gain === GAIN_1_25) &&
                              (treble_gain === GAIN_0_75));
            end
        end

        sample_mem_ok = 1;
        for (i = 0; i < 7; i = i + 1) begin
            write_word(INPUT_SAMPLE_BASE + selected_index[i],
                       sign_extend_sample(expected_input_sample(selected_index[i])));
        end

        for (i = 0; i < 7; i = i + 1) begin
            read_word(INPUT_SAMPLE_BASE + selected_index[i], read_value);
            if (read_value !==
                sign_extend_sample(expected_input_sample(selected_index[i]))) begin
                sample_mem_ok = 0;
                $display("  input sample mismatch index=%0d value=%0d",
                         selected_index[i], read_value);
            end

            input_sample_read_index = selected_index[i][INDEX_WIDTH-1:0];
            @(posedge clk);
            #1;
            if (input_sample_read_data !==
                expected_input_sample(selected_index[i])) begin
                sample_mem_ok = 0;
                $display("  input read port mismatch index=%0d value=%0d",
                         selected_index[i], input_sample_read_data);
            end
        end
        report_result("input_sample_memory_write_read", sample_mem_ok);

        sample_mem_ok = 1;
        for (i = 0; i < 7; i = i + 1) begin
            read_word(OUTPUT_SAMPLE_BASE + selected_index[i], read_value);
            if (read_value !== 32'h00000000) begin
                sample_mem_ok = 0;
            end
        end
        report_result("output_sample_memory_reset_zero", sample_mem_ok);

        write_output_sample(8'd0, 16'sd64);
        write_output_sample(8'd255, -16'sd3);
        read_word(OUTPUT_SAMPLE_BASE + 16'd0, read_value);
        report_result("output_sample_write_port", read_value === 32'h00000040);

        @(negedge clk);
        wr_en = 1'b1;
        wr_addr = CONTROL_REG;
        wr_data = 32'h00000002;

        @(posedge clk);
        #1;
        report_result("ctrl_clear_pulse", clear_pulse === 1'b1);

        @(negedge clk);
        wr_en = 1'b0;
        wr_addr = {ADDR_WIDTH{1'b0}};
        wr_data = {DATA_WIDTH{1'b0}};

        @(posedge clk);
        #1;

        sample_mem_ok = 1;
        for (i = 0; i < 7; i = i + 1) begin
            read_word(OUTPUT_SAMPLE_BASE + selected_index[i], read_value);
            if (read_value !== 32'h00000000) begin
                sample_mem_ok = 0;
            end
        end
        report_result("output_sample_memory_clear_zero", sample_mem_ok);

        $display("");
        if (errors == 0) begin
            $display("STATUS=PASS");
        end else begin
            $display("STATUS=FAIL errors=%0d", errors);
        end

        $finish;
    end

endmodule
