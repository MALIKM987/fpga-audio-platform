`timescale 1ns/1ps

module sample_block_buffer_tb;

    localparam integer FFT_SIZE     = 256;
    localparam integer SAMPLE_WIDTH = 16;
    localparam integer ADDR_WIDTH   = 8;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg sample_valid = 1'b0;
    reg signed [SAMPLE_WIDTH-1:0] sample_in = 16'sd0;
    reg consume_frame = 1'b0;

    wire frame_ready;
    wire frame_valid;
    wire frame_start;
    wire frame_end;
    wire [ADDR_WIDTH-1:0] frame_index;
    wire signed [SAMPLE_WIDTH-1:0] frame_sample;
    wire overflow;

    integer errors = 0;
    integer read_order_ok;
    integer marker_ok;
    integer final_overflow_ok;
    integer i;

    sample_block_buffer #(
        .FFT_SIZE(FFT_SIZE),
        .SAMPLE_WIDTH(SAMPLE_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .sample_valid(sample_valid),
        .sample_in(sample_in),
        .consume_frame(consume_frame),
        .frame_ready(frame_ready),
        .frame_valid(frame_valid),
        .frame_start(frame_start),
        .frame_end(frame_end),
        .frame_index(frame_index),
        .frame_sample(frame_sample),
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

    task write_frame;
        input integer base_value;
        begin
            for (i = 0; i < FFT_SIZE; i = i + 1) begin
                @(negedge clk);
                sample_valid = 1'b1;
                sample_in = base_value + i;
            end

            @(negedge clk);
            sample_valid = 1'b0;
            sample_in = 16'sd0;
        end
    endtask

    task read_frame;
        input integer base_value;
        output integer order_ok;
        output integer markers_ok;
        begin
            order_ok = 1;
            markers_ok = 1;

            @(negedge clk);
            consume_frame = 1'b1;

            for (i = 0; i < FFT_SIZE; i = i + 1) begin
                @(posedge clk);
                #1;

                if (frame_valid !== 1'b1) begin
                    order_ok = 0;
                    $display("  read error: frame_valid=0 at index %0d", i);
                end

                if (frame_index !== i[ADDR_WIDTH-1:0]) begin
                    order_ok = 0;
                    $display("  read error: frame_index=%0d expected=%0d",
                             frame_index, i);
                end

                if (frame_sample !== (base_value + i)) begin
                    order_ok = 0;
                    $display("  read error: frame_sample=%0d expected=%0d",
                             frame_sample, base_value + i);
                end

                if ((i == 0) && (frame_start !== 1'b1)) begin
                    markers_ok = 0;
                    $display("  marker error: frame_start was not set at index 0");
                end

                if ((i != 0) && (frame_start !== 1'b0)) begin
                    markers_ok = 0;
                    $display("  marker error: frame_start set at index %0d", i);
                end

                if ((i == FFT_SIZE - 1) && (frame_end !== 1'b1)) begin
                    markers_ok = 0;
                    $display("  marker error: frame_end was not set at last index");
                end

                if ((i != FFT_SIZE - 1) && (frame_end !== 1'b0)) begin
                    markers_ok = 0;
                    $display("  marker error: frame_end set at index %0d", i);
                end

                if (i == 0) begin
                    @(negedge clk);
                    consume_frame = 1'b0;
                end
            end
        end
    endtask

    task read_frame_with_final_overflow;
        input integer base_value;
        output integer order_ok;
        output integer markers_ok;
        output integer overflow_ok;
        begin
            order_ok = 1;
            markers_ok = 1;
            overflow_ok = 0;

            @(negedge clk);
            consume_frame = 1'b1;

            for (i = 0; i < FFT_SIZE; i = i + 1) begin
                if (i == FFT_SIZE - 1) begin
                    @(negedge clk);
                    sample_valid = 1'b1;
                    sample_in = 16'sd12345;
                end

                @(posedge clk);
                #1;

                if (frame_valid !== 1'b1) begin
                    order_ok = 0;
                    $display("  final overflow read error: frame_valid=0 at index %0d", i);
                end

                if (frame_index !== i[ADDR_WIDTH-1:0]) begin
                    order_ok = 0;
                    $display("  final overflow read error: frame_index=%0d expected=%0d",
                             frame_index, i);
                end

                if (frame_sample !== (base_value + i)) begin
                    order_ok = 0;
                    $display("  final overflow read error: frame_sample=%0d expected=%0d",
                             frame_sample, base_value + i);
                end

                if ((i == 0) && (frame_start !== 1'b1)) begin
                    markers_ok = 0;
                    $display("  final overflow marker error: frame_start was not set at index 0");
                end

                if ((i != 0) && (frame_start !== 1'b0)) begin
                    markers_ok = 0;
                    $display("  final overflow marker error: frame_start set at index %0d", i);
                end

                if ((i == FFT_SIZE - 1) && (frame_end !== 1'b1)) begin
                    markers_ok = 0;
                    $display("  final overflow marker error: frame_end was not set at last index");
                end

                if ((i != FFT_SIZE - 1) && (frame_end !== 1'b0)) begin
                    markers_ok = 0;
                    $display("  final overflow marker error: frame_end set at index %0d", i);
                end

                if (i == FFT_SIZE - 1) begin
                    overflow_ok = (overflow === 1'b1);
                    if (!overflow_ok) begin
                        $display("  overflow error: lost final-read sample was not reported");
                    end
                end

                if (i == 0) begin
                    @(negedge clk);
                    consume_frame = 1'b0;
                end
            end

            @(negedge clk);
            sample_valid = 1'b0;
            sample_in = 16'sd0;
        end
    endtask

    initial begin
        $display("=== SAMPLE BLOCK BUFFER TEST ===");
        $display("FFT_SIZE=%0d", FFT_SIZE);
        $display("SAMPLE_WIDTH=%0d", SAMPLE_WIDTH);
        $display("");

        repeat (3) @(posedge clk);
        #1;
        report_result("reset",
                      (frame_ready === 1'b0) &&
                      (frame_valid === 1'b0) &&
                      (overflow === 1'b0));

        @(negedge clk);
        rst = 1'b0;

        write_frame(0);
        report_result("collect_256_samples", frame_ready === 1'b1);
        report_result("frame_ready", frame_ready === 1'b1);

        @(negedge clk);
        sample_valid = 1'b1;
        sample_in = 16'sd9999;
        @(posedge clk);
        #1;
        report_result("overflow", overflow === 1'b1);

        @(negedge clk);
        sample_valid = 1'b0;
        sample_in = 16'sd0;

        read_frame(0, read_order_ok, marker_ok);
        report_result("read_order", read_order_ok);
        report_result("frame_start_end", marker_ok);

        @(posedge clk);
        #1;

        write_frame(1000);
        read_frame(1000, read_order_ok, marker_ok);
        report_result("second_frame", read_order_ok && marker_ok);

        write_frame(2000);
        read_frame_with_final_overflow(2000, read_order_ok, marker_ok, final_overflow_ok);
        report_result("final_read_overflow",
                      read_order_ok && marker_ok && final_overflow_ok);

        $display("");
        if (errors == 0) begin
            $display("STATUS=PASS");
        end else begin
            $display("STATUS=FAIL errors=%0d", errors);
        end

        $finish;
    end

endmodule
