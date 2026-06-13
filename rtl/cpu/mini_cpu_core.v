`include "rtl/cpu/mini_cpu_defs.vh"

module mini_cpu_core #(
    parameter integer DATA_WIDTH = 16,
    parameter integer ADDR_WIDTH = 16,
    parameter integer REG_COUNT  = 8,
    parameter integer REG_BITS   = 3
) (
    input  wire                         clk,
    input  wire                         rst,

    output reg  [ADDR_WIDTH-1:0]        rom_addr,
    input  wire [DATA_WIDTH-1:0]        rom_data,

    output reg  [ADDR_WIDTH-1:0]        bus_addr,
    output reg  [DATA_WIDTH-1:0]        bus_wdata,
    input  wire [DATA_WIDTH-1:0]        bus_rdata,
    output reg                          bus_we,
    output reg                          bus_re,
    input  wire                         bus_ready,

    output reg                          halted,
    output wire [ADDR_WIDTH-1:0]        debug_pc,
    output wire                         debug_zero_flag,
    output wire [DATA_WIDTH-1:0]        debug_reg0,
    output wire [DATA_WIDTH-1:0]        debug_reg1,
    output wire [DATA_WIDTH-1:0]        debug_reg2,
    output wire [DATA_WIDTH-1:0]        debug_reg3,
    output wire [DATA_WIDTH-1:0]        debug_reg4,
    output wire [DATA_WIDTH-1:0]        debug_reg5,
    output wire [DATA_WIDTH-1:0]        debug_reg6,
    output wire [DATA_WIDTH-1:0]        debug_reg7
);

    localparam [2:0] STATE_FETCH     = 3'd0;
    localparam [2:0] STATE_DECODE    = 3'd1;
    localparam [2:0] STATE_IMMEDIATE = 3'd2;
    localparam [2:0] STATE_MEM_READ  = 3'd3;
    localparam [2:0] STATE_MEM_WRITE = 3'd4;
    localparam [2:0] STATE_HALT      = 3'd5;

    reg [2:0] state = STATE_FETCH;
    reg [ADDR_WIDTH-1:0] pc = {ADDR_WIDTH{1'b0}};
    reg [DATA_WIDTH-1:0] ir = {DATA_WIDTH{1'b0}};
    reg [DATA_WIDTH-1:0] reg_file [0:REG_COUNT-1];
    reg zero_flag = 1'b0;

    reg [3:0] pending_opcode = `MINI_CPU_OP_NOP;
    reg [REG_BITS-1:0] pending_rd = {REG_BITS{1'b0}};
    reg [REG_BITS-1:0] pending_rs = {REG_BITS{1'b0}};
    reg [DATA_WIDTH-1:0] alu_result = {DATA_WIDTH{1'b0}};

    wire [3:0] opcode;
    wire [REG_BITS-1:0] rd;
    wire [REG_BITS-1:0] rs;

    integer i;

    assign opcode = ir[15:12];
    assign rd = ir[11:9];
    assign rs = ir[8:6];

    assign debug_pc = pc;
    assign debug_zero_flag = zero_flag;
    assign debug_reg0 = reg_file[0];
    assign debug_reg1 = reg_file[1];
    assign debug_reg2 = reg_file[2];
    assign debug_reg3 = reg_file[3];
    assign debug_reg4 = reg_file[4];
    assign debug_reg5 = reg_file[5];
    assign debug_reg6 = reg_file[6];
    assign debug_reg7 = reg_file[7];

    always @(posedge clk) begin
        if (rst) begin
            state <= STATE_FETCH;
            pc <= {ADDR_WIDTH{1'b0}};
            rom_addr <= {ADDR_WIDTH{1'b0}};
            ir <= {DATA_WIDTH{1'b0}};
            bus_addr <= {ADDR_WIDTH{1'b0}};
            bus_wdata <= {DATA_WIDTH{1'b0}};
            bus_we <= 1'b0;
            bus_re <= 1'b0;
            halted <= 1'b0;
            zero_flag <= 1'b0;
            pending_opcode <= `MINI_CPU_OP_NOP;
            pending_rd <= {REG_BITS{1'b0}};
            pending_rs <= {REG_BITS{1'b0}};
            alu_result <= {DATA_WIDTH{1'b0}};

            for (i = 0; i < REG_COUNT; i = i + 1) begin
                reg_file[i] <= {DATA_WIDTH{1'b0}};
            end
        end else begin
            bus_we <= 1'b0;
            bus_re <= 1'b0;

            case (state)
                STATE_FETCH: begin
                    ir <= rom_data;
                    pc <= pc + 1'b1;
                    rom_addr <= pc + 1'b1;
                    state <= STATE_DECODE;
                end

                STATE_DECODE: begin
                    case (opcode)
                        `MINI_CPU_OP_NOP: begin
                            state <= STATE_FETCH;
                        end

                        `MINI_CPU_OP_HALT: begin
                            halted <= 1'b1;
                            state <= STATE_HALT;
                        end

                        `MINI_CPU_OP_ADD: begin
                            alu_result = reg_file[rd] + reg_file[rs];
                            reg_file[rd] <= alu_result;
                            zero_flag <= (alu_result == {DATA_WIDTH{1'b0}});
                            state <= STATE_FETCH;
                        end

                        `MINI_CPU_OP_SUB: begin
                            alu_result = reg_file[rd] - reg_file[rs];
                            reg_file[rd] <= alu_result;
                            zero_flag <= (alu_result == {DATA_WIDTH{1'b0}});
                            state <= STATE_FETCH;
                        end

                        `MINI_CPU_OP_AND: begin
                            alu_result = reg_file[rd] & reg_file[rs];
                            reg_file[rd] <= alu_result;
                            zero_flag <= (alu_result == {DATA_WIDTH{1'b0}});
                            state <= STATE_FETCH;
                        end

                        `MINI_CPU_OP_CMP: begin
                            alu_result = reg_file[rd] - reg_file[rs];
                            zero_flag <= (alu_result == {DATA_WIDTH{1'b0}});
                            state <= STATE_FETCH;
                        end

                        `MINI_CPU_OP_LDI,
                        `MINI_CPU_OP_LD,
                        `MINI_CPU_OP_ST,
                        `MINI_CPU_OP_ADDI,
                        `MINI_CPU_OP_JMP,
                        `MINI_CPU_OP_JZ,
                        `MINI_CPU_OP_JNZ: begin
                            pending_opcode <= opcode;
                            pending_rd <= rd;
                            pending_rs <= rs;
                            ir <= rom_data;
                            pc <= pc + 1'b1;
                            rom_addr <= pc + 1'b1;
                            state <= STATE_IMMEDIATE;
                        end

                        default: begin
                            halted <= 1'b1;
                            state <= STATE_HALT;
                        end
                    endcase
                end

                STATE_IMMEDIATE: begin
                    case (pending_opcode)
                        `MINI_CPU_OP_LDI: begin
                            reg_file[pending_rd] <= ir;
                            zero_flag <= (ir == {DATA_WIDTH{1'b0}});
                            state <= STATE_FETCH;
                        end

                        `MINI_CPU_OP_ADDI: begin
                            alu_result = reg_file[pending_rd] + ir;
                            reg_file[pending_rd] <= alu_result;
                            zero_flag <= (alu_result == {DATA_WIDTH{1'b0}});
                            state <= STATE_FETCH;
                        end

                        `MINI_CPU_OP_LD: begin
                            bus_addr <= ir[ADDR_WIDTH-1:0];
                            bus_re <= 1'b1;
                            state <= STATE_MEM_READ;
                        end

                        `MINI_CPU_OP_ST: begin
                            bus_addr <= ir[ADDR_WIDTH-1:0];
                            bus_wdata <= reg_file[pending_rd];
                            bus_we <= 1'b1;
                            state <= STATE_MEM_WRITE;
                        end

                        `MINI_CPU_OP_JMP: begin
                            pc <= ir[ADDR_WIDTH-1:0];
                            rom_addr <= ir[ADDR_WIDTH-1:0];
                            state <= STATE_FETCH;
                        end

                        `MINI_CPU_OP_JZ: begin
                            if (zero_flag) begin
                                pc <= ir[ADDR_WIDTH-1:0];
                                rom_addr <= ir[ADDR_WIDTH-1:0];
                            end
                            state <= STATE_FETCH;
                        end

                        `MINI_CPU_OP_JNZ: begin
                            if (!zero_flag) begin
                                pc <= ir[ADDR_WIDTH-1:0];
                                rom_addr <= ir[ADDR_WIDTH-1:0];
                            end
                            state <= STATE_FETCH;
                        end

                        default: begin
                            halted <= 1'b1;
                            state <= STATE_HALT;
                        end
                    endcase
                end

                STATE_MEM_READ: begin
                    if (bus_ready) begin
                        reg_file[pending_rd] <= bus_rdata;
                        zero_flag <= (bus_rdata == {DATA_WIDTH{1'b0}});
                        state <= STATE_FETCH;
                    end else begin
                        bus_re <= 1'b1;
                    end
                end

                STATE_MEM_WRITE: begin
                    if (bus_ready) begin
                        state <= STATE_FETCH;
                    end else begin
                        bus_we <= 1'b1;
                    end
                end

                STATE_HALT: begin
                    halted <= 1'b1;
                    state <= STATE_HALT;
                end

                default: begin
                    halted <= 1'b1;
                    state <= STATE_HALT;
                end
            endcase
        end
    end

endmodule
