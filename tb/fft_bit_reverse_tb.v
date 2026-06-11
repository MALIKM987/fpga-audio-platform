`timescale 1ns/1ps

module fft_bit_reverse_tb;

    localparam integer INDEX_WIDTH = 8;

    reg [INDEX_WIDTH-1:0] index_in = 8'd255;
    wire [INDEX_WIDTH-1:0] index_out;

    integer errors = 0;

    fft_bit_reverse #(
        .INDEX_WIDTH(INDEX_WIDTH)
    ) dut (
        .index_in(index_in),
        .index_out(index_out)
    );

    task check_case;
        input [INDEX_WIDTH-1:0] test_input;
        input [INDEX_WIDTH-1:0] expected_output;
        input [8*16-1:0] label;
        begin
            index_in = test_input;
            #1;

            if (index_out === expected_output) begin
                $display("TEST %0s input=%0d output=%0d PASS",
                         label, test_input, index_out);
            end else begin
                errors = errors + 1;
                $display("TEST %0s input=%0d FAIL", label, test_input);
                $display("  expected output=%0d actual output=%0d",
                         expected_output, index_out);
            end
        end
    endtask

    initial begin
        $display("=== FFT BIT REVERSE TEST ===");
        $display("INDEX_WIDTH=%0d", INDEX_WIDTH);
        $display("");

        check_case(8'd0,   8'd0,   "0_to_0");
        check_case(8'd1,   8'd128, "1_to_128");
        check_case(8'd2,   8'd64,  "2_to_64");
        check_case(8'd3,   8'd192, "3_to_192");
        check_case(8'd4,   8'd32,  "4_to_32");
        check_case(8'd8,   8'd16,  "8_to_16");
        check_case(8'd15,  8'd240, "15_to_240");
        check_case(8'd16,  8'd8,   "16_to_8");
        check_case(8'd31,  8'd248, "31_to_248");
        check_case(8'd64,  8'd2,   "64_to_2");
        check_case(8'd85,  8'd170, "85_to_170");
        check_case(8'd128, 8'd1,   "128_to_1");
        check_case(8'd170, 8'd85,  "170_to_85");
        check_case(8'd240, 8'd15,  "240_to_15");
        check_case(8'd255, 8'd255, "255_to_255");

        $display("");
        if (errors == 0) begin
            $display("STATUS=PASS");
        end else begin
            $display("STATUS=FAIL errors=%0d", errors);
        end

        $finish;
    end

endmodule
