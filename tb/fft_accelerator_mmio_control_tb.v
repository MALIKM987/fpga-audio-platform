`timescale 1ns/1ps

module fft_accelerator_mmio_control_tb;

    localparam integer FFT_SIZE     = 256;
    localparam integer SAMPLE_WIDTH = 16;
    localparam integer ADDR_WIDTH   = 16;
    localparam integer DATA_WIDTH   = 32;
    localparam integer GAIN_WIDTH   = 16;
    localparam integer INDEX_WIDTH  = 8;

    localparam [ADDR_WIDTH-1:0] CONTROL_REG        = 16'h0000;
    localparam [ADDR_WIDTH-1:0] STATUS_REG         = 16'h0001;
    localparam [ADDR_WIDTH-1:0] INPUT_SAMPLE_BASE  = 16'h0100;

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
    integer busy_seen = 0;
    reg [DATA_WIDTH-1:0] read_value;

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

    initial begin
        $display("=== FFT ACCELERATOR MMIO STAGE 2 CONTROL TEST ===");
        $display("");

        repeat (3) @(posedge clk);
        #1;
        report_result("reset", (busy === 1'b0) &&
                               (done === 1'b0) &&
                               (overflow === 1'b0));

        @(negedge clk);
        rst = 1'b0;

        for (i = 0; i < FFT_SIZE; i = i + 1) begin
            if (i == 0) begin
                write_word(INPUT_SAMPLE_BASE + i[ADDR_WIDTH-1:0],
                           sample_word(16'sd64));
            end else begin
                write_word(INPUT_SAMPLE_BASE + i[ADDR_WIDTH-1:0],
                           sample_word(16'sd0));
            end
        end

        write_word(CONTROL_REG, 32'h00000001);
        repeat (4) @(posedge clk);
        #1;
        read_word(STATUS_REG, read_value);
        report_result("start_launches_processing",
                      (busy === 1'b1) && (read_value[0] === 1'b1));

        write_word(CONTROL_REG, 32'h00000001);
        repeat (4) @(posedge clk);
        #1;
        read_word(STATUS_REG, read_value);
        report_result("second_start_rejected_while_busy",
                      read_value[3] === 1'b1);

        while (timeout_count < 30000 && read_value[1] !== 1'b1) begin
            @(posedge clk);
            #1;
            timeout_count = timeout_count + 1;
            if (busy) begin
                busy_seen = 1;
            end
            read_word(STATUS_REG, read_value);
        end

        report_result("busy_asserted_while_processing", busy_seen);
        report_result("done_after_completion", read_value[1] === 1'b1);
        report_result("overflow_reported_clear",
                      (read_value[2] === 1'b0) && (overflow === 1'b0));
        report_result("error_reported_from_rejected_start",
                      read_value[3] === 1'b1);

        write_word(CONTROL_REG, 32'h00000002);
        repeat (3) @(posedge clk);
        #1;
        read_word(STATUS_REG, read_value);
        report_result("clear_returns_idle",
                      (read_value === 32'h00000000) &&
                      (busy === 1'b0));

        $display("");
        if (errors == 0) begin
            $display("STATUS=PASS");
        end else begin
            $display("STATUS=FAIL errors=%0d", errors);
        end

        $finish;
    end

endmodule
