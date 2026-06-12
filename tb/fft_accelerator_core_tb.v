`timescale 1ns/1ps

module fft_accelerator_core_tb;

    localparam integer FFT_SIZE     = 256;
    localparam integer SAMPLE_WIDTH = 16;
    localparam integer ADDR_WIDTH   = 4;
    localparam integer DATA_WIDTH   = 32;
    localparam integer GAIN_WIDTH   = 16;

    localparam [ADDR_WIDTH-1:0] CONTROL_REG     = 4'h0;
    localparam [ADDR_WIDTH-1:0] STATUS_REG      = 4'h1;
    localparam [ADDR_WIDTH-1:0] BASS_GAIN_REG   = 4'h2;
    localparam [ADDR_WIDTH-1:0] MID_GAIN_REG    = 4'h3;
    localparam [ADDR_WIDTH-1:0] TREBLE_GAIN_REG = 4'h4;

    localparam signed [GAIN_WIDTH-1:0] GAIN_0_75 = 16'sd12288;
    localparam signed [GAIN_WIDTH-1:0] GAIN_1_00 = 16'sd16384;
    localparam signed [GAIN_WIDTH-1:0] GAIN_1_50 = 16'sd24576;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg wr_en = 1'b0;
    reg [ADDR_WIDTH-1:0] wr_addr = {ADDR_WIDTH{1'b0}};
    reg [DATA_WIDTH-1:0] wr_data = {DATA_WIDTH{1'b0}};
    reg rd_en = 1'b0;
    reg [ADDR_WIDTH-1:0] rd_addr = {ADDR_WIDTH{1'b0}};
    reg sample_valid = 1'b0;
    reg signed [SAMPLE_WIDTH-1:0] sample_in = 16'sd0;

    wire [DATA_WIDTH-1:0] rd_data;
    wire out_valid;
    wire [7:0] out_index;
    wire signed [SAMPLE_WIDTH-1:0] sample_out;
    wire busy;
    wire done;
    wire overflow;

    integer errors = 0;
    integer i;
    integer timeout_count = 0;
    integer output_count = 0;
    integer collect_ok = 1;
    integer pipeline_done_ok = 0;
    integer output_count_ok = 0;
    integer output_order_ok = 1;
    integer overflow_ok = 1;
    integer bass_gain_path_ok = 0;
    integer mid_gain_path_ok = 0;
    integer treble_gain_path_ok = 0;
    integer vector_fd = 0;
    integer expected_fd = 0;
    integer output_fd = 0;
    integer scan_result = 0;
    integer csv_index = 0;
    integer csv_sample = 0;
    integer line_status = 0;
    reg [DATA_WIDTH-1:0] read_value;
    reg [8*64-1:0] csv_header;
    reg signed [SAMPLE_WIDTH-1:0] input_samples [0:FFT_SIZE-1];
    reg signed [SAMPLE_WIDTH-1:0] expected_samples [0:FFT_SIZE-1];

    fft_accelerator_core #(
        .FFT_SIZE(FFT_SIZE),
        .SAMPLE_WIDTH(SAMPLE_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .GAIN_WIDTH(GAIN_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .wr_en(wr_en),
        .wr_addr(wr_addr),
        .wr_data(wr_data),
        .rd_en(rd_en),
        .rd_addr(rd_addr),
        .rd_data(rd_data),
        .sample_valid(sample_valid),
        .sample_in(sample_in),
        .out_valid(out_valid),
        .out_index(out_index),
        .sample_out(sample_out),
        .busy(busy),
        .done(done),
        .overflow(overflow)
    );

    always #5 clk = ~clk;

    task report_result;
        input [8*32-1:0] name;
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

    task write_reg;
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

    task read_reg;
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

    function signed [SAMPLE_WIDTH-1:0] expected_output;
        input integer index;
        begin
            expected_output = expected_samples[index];
        end
    endfunction

    initial begin
        for (i = 0; i < FFT_SIZE; i = i + 1) begin
            input_samples[i] = 16'sd0;
            expected_samples[i] = 16'sd0;
        end

        vector_fd = $fopen("sim/vectors/mixed.csv", "r");
        if (vector_fd != 0) begin
            line_status = $fgets(csv_header, vector_fd);
            for (i = 0; i < FFT_SIZE; i = i + 1) begin
                scan_result = $fscanf(vector_fd, "%d,%d\n", csv_index, csv_sample);
                if (scan_result == 2 && csv_index >= 0 && csv_index < FFT_SIZE) begin
                    input_samples[csv_index] = csv_sample;
                end else begin
                    errors = errors + 1;
                    $display("TEST input_vector_read FAIL at row %0d", i);
                end
            end
            $fclose(vector_fd);
            $display("INPUT_VECTOR=sim/vectors/mixed.csv");

            expected_fd = $fopen(
                "sim/vectors/mixed_expected_rtl_fft_ifft_normalized.csv",
                "r"
            );
            if (expected_fd != 0) begin
                line_status = $fgets(csv_header, expected_fd);
                for (i = 0; i < FFT_SIZE; i = i + 1) begin
                    scan_result = $fscanf(expected_fd, "%d,%d\n", csv_index, csv_sample);
                    if (scan_result == 2 && csv_index >= 0 && csv_index < FFT_SIZE) begin
                        expected_samples[csv_index] = csv_sample;
                    end else begin
                        errors = errors + 1;
                        $display("TEST expected_vector_read FAIL at row %0d", i);
                    end
                end
                $fclose(expected_fd);
                $display("EXPECTED_VECTOR=sim/vectors/mixed_expected_rtl_fft_ifft_normalized.csv");
            end else begin
                errors = errors + 1;
                $display("TEST expected_vector_open FAIL");
            end
        end else begin
            $display("INPUT_VECTOR=default_zero_frame");
            $display("NOTE=sim/vectors/mixed.csv not found, using built-in zero frame.");
        end

        output_fd = $fopen("sim/fft_accelerator_core_output.csv", "w");
        if (output_fd != 0) begin
            $fdisplay(output_fd, "index,sample");
        end else begin
            $display("NOTE=Could not open sim/fft_accelerator_core_output.csv for writing.");
        end

        $display("=== REGISTER CONTROLLED FFT ACCELERATOR DEMO ===");
        $display("MODE=FFT_CORE_PLUS_NORMALIZED_IFFT");
        $display("NOTE=FFT and IFFT wrappers use fft_radix2_core; IFFT applies 1/N normalization.");
        $display("");
        $display("REGISTER MAP:");
        $display("0x0 CONTROL_REG");
        $display("0x1 STATUS_REG");
        $display("0x2 BASS_GAIN_REG");
        $display("0x3 MID_GAIN_REG");
        $display("0x4 TREBLE_GAIN_REG");
        $display("0x5 TEST_SELECT_REG");
        $display("0x6 DEBUG_REG");
        $display("");

        repeat (3) @(posedge clk);
        #1;
        report_result("reset",
                      (busy === 1'b0) &&
                      (done === 1'b0) &&
                      (overflow === 1'b0) &&
                      (out_valid === 1'b0));

        @(negedge clk);
        rst = 1'b0;

        read_reg(BASS_GAIN_REG, read_value);
        if (read_value !== {16'h0000, GAIN_1_00}) begin
            report_result("default_gains", 0);
        end else begin
            read_reg(MID_GAIN_REG, read_value);
            if (read_value !== {16'h0000, GAIN_1_00}) begin
                report_result("default_gains", 0);
            end else begin
                read_reg(TREBLE_GAIN_REG, read_value);
                report_result("default_gains", read_value === {16'h0000, GAIN_1_00});
            end
        end

        $display("");
        $display("CONFIGURATION:");
        $display("WRITE BASS_GAIN_REG=24576    // 1.50 Q2.14");
        $display("WRITE MID_GAIN_REG=16384     // 1.00 Q2.14");
        $display("WRITE TREBLE_GAIN_REG=12288  // 0.75 Q2.14");
        write_reg(BASS_GAIN_REG, {16'h0000, GAIN_1_50});
        write_reg(MID_GAIN_REG, {16'h0000, GAIN_1_00});
        write_reg(TREBLE_GAIN_REG, {16'h0000, GAIN_0_75});

        read_reg(BASS_GAIN_REG, read_value);
        if (read_value !== {16'h0000, GAIN_1_50}) begin
            report_result("write_gains", 0);
        end else begin
            read_reg(MID_GAIN_REG, read_value);
            if (read_value !== {16'h0000, GAIN_1_00}) begin
                report_result("write_gains", 0);
            end else begin
                read_reg(TREBLE_GAIN_REG, read_value);
                report_result("write_gains", read_value === {16'h0000, GAIN_0_75});
            end
        end

        $display("WRITE CONTROL_REG start=1 spectral_enable=1 bypass=0");
        write_reg(CONTROL_REG, 32'h00000005);
        @(posedge clk);
        #1;
        read_reg(STATUS_REG, read_value);
        report_result("control_start", read_value[0] === 1'b1);

        $display("");
        $display("PROCESS:");
        for (i = 0; i < FFT_SIZE; i = i + 1) begin
            @(negedge clk);
            sample_valid = 1'b1;
            sample_in = input_samples[i];

            @(posedge clk);
            #1;

            if (overflow) begin
                collect_ok = 0;
                overflow_ok = 0;
                $display("  overflow error while collecting sample %0d", i);
            end
        end

        @(negedge clk);
        sample_valid = 1'b0;
        sample_in = 16'sd0;

        while (!pipeline_done_ok && timeout_count < 25000) begin
            @(posedge clk);
            #1;
            timeout_count = timeout_count + 1;

            if (overflow) begin
                overflow_ok = 0;
            end

            if (out_valid) begin
                if (output_fd != 0) begin
                    $fdisplay(output_fd, "%0d,%0d", out_index, sample_out);
                end

                if (out_index !== output_count[7:0]) begin
                    output_order_ok = 0;
                    $display("  order error: out_index=%0d expected=%0d",
                             out_index, output_count);
                end

                if (sample_out !== expected_output(output_count)) begin
                    output_order_ok = 0;
                    $display("  data error at index %0d sample_out=%0d expected=%0d",
                             output_count, sample_out, expected_output(output_count));
                end

                if ((out_index == 8'd1) && (sample_out === expected_output(1))) begin
                    bass_gain_path_ok = 1;
                end

                if ((out_index == 8'd10) && (sample_out === expected_output(10))) begin
                    mid_gain_path_ok = 1;
                end

                if ((out_index == 8'd40) && (sample_out === expected_output(40))) begin
                    treble_gain_path_ok = 1;
                end

                output_count = output_count + 1;
            end

            if (done) begin
                pipeline_done_ok = 1;
            end
        end

        output_count_ok = (output_count == FFT_SIZE);

        report_result("collect_samples", collect_ok);
        if (collect_ok) begin
            $display("collect_samples=%0d PASS", FFT_SIZE);
        end else begin
            $display("collect_samples=%0d FAIL", FFT_SIZE);
        end

        report_result("pipeline_done", pipeline_done_ok);
        if (pipeline_done_ok) begin
            $display("pipeline_done=1 PASS");
        end else begin
            $display("pipeline_done=0 FAIL");
        end

        report_result("output_count", output_count_ok);
        report_result("output_order", output_order_ok);
        report_result("sample_spot_checks",
                      bass_gain_path_ok &&
                      mid_gain_path_ok &&
                      treble_gain_path_ok);
        report_result("overflow", overflow_ok);
        if (overflow_ok) begin
            $display("overflow=0 PASS");
        end else begin
            $display("overflow=1 FAIL");
        end

        @(posedge clk);
        #1;
        read_reg(STATUS_REG, read_value);
        $display("");
        $display("STATUS_REG:");
        $display("busy=%0d", read_value[0]);
        $display("done=%0d", read_value[1]);
        $display("overflow=%0d", read_value[2]);
        $display("error=%0d", read_value[3]);
        report_result("status_done_latched",
                      (read_value[1] === 1'b1) &&
                      (read_value[2] === 1'b0) &&
                      (read_value[3] === 1'b0));

        write_reg(CONTROL_REG, 32'h0000000C);
        read_reg(STATUS_REG, read_value);
        report_result("clear_status",
                      (read_value[1] === 1'b0) &&
                      (read_value[2] === 1'b0) &&
                      (read_value[3] === 1'b0));

        $display("");
        $display("SUMMARY:");
        if (errors == 0) begin
            $display("STATUS=PASS");
        end else begin
            $display("STATUS=FAIL errors=%0d", errors);
        end

        if (output_fd != 0) begin
            $fclose(output_fd);
        end

        $finish;
    end

endmodule
