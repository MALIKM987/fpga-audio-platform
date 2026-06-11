`timescale 1ns/1ps

module fft_twiddle_rom_tb;

    localparam integer DATA_WIDTH = 16;
    localparam integer FRAC_BITS  = 14;

    reg [6:0] addr = 7'd127;
    reg inverse = 1'b1;

    wire signed [DATA_WIDTH-1:0] tw_real;
    wire signed [DATA_WIDTH-1:0] tw_imag;

    integer errors = 0;

    fft_twiddle_rom #(
        .DATA_WIDTH(DATA_WIDTH),
        .FRAC_BITS(FRAC_BITS)
    ) dut (
        .addr(addr),
        .inverse(inverse),
        .tw_real(tw_real),
        .tw_imag(tw_imag)
    );

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

    task check_twiddle;
        input [6:0] test_addr;
        input signed [DATA_WIDTH-1:0] expected_real;
        input signed [DATA_WIDTH-1:0] expected_fft_imag;
        input [8*16-1:0] label;
        reg signed [DATA_WIDTH-1:0] expected_ifft_imag;
        reg signed [DATA_WIDTH-1:0] fft_real_seen;
        reg signed [DATA_WIDTH-1:0] fft_imag_seen;
        reg fft_ok;
        reg ifft_ok;
        reg inverse_sign_ok;
        begin
            expected_ifft_imag = -expected_fft_imag;

            addr = test_addr;
            inverse = 1'b0;
            #1;
            fft_real_seen = tw_real;
            fft_imag_seen = tw_imag;
            fft_ok = ((tw_real === expected_real) &&
                      (tw_imag === expected_fft_imag));
            if (!fft_ok) begin
                $display("  %0s FFT expected real=%0d imag=%0d actual real=%0d imag=%0d",
                         label, expected_real, expected_fft_imag, tw_real, tw_imag);
            end
            report_result({label, " FFT"}, fft_ok);

            inverse = 1'b1;
            #1;
            ifft_ok = ((tw_real === expected_real) &&
                       (tw_imag === expected_ifft_imag));
            if (!ifft_ok) begin
                $display("  %0s IFFT expected real=%0d imag=%0d actual real=%0d imag=%0d",
                         label, expected_real, expected_ifft_imag, tw_real, tw_imag);
            end
            report_result({label, " IFFT"}, ifft_ok);

            inverse_sign_ok = ((tw_real === fft_real_seen) &&
                               (tw_imag === -fft_imag_seen));
            report_result({label, " inverse_sign"}, inverse_sign_ok);
        end
    endtask

    initial begin
        $display("=== FFT TWIDDLE ROM TEST ===");
        $display("FFT_SIZE=256");
        $display("TWIDDLE_FORMAT=Q2.14");
        $display("");

        check_twiddle(7'd0,  16'sd16384,  16'sd0,      "k=0");
        check_twiddle(7'd32, 16'sd11585, -16'sd11585,  "k=32");
        check_twiddle(7'd64, 16'sd0,     -16'sd16384,  "k=64");
        check_twiddle(7'd96, -16'sd11585, -16'sd11585, "k=96");

        $display("");
        if (errors == 0) begin
            $display("STATUS=PASS");
        end else begin
            $display("STATUS=FAIL errors=%0d", errors);
        end

        $finish;
    end

endmodule
