// Fixed-point twiddle factor ROM for a future radix-2 FFT/IFFT core.
//
// This module targets N = 256 and exposes twiddle exponents k = 0..127.
// Coefficients use signed Q2.14 format:
//   1.0  ->  16384
//  -1.0  -> -16384
//
// FFT mode uses:
//   W_N^k = cos(2*pi*k/N) - j*sin(2*pi*k/N)
//
// IFFT mode uses the conjugated sign:
//   W_N^-k = cos(2*pi*k/N) + j*sin(2*pi*k/N)
//
// The ROM stores quarter-wave cosine values and derives the first half of the
// unit circle by symmetry. This block is standalone and is not connected to the
// current passthrough FFT/IFFT wrappers yet.

module fft_twiddle_rom #(
    parameter DATA_WIDTH = 16,
    parameter FRAC_BITS = 14
)(
    input  wire [6:0] addr,
    input  wire       inverse,
    output reg signed [DATA_WIDTH-1:0] tw_real,
    output reg signed [DATA_WIDTH-1:0] tw_imag
);

    reg [6:0] mirror_addr;
    reg signed [DATA_WIDTH-1:0] base_real;
    reg signed [DATA_WIDTH-1:0] base_imag;

    // Q2.14 cosine table for angles 2*pi*k/256, k = 0..64.
    // FRAC_BITS is kept as a parameter for interface documentation; this first
    // ROM instance is intentionally generated for the project default Q2.14.
    function signed [DATA_WIDTH-1:0] cos_q14;
        input [6:0] index;
        begin
            case (index)
                7'd0:  cos_q14 = 16'sd16384;
                7'd1:  cos_q14 = 16'sd16379;
                7'd2:  cos_q14 = 16'sd16364;
                7'd3:  cos_q14 = 16'sd16340;
                7'd4:  cos_q14 = 16'sd16305;
                7'd5:  cos_q14 = 16'sd16261;
                7'd6:  cos_q14 = 16'sd16207;
                7'd7:  cos_q14 = 16'sd16143;
                7'd8:  cos_q14 = 16'sd16069;
                7'd9:  cos_q14 = 16'sd15986;
                7'd10: cos_q14 = 16'sd15893;
                7'd11: cos_q14 = 16'sd15791;
                7'd12: cos_q14 = 16'sd15679;
                7'd13: cos_q14 = 16'sd15557;
                7'd14: cos_q14 = 16'sd15426;
                7'd15: cos_q14 = 16'sd15286;
                7'd16: cos_q14 = 16'sd15137;
                7'd17: cos_q14 = 16'sd14978;
                7'd18: cos_q14 = 16'sd14811;
                7'd19: cos_q14 = 16'sd14635;
                7'd20: cos_q14 = 16'sd14449;
                7'd21: cos_q14 = 16'sd14256;
                7'd22: cos_q14 = 16'sd14053;
                7'd23: cos_q14 = 16'sd13842;
                7'd24: cos_q14 = 16'sd13623;
                7'd25: cos_q14 = 16'sd13395;
                7'd26: cos_q14 = 16'sd13160;
                7'd27: cos_q14 = 16'sd12916;
                7'd28: cos_q14 = 16'sd12665;
                7'd29: cos_q14 = 16'sd12406;
                7'd30: cos_q14 = 16'sd12140;
                7'd31: cos_q14 = 16'sd11866;
                7'd32: cos_q14 = 16'sd11585;
                7'd33: cos_q14 = 16'sd11297;
                7'd34: cos_q14 = 16'sd11003;
                7'd35: cos_q14 = 16'sd10702;
                7'd36: cos_q14 = 16'sd10394;
                7'd37: cos_q14 = 16'sd10080;
                7'd38: cos_q14 = 16'sd9760;
                7'd39: cos_q14 = 16'sd9434;
                7'd40: cos_q14 = 16'sd9102;
                7'd41: cos_q14 = 16'sd8765;
                7'd42: cos_q14 = 16'sd8423;
                7'd43: cos_q14 = 16'sd8076;
                7'd44: cos_q14 = 16'sd7723;
                7'd45: cos_q14 = 16'sd7366;
                7'd46: cos_q14 = 16'sd7005;
                7'd47: cos_q14 = 16'sd6639;
                7'd48: cos_q14 = 16'sd6270;
                7'd49: cos_q14 = 16'sd5897;
                7'd50: cos_q14 = 16'sd5520;
                7'd51: cos_q14 = 16'sd5139;
                7'd52: cos_q14 = 16'sd4756;
                7'd53: cos_q14 = 16'sd4370;
                7'd54: cos_q14 = 16'sd3981;
                7'd55: cos_q14 = 16'sd3590;
                7'd56: cos_q14 = 16'sd3196;
                7'd57: cos_q14 = 16'sd2801;
                7'd58: cos_q14 = 16'sd2404;
                7'd59: cos_q14 = 16'sd2006;
                7'd60: cos_q14 = 16'sd1606;
                7'd61: cos_q14 = 16'sd1205;
                7'd62: cos_q14 = 16'sd804;
                7'd63: cos_q14 = 16'sd402;
                7'd64: cos_q14 = 16'sd0;
                default: cos_q14 = 16'sd0;
            endcase
        end
    endfunction

    always @* begin
        if (addr <= 7'd64) begin
            mirror_addr = addr;
            base_real = cos_q14(addr);
            base_imag = -cos_q14(7'd64 - addr);
        end else begin
            mirror_addr = 8'd128 - {1'b0, addr};
            base_real = -cos_q14(mirror_addr);
            base_imag = -cos_q14(7'd64 - mirror_addr);
        end

        tw_real = base_real;
        if (inverse) begin
            tw_imag = -base_imag;
        end else begin
            tw_imag = base_imag;
        end
    end

endmodule
