`timescale 1ns/1ps

module complex_mult_tb;

    localparam integer DATA_WIDTH = 16;
    localparam integer FRAC_BITS  = 14;

    localparam signed [DATA_WIDTH-1:0] Q_ZERO    = 16'sd0;
    localparam signed [DATA_WIDTH-1:0] Q_ONE     = 16'sd16384;
    localparam signed [DATA_WIDTH-1:0] Q_NEG_ONE = -16'sd16384;
    localparam signed [DATA_WIDTH-1:0] Q_1_50    = 16'sd24576;
    localparam signed [DATA_WIDTH-1:0] Q_HALF    = 16'sd8192;
    localparam signed [DATA_WIDTH-1:0] Q_NEG_HALF = -16'sd8192;
    localparam signed [DATA_WIDTH-1:0] Q_QUARTER = 16'sd4096;
    localparam signed [DATA_WIDTH-1:0] Q_NEG_QUARTER = -16'sd4096;
    localparam signed [DATA_WIDTH-1:0] INT_MAX   = 16'sd32767;
    localparam signed [DATA_WIDTH-1:0] INT_MIN   = -16'sd32768;

    reg signed [DATA_WIDTH-1:0] a_real = 16'sd123;
    reg signed [DATA_WIDTH-1:0] a_imag = -16'sd456;
    reg signed [DATA_WIDTH-1:0] b_real = 16'sd789;
    reg signed [DATA_WIDTH-1:0] b_imag = -16'sd321;

    wire signed [DATA_WIDTH-1:0] out_real;
    wire signed [DATA_WIDTH-1:0] out_imag;

    integer errors = 0;

    complex_mult #(
        .DATA_WIDTH(DATA_WIDTH),
        .FRAC_BITS(FRAC_BITS)
    ) dut (
        .a_real(a_real),
        .a_imag(a_imag),
        .b_real(b_real),
        .b_imag(b_imag),
        .out_real(out_real),
        .out_imag(out_imag)
    );

    task run_case;
        input [8*32-1:0] name;
        input signed [DATA_WIDTH-1:0] test_a_real;
        input signed [DATA_WIDTH-1:0] test_a_imag;
        input signed [DATA_WIDTH-1:0] test_b_real;
        input signed [DATA_WIDTH-1:0] test_b_imag;
        input signed [DATA_WIDTH-1:0] expected_real;
        input signed [DATA_WIDTH-1:0] expected_imag;
        reg pass;
        begin
            a_real = test_a_real;
            a_imag = test_a_imag;
            b_real = test_b_real;
            b_imag = test_b_imag;
            #1;

            pass = ((out_real === expected_real) &&
                    (out_imag === expected_imag));

            if (pass) begin
                $display("TEST %0s real=%0d imag=%0d PASS",
                         name, out_real, out_imag);
            end else begin
                errors = errors + 1;
                $display("TEST %0s FAIL", name);
                $display("  expected real=%0d imag=%0d",
                         expected_real, expected_imag);
                $display("  actual   real=%0d imag=%0d",
                         out_real, out_imag);
            end
        end
    endtask

    function signed [DATA_WIDTH-1:0] saturate_q14;
        input signed [(2*DATA_WIDTH):0] value;
        begin
            if (value > INT_MAX) begin
                saturate_q14 = INT_MAX;
            end else if (value < INT_MIN) begin
                saturate_q14 = INT_MIN;
            end else begin
                saturate_q14 = value[DATA_WIDTH-1:0];
            end
        end
    endfunction

    function signed [DATA_WIDTH-1:0] expected_real_q14;
        input signed [DATA_WIDTH-1:0] in_a_real;
        input signed [DATA_WIDTH-1:0] in_a_imag;
        input signed [DATA_WIDTH-1:0] in_b_real;
        input signed [DATA_WIDTH-1:0] in_b_imag;
        reg signed [(2*DATA_WIDTH):0] full_value;
        begin
            full_value = (in_a_real * in_b_real) -
                         (in_a_imag * in_b_imag);
            expected_real_q14 = saturate_q14(full_value >>> FRAC_BITS);
        end
    endfunction

    function signed [DATA_WIDTH-1:0] expected_imag_q14;
        input signed [DATA_WIDTH-1:0] in_a_real;
        input signed [DATA_WIDTH-1:0] in_a_imag;
        input signed [DATA_WIDTH-1:0] in_b_real;
        input signed [DATA_WIDTH-1:0] in_b_imag;
        reg signed [(2*DATA_WIDTH):0] full_value;
        begin
            full_value = (in_a_real * in_b_imag) +
                         (in_a_imag * in_b_real);
            expected_imag_q14 = saturate_q14(full_value >>> FRAC_BITS);
        end
    endfunction

    initial begin
        $display("=== COMPLEX MULT TEST ===");
        $display("FORMAT=Q2.14");
        $display("MODE=COMBINATIONAL_WITH_SATURATION");
        $display("");

        run_case("multiply_by_one",
                 Q_HALF, Q_QUARTER,
                 Q_ONE, Q_ZERO,
                 Q_HALF, Q_QUARTER);

        run_case("multiply_by_j",
                 Q_HALF, Q_QUARTER,
                 Q_ZERO, Q_ONE,
                 Q_NEG_QUARTER, Q_HALF);

        run_case("multiply_by_minus_one",
                 Q_HALF, Q_NEG_QUARTER,
                 Q_NEG_ONE, Q_ZERO,
                 Q_NEG_HALF, Q_QUARTER);

        run_case("non_trivial_conjugate",
                 Q_HALF, Q_HALF,
                 Q_HALF, Q_NEG_HALF,
                 Q_HALF, Q_ZERO);

        run_case("multiply_by_zero",
                 16'sd12288, -16'sd6144,
                 Q_ZERO, Q_ZERO,
                 Q_ZERO, Q_ZERO);

        run_case("signed_formula_check",
                 Q_NEG_HALF, Q_QUARTER,
                 Q_HALF, Q_QUARTER,
                 expected_real_q14(Q_NEG_HALF, Q_QUARTER,
                                   Q_HALF, Q_QUARTER),
                 expected_imag_q14(Q_NEG_HALF, Q_QUARTER,
                                   Q_HALF, Q_QUARTER));

        run_case("positive_saturation",
                 INT_MAX, Q_ZERO,
                 Q_1_50, Q_ZERO,
                 INT_MAX, Q_ZERO);

        run_case("negative_saturation",
                 INT_MIN, Q_ZERO,
                 Q_1_50, Q_ZERO,
                 INT_MIN, Q_ZERO);

        $display("");
        if (errors == 0) begin
            $display("STATUS=PASS");
        end else begin
            $display("STATUS=FAIL errors=%0d", errors);
        end

        $finish;
    end

endmodule
