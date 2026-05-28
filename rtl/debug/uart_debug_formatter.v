module uart_debug_formatter (
    input  wire clk,
    input  wire rst,
    input  wire report_valid,
    input  wire [2:0] mode,
    input  wire [3:0] volume_gain,
    input  wire signed [4:0] bass_gain,
    input  wire signed [4:0] mid_gain,
    input  wire signed [4:0] treble_gain,
    input  wire signed [15:0] in_min,
    input  wire signed [15:0] in_max,
    input  wire signed [15:0] out_min,
    input  wire signed [15:0] out_max,
    input  wire clip_seen,
    input  wire uart_busy,
    output reg  [7:0] uart_data,
    output reg  uart_valid
);

    localparam [5:0] SEG_IDLE       = 6'd0;
    localparam [5:0] SEG_START      = 6'd1;
    localparam [5:0] SEG_MODE_L     = 6'd2;
    localparam [5:0] SEG_MODE_V     = 6'd3;
    localparam [5:0] SEG_VOL_L      = 6'd4;
    localparam [5:0] SEG_VOL_V      = 6'd5;
    localparam [5:0] SEG_BASS_L     = 6'd6;
    localparam [5:0] SEG_BASS_V     = 6'd7;
    localparam [5:0] SEG_MID_L      = 6'd8;
    localparam [5:0] SEG_MID_V      = 6'd9;
    localparam [5:0] SEG_TREBLE_L   = 6'd10;
    localparam [5:0] SEG_TREBLE_V   = 6'd11;
    localparam [5:0] SEG_IN_MIN_L   = 6'd12;
    localparam [5:0] SEG_IN_MIN_V   = 6'd13;
    localparam [5:0] SEG_IN_MAX_L   = 6'd14;
    localparam [5:0] SEG_IN_MAX_V   = 6'd15;
    localparam [5:0] SEG_OUT_MIN_L  = 6'd16;
    localparam [5:0] SEG_OUT_MIN_V  = 6'd17;
    localparam [5:0] SEG_OUT_MAX_L  = 6'd18;
    localparam [5:0] SEG_OUT_MAX_V  = 6'd19;
    localparam [5:0] SEG_CLIP_L     = 6'd20;
    localparam [5:0] SEG_CLIP_V     = 6'd21;
    localparam [5:0] SEG_EOL        = 6'd22;

    reg [5:0] segment;
    reg [5:0] char_index;
    reg holding_char;

    reg [2:0] mode_reg;
    reg [3:0] volume_reg;
    reg signed [4:0] bass_reg;
    reg signed [4:0] mid_reg;
    reg signed [4:0] treble_reg;
    reg signed [15:0] in_min_reg;
    reg signed [15:0] in_max_reg;
    reg signed [15:0] out_min_reg;
    reg signed [15:0] out_max_reg;
    reg clip_reg;

    function [7:0] hex_char;
        input [3:0] value;
        begin
            if (value < 4'd10) begin
                hex_char = 8'h30 + value;
            end else begin
                hex_char = 8'h41 + (value - 4'd10);
            end
        end
    endfunction

    function [7:0] start_char;
        input [5:0] idx;
        begin
            case (idx)
                6'd0:  start_char = "T";
                6'd1:  start_char = "A";
                6'd2:  start_char = "N";
                6'd3:  start_char = "G";
                6'd4:  start_char = " ";
                6'd5:  start_char = "A";
                6'd6:  start_char = "U";
                6'd7:  start_char = "D";
                6'd8:  start_char = "I";
                6'd9:  start_char = "O";
                6'd10: start_char = " ";
                6'd11: start_char = "S";
                6'd12: start_char = "E";
                6'd13: start_char = "L";
                6'd14: start_char = "F";
                6'd15: start_char = "T";
                6'd16: start_char = "E";
                6'd17: start_char = "S";
                6'd18: start_char = "T";
                6'd19: start_char = " ";
                6'd20: start_char = "S";
                6'd21: start_char = "T";
                6'd22: start_char = "A";
                6'd23: start_char = "R";
                6'd24: start_char = "T";
                6'd25: start_char = 8'h0d;
                default: start_char = 8'h0a;
            endcase
        end
    endfunction

    function [7:0] label_char;
        input [5:0] seg;
        input [5:0] idx;
        begin
            case (seg)
                SEG_MODE_L: begin
                    case (idx)
                        6'd0: label_char = "M";
                        6'd1: label_char = "O";
                        6'd2: label_char = "D";
                        6'd3: label_char = "E";
                        default: label_char = "=";
                    endcase
                end
                SEG_VOL_L: begin
                    case (idx)
                        6'd0: label_char = " ";
                        6'd1: label_char = "V";
                        6'd2: label_char = "O";
                        6'd3: label_char = "L";
                        default: label_char = "=";
                    endcase
                end
                SEG_BASS_L: begin
                    case (idx)
                        6'd0: label_char = " ";
                        6'd1: label_char = "B";
                        6'd2: label_char = "A";
                        6'd3: label_char = "S";
                        6'd4: label_char = "S";
                        default: label_char = "=";
                    endcase
                end
                SEG_MID_L: begin
                    case (idx)
                        6'd0: label_char = " ";
                        6'd1: label_char = "M";
                        6'd2: label_char = "I";
                        6'd3: label_char = "D";
                        default: label_char = "=";
                    endcase
                end
                SEG_TREBLE_L: begin
                    case (idx)
                        6'd0: label_char = " ";
                        6'd1: label_char = "T";
                        6'd2: label_char = "R";
                        6'd3: label_char = "E";
                        6'd4: label_char = "B";
                        6'd5: label_char = "L";
                        6'd6: label_char = "E";
                        default: label_char = "=";
                    endcase
                end
                SEG_IN_MIN_L: begin
                    case (idx)
                        6'd0: label_char = " ";
                        6'd1: label_char = "I";
                        6'd2: label_char = "N";
                        6'd3: label_char = "_";
                        6'd4: label_char = "M";
                        6'd5: label_char = "I";
                        6'd6: label_char = "N";
                        6'd7: label_char = "=";
                        6'd8: label_char = "0";
                        default: label_char = "x";
                    endcase
                end
                SEG_IN_MAX_L: begin
                    case (idx)
                        6'd0: label_char = " ";
                        6'd1: label_char = "I";
                        6'd2: label_char = "N";
                        6'd3: label_char = "_";
                        6'd4: label_char = "M";
                        6'd5: label_char = "A";
                        6'd6: label_char = "X";
                        6'd7: label_char = "=";
                        6'd8: label_char = "0";
                        default: label_char = "x";
                    endcase
                end
                SEG_OUT_MIN_L: begin
                    case (idx)
                        6'd0: label_char = " ";
                        6'd1: label_char = "O";
                        6'd2: label_char = "U";
                        6'd3: label_char = "T";
                        6'd4: label_char = "_";
                        6'd5: label_char = "M";
                        6'd6: label_char = "I";
                        6'd7: label_char = "N";
                        6'd8: label_char = "=";
                        6'd9: label_char = "0";
                        default: label_char = "x";
                    endcase
                end
                SEG_OUT_MAX_L: begin
                    case (idx)
                        6'd0: label_char = " ";
                        6'd1: label_char = "O";
                        6'd2: label_char = "U";
                        6'd3: label_char = "T";
                        6'd4: label_char = "_";
                        6'd5: label_char = "M";
                        6'd6: label_char = "A";
                        6'd7: label_char = "X";
                        6'd8: label_char = "=";
                        6'd9: label_char = "0";
                        default: label_char = "x";
                    endcase
                end
                SEG_CLIP_L: begin
                    case (idx)
                        6'd0: label_char = " ";
                        6'd1: label_char = "C";
                        6'd2: label_char = "L";
                        6'd3: label_char = "I";
                        6'd4: label_char = "P";
                        default: label_char = "=";
                    endcase
                end
                default: label_char = " ";
            endcase
        end
    endfunction

    function [5:0] segment_len;
        input [5:0] seg;
        begin
            case (seg)
                SEG_START:     segment_len = 6'd27;
                SEG_MODE_L:    segment_len = 6'd5;
                SEG_MODE_V:    segment_len = 6'd1;
                SEG_VOL_L:     segment_len = 6'd5;
                SEG_VOL_V:     segment_len = 6'd2;
                SEG_BASS_L:    segment_len = 6'd6;
                SEG_BASS_V:    segment_len = 6'd2;
                SEG_MID_L:     segment_len = 6'd5;
                SEG_MID_V:     segment_len = 6'd2;
                SEG_TREBLE_L:  segment_len = 6'd8;
                SEG_TREBLE_V:  segment_len = 6'd2;
                SEG_IN_MIN_L:  segment_len = 6'd10;
                SEG_IN_MIN_V:  segment_len = 6'd4;
                SEG_IN_MAX_L:  segment_len = 6'd10;
                SEG_IN_MAX_V:  segment_len = 6'd4;
                SEG_OUT_MIN_L: segment_len = 6'd11;
                SEG_OUT_MIN_V: segment_len = 6'd4;
                SEG_OUT_MAX_L: segment_len = 6'd11;
                SEG_OUT_MAX_V: segment_len = 6'd4;
                SEG_CLIP_L:    segment_len = 6'd6;
                SEG_CLIP_V:    segment_len = 6'd1;
                SEG_EOL:       segment_len = 6'd2;
                default:       segment_len = 6'd1;
            endcase
        end
    endfunction

    function [5:0] next_segment;
        input [5:0] seg;
        begin
            case (seg)
                SEG_START:     next_segment = SEG_IDLE;
                SEG_MODE_L:    next_segment = SEG_MODE_V;
                SEG_MODE_V:    next_segment = SEG_VOL_L;
                SEG_VOL_L:     next_segment = SEG_VOL_V;
                SEG_VOL_V:     next_segment = SEG_BASS_L;
                SEG_BASS_L:    next_segment = SEG_BASS_V;
                SEG_BASS_V:    next_segment = SEG_MID_L;
                SEG_MID_L:     next_segment = SEG_MID_V;
                SEG_MID_V:     next_segment = SEG_TREBLE_L;
                SEG_TREBLE_L:  next_segment = SEG_TREBLE_V;
                SEG_TREBLE_V:  next_segment = SEG_IN_MIN_L;
                SEG_IN_MIN_L:  next_segment = SEG_IN_MIN_V;
                SEG_IN_MIN_V:  next_segment = SEG_IN_MAX_L;
                SEG_IN_MAX_L:  next_segment = SEG_IN_MAX_V;
                SEG_IN_MAX_V:  next_segment = SEG_OUT_MIN_L;
                SEG_OUT_MIN_L: next_segment = SEG_OUT_MIN_V;
                SEG_OUT_MIN_V: next_segment = SEG_OUT_MAX_L;
                SEG_OUT_MAX_L: next_segment = SEG_OUT_MAX_V;
                SEG_OUT_MAX_V: next_segment = SEG_CLIP_L;
                SEG_CLIP_L:    next_segment = SEG_CLIP_V;
                SEG_CLIP_V:    next_segment = SEG_EOL;
                SEG_EOL:       next_segment = SEG_IDLE;
                default:       next_segment = SEG_IDLE;
            endcase
        end
    endfunction

    function [7:0] gain_char;
        input signed [4:0] value;
        input [0:0] sign_pos;
        reg signed [4:0] abs_value;
        begin
            abs_value = (value < 0) ? -value : value;
            if (sign_pos) begin
                gain_char = (value < 0) ? "-" : "+";
            end else begin
                gain_char = 8'h30 + abs_value[3:0];
            end
        end
    endfunction

    function [7:0] value_char;
        input [5:0] seg;
        input [5:0] idx;
        begin
            case (seg)
                SEG_MODE_V: value_char = 8'h30 + {1'b0, mode_reg};
                SEG_VOL_V: begin
                    if (idx == 0) begin
                        value_char = (volume_reg >= 4'd10) ? "1" : "0";
                    end else begin
                        value_char = 8'h30 + ((volume_reg >= 4'd10) ? (volume_reg - 4'd10) : volume_reg);
                    end
                end
                SEG_BASS_V:   value_char = gain_char(bass_reg, idx == 0);
                SEG_MID_V:    value_char = gain_char(mid_reg, idx == 0);
                SEG_TREBLE_V: value_char = gain_char(treble_reg, idx == 0);
                SEG_IN_MIN_V:  value_char = hex_char(in_min_reg[15 - idx*4 -: 4]);
                SEG_IN_MAX_V:  value_char = hex_char(in_max_reg[15 - idx*4 -: 4]);
                SEG_OUT_MIN_V: value_char = hex_char(out_min_reg[15 - idx*4 -: 4]);
                SEG_OUT_MAX_V: value_char = hex_char(out_max_reg[15 - idx*4 -: 4]);
                SEG_CLIP_V:    value_char = clip_reg ? "1" : "0";
                SEG_EOL:       value_char = (idx == 0) ? 8'h0d : 8'h0a;
                default:       value_char = " ";
            endcase
        end
    endfunction

    function [7:0] current_char;
        input [5:0] seg;
        input [5:0] idx;
        begin
            if (seg == SEG_START) begin
                current_char = start_char(idx);
            end else if (seg == SEG_MODE_V || seg == SEG_VOL_V ||
                         seg == SEG_BASS_V || seg == SEG_MID_V ||
                         seg == SEG_TREBLE_V || seg == SEG_IN_MIN_V ||
                         seg == SEG_IN_MAX_V || seg == SEG_OUT_MIN_V ||
                         seg == SEG_OUT_MAX_V || seg == SEG_CLIP_V ||
                         seg == SEG_EOL) begin
                current_char = value_char(seg, idx);
            end else begin
                current_char = label_char(seg, idx);
            end
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            segment      <= SEG_START;
            char_index   <= 6'd0;
            holding_char <= 1'b0;
            uart_data    <= 8'h00;
            uart_valid   <= 1'b0;
            mode_reg     <= 3'd0;
            volume_reg   <= 4'd8;
            bass_reg     <= 5'sd0;
            mid_reg      <= 5'sd0;
            treble_reg   <= 5'sd0;
            in_min_reg   <= 16'sd0;
            in_max_reg   <= 16'sd0;
            out_min_reg  <= 16'sd0;
            out_max_reg  <= 16'sd0;
            clip_reg     <= 1'b0;
        end else begin
            uart_valid <= 1'b0;

            if (segment == SEG_IDLE) begin
                char_index <= 6'd0;
                holding_char <= 1'b0;
                if (report_valid) begin
                    mode_reg    <= mode;
                    volume_reg  <= volume_gain;
                    bass_reg    <= bass_gain;
                    mid_reg     <= mid_gain;
                    treble_reg  <= treble_gain;
                    in_min_reg  <= in_min;
                    in_max_reg  <= in_max;
                    out_min_reg <= out_min;
                    out_max_reg <= out_max;
                    clip_reg    <= clip_seen;
                    segment     <= SEG_MODE_L;
                end
            end else if (!holding_char) begin
                if (!uart_busy) begin
                    uart_data    <= current_char(segment, char_index);
                    uart_valid   <= 1'b1;
                    holding_char <= 1'b1;
                end
            end else begin
                if (uart_busy) begin
                    uart_valid   <= 1'b0;
                    holding_char <= 1'b0;

                    if (char_index == segment_len(segment) - 1) begin
                        segment    <= next_segment(segment);
                        char_index <= 6'd0;
                    end else begin
                        char_index <= char_index + 6'd1;
                    end
                end else begin
                    uart_valid <= 1'b1;
                end
            end
        end
    end

endmodule
