`include "rtl/cpu/mini_cpu_defs.vh"

module mini_cpu_program_rom #(
    parameter integer PROGRAM_ID = `MINI_CPU_PROGRAM_FETCH_HALT,
    parameter integer ADDR_WIDTH = 16,
    parameter integer DATA_WIDTH = 16
) (
    input  wire [ADDR_WIDTH-1:0] addr,
    output reg  [DATA_WIDTH-1:0] data
);

    function [15:0] enc_reg;
        input [3:0] opcode;
        input [2:0] rd;
        input [2:0] rs;
        begin
            enc_reg = {opcode, rd, rs, 6'd0};
        end
    endfunction

    function [15:0] enc_imm;
        input [3:0] opcode;
        input [2:0] rd;
        begin
            enc_imm = {opcode, rd, 9'd0};
        end
    endfunction

    function [15:0] enc_jump;
        input [3:0] opcode;
        begin
            enc_jump = {opcode, 12'd0};
        end
    endfunction

    localparam [15:0] UART_FRAME_COPY_IN_BASE  = 16'd31;
    localparam [15:0] UART_FRAME_START_ADDR    = 16'd1055;
    localparam [15:0] UART_FRAME_POLL_ADDR     = 16'd1059;
    localparam [15:0] UART_FRAME_COPY_OUT_BASE = 16'd1073;
    localparam [15:0] UART_FRAME_SUCCESS_ADDR  = 16'd2097;
    localparam [15:0] UART_FRAME_ERROR_ADDR    = 16'd2110;

    always @* begin
        data = enc_reg(`MINI_CPU_OP_NOP, 3'd0, 3'd0);

        case (PROGRAM_ID)
            `MINI_CPU_PROGRAM_FETCH_HALT: begin
                case (addr)
                    16'd0: data = enc_reg(`MINI_CPU_OP_NOP, 3'd0, 3'd0);
                    16'd1: data = enc_reg(`MINI_CPU_OP_NOP, 3'd0, 3'd0);
                    16'd2: data = enc_reg(`MINI_CPU_OP_HALT, 3'd0, 3'd0);
                    default: data = enc_reg(`MINI_CPU_OP_NOP, 3'd0, 3'd0);
                endcase
            end

            `MINI_CPU_PROGRAM_ALU: begin
                case (addr)
                    16'd0:  data = enc_imm(`MINI_CPU_OP_LDI, 3'd0);
                    16'd1:  data = 16'd5;
                    16'd2:  data = enc_imm(`MINI_CPU_OP_ADDI, 3'd0);
                    16'd3:  data = 16'd3;
                    16'd4:  data = enc_imm(`MINI_CPU_OP_LDI, 3'd1);
                    16'd5:  data = 16'd2;
                    16'd6:  data = enc_imm(`MINI_CPU_OP_LDI, 3'd2);
                    16'd7:  data = 16'd8;
                    16'd8:  data = enc_reg(`MINI_CPU_OP_ADD, 3'd2, 3'd1);
                    16'd9:  data = enc_imm(`MINI_CPU_OP_LDI, 3'd3);
                    16'd10: data = 16'd8;
                    16'd11: data = enc_reg(`MINI_CPU_OP_SUB, 3'd3, 3'd1);
                    16'd12: data = enc_imm(`MINI_CPU_OP_LDI, 3'd4);
                    16'd13: data = 16'd8;
                    16'd14: data = enc_reg(`MINI_CPU_OP_AND, 3'd4, 3'd1);
                    16'd15: data = enc_reg(`MINI_CPU_OP_CMP, 3'd4, 3'd4);
                    16'd16: data = enc_reg(`MINI_CPU_OP_HALT, 3'd0, 3'd0);
                    default: data = enc_reg(`MINI_CPU_OP_NOP, 3'd0, 3'd0);
                endcase
            end

            `MINI_CPU_PROGRAM_BRANCH: begin
                case (addr)
                    16'd0:  data = enc_imm(`MINI_CPU_OP_LDI, 3'd0);
                    16'd1:  data = 16'd0;
                    16'd2:  data = enc_jump(`MINI_CPU_OP_JZ);
                    16'd3:  data = 16'd6;
                    16'd4:  data = enc_imm(`MINI_CPU_OP_LDI, 3'd1);
                    16'd5:  data = 16'h0BAD;
                    16'd6:  data = enc_imm(`MINI_CPU_OP_LDI, 3'd1);
                    16'd7:  data = 16'h1111;
                    16'd8:  data = enc_imm(`MINI_CPU_OP_LDI, 3'd2);
                    16'd9:  data = 16'd1;
                    16'd10: data = enc_jump(`MINI_CPU_OP_JZ);
                    16'd11: data = 16'd14;
                    16'd12: data = enc_imm(`MINI_CPU_OP_LDI, 3'd3);
                    16'd13: data = 16'h2222;
                    16'd14: data = enc_jump(`MINI_CPU_OP_JNZ);
                    16'd15: data = 16'd18;
                    16'd16: data = enc_imm(`MINI_CPU_OP_LDI, 3'd3);
                    16'd17: data = 16'h0BAD;
                    16'd18: data = enc_imm(`MINI_CPU_OP_LDI, 3'd4);
                    16'd19: data = 16'd0;
                    16'd20: data = enc_jump(`MINI_CPU_OP_JNZ);
                    16'd21: data = 16'd24;
                    16'd22: data = enc_imm(`MINI_CPU_OP_LDI, 3'd5);
                    16'd23: data = 16'h5555;
                    16'd24: data = enc_jump(`MINI_CPU_OP_JMP);
                    16'd25: data = 16'd28;
                    16'd26: data = enc_imm(`MINI_CPU_OP_LDI, 3'd5);
                    16'd27: data = 16'h0BAD;
                    16'd28: data = enc_reg(`MINI_CPU_OP_HALT, 3'd0, 3'd0);
                    default: data = enc_reg(`MINI_CPU_OP_NOP, 3'd0, 3'd0);
                endcase
            end

            `MINI_CPU_PROGRAM_MMIO: begin
                case (addr)
                    16'd0:  data = enc_imm(`MINI_CPU_OP_LDI, 3'd0);
                    16'd1:  data = 16'h1234;
                    16'd2:  data = enc_imm(`MINI_CPU_OP_ST, 3'd0);
                    16'd3:  data = 16'h8010;
                    16'd4:  data = enc_imm(`MINI_CPU_OP_LD, 3'd1);
                    16'd5:  data = 16'h8010;
                    16'd6:  data = enc_imm(`MINI_CPU_OP_LDI, 3'd2);
                    16'd7:  data = 16'd1;
                    16'd8:  data = enc_reg(`MINI_CPU_OP_ADD, 3'd1, 3'd2);
                    16'd9:  data = enc_imm(`MINI_CPU_OP_ST, 3'd1);
                    16'd10: data = 16'h8012;
                    16'd11: data = enc_reg(`MINI_CPU_OP_HALT, 3'd0, 3'd0);
                    default: data = enc_reg(`MINI_CPU_OP_NOP, 3'd0, 3'd0);
                endcase
            end

            `MINI_CPU_PROGRAM_GPIO: begin
                case (addr)
                    16'd0: data = enc_imm(`MINI_CPU_OP_LDI, 3'd0);
                    16'd1: data = 16'h00A5;
                    16'd2: data = enc_imm(`MINI_CPU_OP_ST, 3'd0);
                    16'd3: data = 16'h8000;
                    16'd4: data = enc_reg(`MINI_CPU_OP_HALT, 3'd0, 3'd0);
                    default: data = enc_reg(`MINI_CPU_OP_NOP, 3'd0, 3'd0);
                endcase
            end

            `MINI_CPU_PROGRAM_FFT_IMPULSE: begin
                case (addr)
                    16'd0:   data = enc_imm(`MINI_CPU_OP_LDI, 3'd0);
                    16'd1:   data = 16'h0002;
                    16'd2:   data = enc_imm(`MINI_CPU_OP_ST, 3'd0);
                    16'd3:   data = 16'h9000;

                    16'd4:   data = enc_imm(`MINI_CPU_OP_LDI, 3'd0);
                    16'd5:   data = 16'd16384;
                    16'd6:   data = enc_imm(`MINI_CPU_OP_ST, 3'd0);
                    16'd7:   data = 16'h9003;
                    16'd8:   data = enc_imm(`MINI_CPU_OP_ST, 3'd0);
                    16'd9:   data = 16'h9004;
                    16'd10:  data = enc_imm(`MINI_CPU_OP_ST, 3'd0);
                    16'd11:  data = 16'h9005;

                    16'd12:  data = enc_imm(`MINI_CPU_OP_LDI, 3'd0);
                    16'd13:  data = 16'd64;
                    16'd14:  data = enc_imm(`MINI_CPU_OP_ST, 3'd0);
                    16'd15:  data = 16'h9100;
                    16'd16:  data = enc_imm(`MINI_CPU_OP_LDI, 3'd0);
                    16'd17:  data = 16'd0;

                    16'd528: data = enc_imm(`MINI_CPU_OP_LDI, 3'd0);
                    16'd529: data = 16'h0001;
                    16'd530: data = enc_imm(`MINI_CPU_OP_ST, 3'd0);
                    16'd531: data = 16'h9000;

                    16'd532: data = enc_imm(`MINI_CPU_OP_LD, 3'd1);
                    16'd533: data = 16'h9001;
                    16'd534: data = enc_imm(`MINI_CPU_OP_LDI, 3'd2);
                    16'd535: data = 16'h0002;
                    16'd536: data = enc_reg(`MINI_CPU_OP_AND, 3'd1, 3'd2);
                    16'd537: data = enc_jump(`MINI_CPU_OP_JZ);
                    16'd538: data = 16'd532;

                    16'd539: data = enc_imm(`MINI_CPU_OP_LD, 3'd3);
                    16'd540: data = 16'h9001;
                    16'd541: data = enc_imm(`MINI_CPU_OP_LDI, 3'd2);
                    16'd542: data = 16'h000C;
                    16'd543: data = enc_reg(`MINI_CPU_OP_AND, 3'd3, 3'd2);
                    16'd544: data = enc_jump(`MINI_CPU_OP_JNZ);
                    16'd545: data = 16'd579;

                    16'd546: data = enc_imm(`MINI_CPU_OP_LD, 3'd0);
                    16'd547: data = 16'h9200;
                    16'd548: data = enc_imm(`MINI_CPU_OP_ST, 3'd0);
                    16'd549: data = 16'h8010;
                    16'd550: data = enc_imm(`MINI_CPU_OP_LD, 3'd0);
                    16'd551: data = 16'h9201;
                    16'd552: data = enc_imm(`MINI_CPU_OP_ST, 3'd0);
                    16'd553: data = 16'h8011;
                    16'd554: data = enc_imm(`MINI_CPU_OP_LD, 3'd0);
                    16'd555: data = 16'h9202;
                    16'd556: data = enc_imm(`MINI_CPU_OP_ST, 3'd0);
                    16'd557: data = 16'h8012;
                    16'd558: data = enc_imm(`MINI_CPU_OP_LD, 3'd0);
                    16'd559: data = 16'h9210;
                    16'd560: data = enc_imm(`MINI_CPU_OP_ST, 3'd0);
                    16'd561: data = 16'h8013;
                    16'd562: data = enc_imm(`MINI_CPU_OP_LD, 3'd0);
                    16'd563: data = 16'h9240;
                    16'd564: data = enc_imm(`MINI_CPU_OP_ST, 3'd0);
                    16'd565: data = 16'h8014;
                    16'd566: data = enc_imm(`MINI_CPU_OP_LD, 3'd0);
                    16'd567: data = 16'h9280;
                    16'd568: data = enc_imm(`MINI_CPU_OP_ST, 3'd0);
                    16'd569: data = 16'h8015;
                    16'd570: data = enc_imm(`MINI_CPU_OP_LD, 3'd0);
                    16'd571: data = 16'h92FF;
                    16'd572: data = enc_imm(`MINI_CPU_OP_ST, 3'd0);
                    16'd573: data = 16'h8016;

                    16'd574: data = enc_imm(`MINI_CPU_OP_LDI, 3'd0);
                    16'd575: data = 16'h00A5;
                    16'd576: data = enc_imm(`MINI_CPU_OP_ST, 3'd0);
                    16'd577: data = 16'h8000;
                    16'd578: data = enc_reg(`MINI_CPU_OP_HALT, 3'd0, 3'd0);

                    16'd579: data = enc_imm(`MINI_CPU_OP_LDI, 3'd0);
                    16'd580: data = 16'h00E1;
                    16'd581: data = enc_imm(`MINI_CPU_OP_ST, 3'd0);
                    16'd582: data = 16'h8000;
                    16'd583: data = enc_reg(`MINI_CPU_OP_HALT, 3'd0, 3'd0);

                    default: begin
                        if (addr >= 16'd18 && addr <= 16'd527) begin
                            if (addr[0] == 1'b0) begin
                                data = enc_imm(`MINI_CPU_OP_ST, 3'd0);
                            end else begin
                                data = 16'h9101 + ((addr - 16'd19) >> 1);
                            end
                        end else begin
                            data = enc_reg(`MINI_CPU_OP_NOP, 3'd0, 3'd0);
                        end
                    end
                endcase
            end

            `MINI_CPU_PROGRAM_UART_FRAME_ONCE,
            `MINI_CPU_PROGRAM_UART_FRAME_SERVICE: begin
                case (addr)
                    16'd0:    data = enc_imm(`MINI_CPU_OP_LD, 3'd0);
                    16'd1:    data = 16'hA000;
                    16'd2:    data = enc_imm(`MINI_CPU_OP_LDI, 3'd1);
                    16'd3:    data = 16'h0001;
                    16'd4:    data = enc_reg(`MINI_CPU_OP_AND, 3'd0, 3'd1);
                    16'd5:    data = enc_jump(`MINI_CPU_OP_JZ);
                    16'd6:    data = 16'd0;

                    16'd7:    data = enc_imm(`MINI_CPU_OP_LDI, 3'd0);
                    16'd8:    data = 16'h0002;
                    16'd9:    data = enc_imm(`MINI_CPU_OP_ST, 3'd0);
                    16'd10:   data = 16'hA001;
                    16'd11:   data = enc_imm(`MINI_CPU_OP_LDI, 3'd0);
                    16'd12:   data = 16'h0001;
                    16'd13:   data = enc_imm(`MINI_CPU_OP_ST, 3'd0);
                    16'd14:   data = 16'hA000;

                    16'd15:   data = enc_imm(`MINI_CPU_OP_LD, 3'd0);
                    16'd16:   data = 16'hA003;
                    16'd17:   data = enc_imm(`MINI_CPU_OP_ST, 3'd0);
                    16'd18:   data = 16'h9003;
                    16'd19:   data = enc_imm(`MINI_CPU_OP_LD, 3'd0);
                    16'd20:   data = 16'hA004;
                    16'd21:   data = enc_imm(`MINI_CPU_OP_ST, 3'd0);
                    16'd22:   data = 16'h9004;
                    16'd23:   data = enc_imm(`MINI_CPU_OP_LD, 3'd0);
                    16'd24:   data = 16'hA005;
                    16'd25:   data = enc_imm(`MINI_CPU_OP_ST, 3'd0);
                    16'd26:   data = 16'h9005;
                    16'd27:   data = enc_imm(`MINI_CPU_OP_LDI, 3'd0);
                    16'd28:   data = 16'h0002;
                    16'd29:   data = enc_imm(`MINI_CPU_OP_ST, 3'd0);
                    16'd30:   data = 16'h9000;

                    16'd1055: data = enc_imm(`MINI_CPU_OP_LDI, 3'd0);
                    16'd1056: data = 16'h0001;
                    16'd1057: data = enc_imm(`MINI_CPU_OP_ST, 3'd0);
                    16'd1058: data = 16'h9000;

                    16'd1059: data = enc_imm(`MINI_CPU_OP_LD, 3'd3);
                    16'd1060: data = 16'h9001;
                    16'd1061: data = enc_imm(`MINI_CPU_OP_LDI, 3'd2);
                    16'd1062: data = 16'h000C;
                    16'd1063: data = enc_reg(`MINI_CPU_OP_AND, 3'd3, 3'd2);
                    16'd1064: data = enc_jump(`MINI_CPU_OP_JNZ);
                    16'd1065: data = UART_FRAME_ERROR_ADDR;
                    16'd1066: data = enc_imm(`MINI_CPU_OP_LD, 3'd1);
                    16'd1067: data = 16'h9001;
                    16'd1068: data = enc_imm(`MINI_CPU_OP_LDI, 3'd2);
                    16'd1069: data = 16'h0002;
                    16'd1070: data = enc_reg(`MINI_CPU_OP_AND, 3'd1, 3'd2);
                    16'd1071: data = enc_jump(`MINI_CPU_OP_JZ);
                    16'd1072: data = UART_FRAME_POLL_ADDR;

                    16'd2097: data = enc_imm(`MINI_CPU_OP_LDI, 3'd0);
                    16'd2098: data = 16'h0005;
                    16'd2099: data = enc_imm(`MINI_CPU_OP_ST, 3'd0);
                    16'd2100: data = 16'hA001;
                    16'd2101: data = enc_imm(`MINI_CPU_OP_LDI, 3'd0);
                    16'd2102: data = 16'h00A5;
                    16'd2103: data = enc_imm(`MINI_CPU_OP_ST, 3'd0);
                    16'd2104: data = 16'h8000;
                    16'd2105: begin
                        if (PROGRAM_ID ==
                            `MINI_CPU_PROGRAM_UART_FRAME_SERVICE) begin
                            data = enc_jump(`MINI_CPU_OP_JMP);
                        end else begin
                            data = enc_reg(`MINI_CPU_OP_HALT, 3'd0, 3'd0);
                        end
                    end
                    16'd2106: data = 16'd0;

                    16'd2110: data = enc_imm(`MINI_CPU_OP_LDI, 3'd0);
                    16'd2111: data = 16'h0009;
                    16'd2112: data = enc_imm(`MINI_CPU_OP_ST, 3'd0);
                    16'd2113: data = 16'hA001;
                    16'd2114: data = enc_imm(`MINI_CPU_OP_LDI, 3'd0);
                    16'd2115: data = 16'h00E1;
                    16'd2116: data = enc_imm(`MINI_CPU_OP_ST, 3'd0);
                    16'd2117: data = 16'h8000;
                    16'd2118: begin
                        if (PROGRAM_ID ==
                            `MINI_CPU_PROGRAM_UART_FRAME_SERVICE) begin
                            data = enc_jump(`MINI_CPU_OP_JMP);
                        end else begin
                            data = enc_reg(`MINI_CPU_OP_HALT, 3'd0, 3'd0);
                        end
                    end
                    16'd2119: data = 16'd0;

                    default: begin
                        if (addr >= UART_FRAME_COPY_IN_BASE &&
                            addr < UART_FRAME_START_ADDR) begin
                            case ((addr - UART_FRAME_COPY_IN_BASE) & 16'h0003)
                                16'd0: data = enc_imm(`MINI_CPU_OP_LD, 3'd0);
                                16'd1: data = 16'hA100 +
                                             ((addr - UART_FRAME_COPY_IN_BASE)
                                              >> 2);
                                16'd2: data = enc_imm(`MINI_CPU_OP_ST, 3'd0);
                                default: data = 16'h9100 +
                                                ((addr -
                                                  UART_FRAME_COPY_IN_BASE)
                                                 >> 2);
                            endcase
                        end else if (addr >= UART_FRAME_COPY_OUT_BASE &&
                                     addr < UART_FRAME_SUCCESS_ADDR) begin
                            case ((addr - UART_FRAME_COPY_OUT_BASE) & 16'h0003)
                                16'd0: data = enc_imm(`MINI_CPU_OP_LD, 3'd0);
                                16'd1: data = 16'h9200 +
                                             ((addr - UART_FRAME_COPY_OUT_BASE)
                                              >> 2);
                                16'd2: data = enc_imm(`MINI_CPU_OP_ST, 3'd0);
                                default: data = 16'hA200 +
                                                ((addr -
                                                  UART_FRAME_COPY_OUT_BASE)
                                                 >> 2);
                            endcase
                        end else begin
                            data = enc_reg(`MINI_CPU_OP_NOP, 3'd0, 3'd0);
                        end
                    end
                endcase
            end

            default: begin
                data = enc_reg(`MINI_CPU_OP_NOP, 3'd0, 3'd0);
            end
        endcase
    end

endmodule
