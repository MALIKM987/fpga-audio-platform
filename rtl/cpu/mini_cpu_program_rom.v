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

            default: begin
                data = enc_reg(`MINI_CPU_OP_NOP, 3'd0, 3'd0);
            end
        endcase
    end

endmodule
