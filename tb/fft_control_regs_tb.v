`timescale 1ns/1ps

module fft_control_regs_tb;

    localparam integer ADDR_WIDTH = 4;
    localparam integer DATA_WIDTH = 32;
    localparam integer GAIN_WIDTH = 16;

    localparam [ADDR_WIDTH-1:0] CONTROL_REG     = 4'h0;
    localparam [ADDR_WIDTH-1:0] STATUS_REG      = 4'h1;
    localparam [ADDR_WIDTH-1:0] BASS_GAIN_REG   = 4'h2;
    localparam [ADDR_WIDTH-1:0] MID_GAIN_REG    = 4'h3;
    localparam [ADDR_WIDTH-1:0] TREBLE_GAIN_REG = 4'h4;
    localparam [ADDR_WIDTH-1:0] TEST_SELECT_REG = 4'h5;
    localparam [ADDR_WIDTH-1:0] DEBUG_REG       = 4'h6;

    localparam signed [GAIN_WIDTH-1:0] GAIN_0_50 = 16'sd8192;
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
    reg pipeline_busy = 1'b0;
    reg pipeline_done = 1'b0;
    reg pipeline_overflow = 1'b0;
    reg pipeline_error = 1'b0;

    wire [DATA_WIDTH-1:0] rd_data;
    wire start_pulse;
    wire bypass_enable;
    wire spectral_enable;
    wire signed [GAIN_WIDTH-1:0] bass_gain;
    wire signed [GAIN_WIDTH-1:0] mid_gain;
    wire signed [GAIN_WIDTH-1:0] treble_gain;
    wire [DATA_WIDTH-1:0] test_select;

    integer errors = 0;
    integer start_pulse_ok;
    reg [DATA_WIDTH-1:0] read_value;

    fft_control_regs #(
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
        .pipeline_busy(pipeline_busy),
        .pipeline_done(pipeline_done),
        .pipeline_overflow(pipeline_overflow),
        .pipeline_error(pipeline_error),
        .start_pulse(start_pulse),
        .bypass_enable(bypass_enable),
        .spectral_enable(spectral_enable),
        .bass_gain(bass_gain),
        .mid_gain(mid_gain),
        .treble_gain(treble_gain),
        .test_select(test_select)
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

    initial begin
        $display("=== FFT CONTROL REGS TEST ===");
        $display("");

        repeat (3) @(posedge clk);
        #1;
        report_result("reset_defaults",
                      (start_pulse === 1'b0) &&
                      (bypass_enable === 1'b0) &&
                      (spectral_enable === 1'b1) &&
                      (bass_gain === GAIN_1_00) &&
                      (mid_gain === GAIN_1_00) &&
                      (treble_gain === GAIN_1_00) &&
                      (test_select === 32'h00000000));

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

        write_reg(BASS_GAIN_REG, {16'h0000, GAIN_1_50});
        write_reg(MID_GAIN_REG, {16'h0000, GAIN_0_75});
        write_reg(TREBLE_GAIN_REG, {16'h0000, GAIN_0_50});

        read_reg(BASS_GAIN_REG, read_value);
        if (read_value !== {16'h0000, GAIN_1_50}) begin
            report_result("write_read_gains", 0);
        end else begin
            read_reg(MID_GAIN_REG, read_value);
            if (read_value !== {16'h0000, GAIN_0_75}) begin
                report_result("write_read_gains", 0);
            end else begin
                read_reg(TREBLE_GAIN_REG, read_value);
                report_result("write_read_gains",
                              (read_value === {16'h0000, GAIN_0_50}) &&
                              (bass_gain === GAIN_1_50) &&
                              (mid_gain === GAIN_0_75) &&
                              (treble_gain === GAIN_0_50));
            end
        end

        @(negedge clk);
        wr_en = 1'b1;
        wr_addr = CONTROL_REG;
        wr_data = 32'h00000005;

        @(posedge clk);
        #1;
        start_pulse_ok = (start_pulse === 1'b1);
        if (start_pulse !== 1'b1) begin
            $display("  start pulse error: pulse was not asserted");
        end

        @(negedge clk);
        wr_en = 1'b0;
        wr_addr = {ADDR_WIDTH{1'b0}};
        wr_data = {DATA_WIDTH{1'b0}};

        @(posedge clk);
        #1;
        if (start_pulse !== 1'b0) begin
            start_pulse_ok = 0;
            $display("  start pulse error: pulse stayed high for more than one cycle");
        end
        report_result("start_pulse", start_pulse_ok);

        write_reg(CONTROL_REG, 32'h00000006);
        report_result("bypass_enable", bypass_enable === 1'b1);
        report_result("spectral_enable", spectral_enable === 1'b1);

        @(negedge clk);
        pipeline_done = 1'b1;
        @(posedge clk);
        #1;
        pipeline_done = 1'b0;
        read_reg(STATUS_REG, read_value);
        report_result("done_latch", read_value[1] === 1'b1);

        @(negedge clk);
        pipeline_overflow = 1'b1;
        @(posedge clk);
        #1;
        pipeline_overflow = 1'b0;
        read_reg(STATUS_REG, read_value);
        report_result("overflow_latch", read_value[2] === 1'b1);

        @(negedge clk);
        pipeline_busy = 1'b1;
        read_reg(STATUS_REG, read_value);
        report_result("read_status",
                      (read_value[0] === 1'b1) &&
                      (read_value[1] === 1'b1) &&
                      (read_value[2] === 1'b1));
        @(negedge clk);
        pipeline_busy = 1'b0;

        write_reg(CONTROL_REG, 32'h0000000C);
        read_reg(STATUS_REG, read_value);
        report_result("clear_status",
                      (read_value[1] === 1'b0) &&
                      (read_value[2] === 1'b0) &&
                      (read_value[3] === 1'b0));

        write_reg(TEST_SELECT_REG, 32'hA5A55A5A);
        read_reg(TEST_SELECT_REG, read_value);
        report_result("test_select",
                      (read_value === 32'hA5A55A5A) &&
                      (test_select === 32'hA5A55A5A));

        read_reg(DEBUG_REG, read_value);
        report_result("debug_reg", read_value === 32'h00010000);

        $display("");
        if (errors == 0) begin
            $display("STATUS=PASS");
        end else begin
            $display("STATUS=FAIL errors=%0d", errors);
        end

        $finish;
    end

endmodule
