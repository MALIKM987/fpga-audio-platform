`ifndef MINI_CPU_DEFS_VH
`define MINI_CPU_DEFS_VH

`define MINI_CPU_OP_NOP   4'h0
`define MINI_CPU_OP_LDI   4'h1
`define MINI_CPU_OP_LD    4'h2
`define MINI_CPU_OP_ST    4'h3
`define MINI_CPU_OP_ADD   4'h4
`define MINI_CPU_OP_ADDI  4'h5
`define MINI_CPU_OP_SUB   4'h6
`define MINI_CPU_OP_AND   4'h7
`define MINI_CPU_OP_CMP   4'h8
`define MINI_CPU_OP_JMP   4'h9
`define MINI_CPU_OP_JZ    4'hA
`define MINI_CPU_OP_JNZ   4'hB
`define MINI_CPU_OP_HALT  4'hF

`define MINI_CPU_PROGRAM_FETCH_HALT 0
`define MINI_CPU_PROGRAM_ALU        1
`define MINI_CPU_PROGRAM_BRANCH     2
`define MINI_CPU_PROGRAM_MMIO       3
`define MINI_CPU_PROGRAM_GPIO       4
`define MINI_CPU_PROGRAM_FFT_IMPULSE 5
`define MINI_CPU_PROGRAM_UART_FRAME_ONCE 6

`endif
