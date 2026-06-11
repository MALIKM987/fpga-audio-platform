`timescale 1ns/1ps

module fft_butterfly_addr_gen_tb;

    localparam integer FFT_SIZE    = 256;
    localparam integer INDEX_WIDTH = 8;
    localparam integer STAGE_WIDTH = 3;

    reg [STAGE_WIDTH-1:0] stage = 3'd7;
    reg [INDEX_WIDTH-2:0] butterfly_index = 7'd127;

    wire [INDEX_WIDTH-1:0] addr_a;
    wire [INDEX_WIDTH-1:0] addr_b;
    wire [INDEX_WIDTH-1:0] twiddle_index;

    integer errors = 0;

    fft_butterfly_addr_gen #(
        .FFT_SIZE(FFT_SIZE),
        .INDEX_WIDTH(INDEX_WIDTH),
        .STAGE_WIDTH(STAGE_WIDTH)
    ) dut (
        .stage(stage),
        .butterfly_index(butterfly_index),
        .addr_a(addr_a),
        .addr_b(addr_b),
        .twiddle_index(twiddle_index)
    );

    task check_case;
        input [STAGE_WIDTH-1:0] test_stage;
        input [INDEX_WIDTH-2:0] test_butterfly_index;
        input [INDEX_WIDTH-1:0] expected_addr_a;
        input [INDEX_WIDTH-1:0] expected_addr_b;
        input [INDEX_WIDTH-1:0] expected_twiddle_index;
        input [8*32-1:0] label;
        begin
            stage = test_stage;
            butterfly_index = test_butterfly_index;
            #1;

            if ((addr_a === expected_addr_a) &&
                (addr_b === expected_addr_b) &&
                (twiddle_index === expected_twiddle_index)) begin
                $display("TEST %0s stage=%0d butterfly=%0d PASS",
                         label, test_stage, test_butterfly_index);
            end else begin
                errors = errors + 1;
                $display("TEST %0s stage=%0d butterfly=%0d FAIL",
                         label, test_stage, test_butterfly_index);
                $display("  expected addr_a=%0d addr_b=%0d twiddle=%0d",
                         expected_addr_a,
                         expected_addr_b,
                         expected_twiddle_index);
                $display("  actual   addr_a=%0d addr_b=%0d twiddle=%0d",
                         addr_a,
                         addr_b,
                         twiddle_index);
            end
        end
    endtask

    initial begin
        $display("=== FFT BUTTERFLY ADDRESS GENERATOR TEST ===");
        $display("FFT_SIZE=%0d", FFT_SIZE);
        $display("MODE=RADIX2_DIT_ADDRESS_ONLY");
        $display("");

        check_case(3'd0, 7'd0,   8'd0,   8'd1,   8'd0,   "stage0_b0");
        check_case(3'd0, 7'd1,   8'd2,   8'd3,   8'd0,   "stage0_b1");
        check_case(3'd0, 7'd2,   8'd4,   8'd5,   8'd0,   "stage0_b2");
        check_case(3'd0, 7'd127, 8'd254, 8'd255, 8'd0,   "stage0_b127");

        check_case(3'd1, 7'd0,   8'd0,   8'd2,   8'd0,   "stage1_b0");
        check_case(3'd1, 7'd1,   8'd1,   8'd3,   8'd64,  "stage1_b1");
        check_case(3'd1, 7'd2,   8'd4,   8'd6,   8'd0,   "stage1_b2");
        check_case(3'd1, 7'd3,   8'd5,   8'd7,   8'd64,  "stage1_b3");

        check_case(3'd2, 7'd0,   8'd0,   8'd4,   8'd0,   "stage2_b0");
        check_case(3'd2, 7'd1,   8'd1,   8'd5,   8'd32,  "stage2_b1");
        check_case(3'd2, 7'd2,   8'd2,   8'd6,   8'd64,  "stage2_b2");
        check_case(3'd2, 7'd3,   8'd3,   8'd7,   8'd96,  "stage2_b3");
        check_case(3'd2, 7'd4,   8'd8,   8'd12,  8'd0,   "stage2_b4");

        check_case(3'd7, 7'd0,   8'd0,   8'd128, 8'd0,   "stage7_b0");
        check_case(3'd7, 7'd1,   8'd1,   8'd129, 8'd1,   "stage7_b1");
        check_case(3'd7, 7'd64,  8'd64,  8'd192, 8'd64,  "stage7_b64");
        check_case(3'd7, 7'd127, 8'd127, 8'd255, 8'd127, "stage7_b127");

        $display("");
        if (errors == 0) begin
            $display("STATUS=PASS");
        end else begin
            $display("STATUS=FAIL errors=%0d", errors);
        end

        $finish;
    end

endmodule
