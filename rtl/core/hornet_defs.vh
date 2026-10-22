// HORNET shared definitions

`ifndef HORNET_DEFS_VH
`define HORNET_DEFS_VH

// opcodes
`define OP_LOAD     7'b0000011
`define OP_LOAD_FP  7'b0000111
`define OP_MISC_MEM 7'b0001111
`define OP_IMM      7'b0010011
`define OP_AUIPC    7'b0010111
`define OP_STORE    7'b0100011
`define OP_STORE_FP 7'b0100111
`define OP_OP       7'b0110011
`define OP_LUI      7'b0110111
`define OP_MADD     7'b1000011
`define OP_MSUB     7'b1000111
`define OP_NMSUB    7'b1001011
`define OP_NMADD    7'b1001111
`define OP_FP       7'b1010011
`define OP_BRANCH   7'b1100011
`define OP_JALR     7'b1100111
`define OP_JAL      7'b1101111
`define OP_SYSTEM   7'b1110011

// ALU functions (ALU.v)
`define ALU_ADD  4'b0000
`define ALU_SUB  4'b0001
`define ALU_XOR  4'b0010
`define ALU_OR   4'b0011
`define ALU_AND  4'b0100
`define ALU_SLTU 4'b0101
`define ALU_SLT  4'b0110
`define ALU_SLL  4'b0111
`define ALU_SRL  4'b1000
`define ALU_SRA  4'b1001
`define ALU_EQ   4'b1010
`define ALU_NE   4'b1011
`define ALU_GEU  4'b1100
`define ALU_GE   4'b1101
`define ALU_PASS 4'b1111

// EX result select
`define RES_ALU 2'd0
`define RES_PC4 2'd1
`define RES_DIV 2'd2
`define RES_FPU 2'd3

// FPU operations
`define FPU_ADD    5'd0
`define FPU_SUB    5'd1
`define FPU_MUL    5'd2
`define FPU_MADD   5'd3
`define FPU_MSUB   5'd4
`define FPU_NMSUB  5'd5
`define FPU_NMADD  5'd6
`define FPU_DIV    5'd7
`define FPU_SQRT   5'd8
`define FPU_SGNJ   5'd9
`define FPU_SGNJN  5'd10
`define FPU_SGNJX  5'd11
`define FPU_MIN    5'd12
`define FPU_MAX    5'd13
`define FPU_EQ     5'd14
`define FPU_LT     5'd15
`define FPU_LE     5'd16
`define FPU_CLASS  5'd17
`define FPU_MVXW   5'd18
`define FPU_MVWX   5'd19
`define FPU_CVTWS  5'd20
`define FPU_CVTWUS 5'd21
`define FPU_CVTSW  5'd22
`define FPU_CVTSWU 5'd23

// exception causes
`define EXC_INSN_MISALIGNED  5'd0
`define EXC_INSN_FAULT       5'd1
`define EXC_ILLEGAL          5'd2
`define EXC_BREAKPOINT       5'd3
`define EXC_LOAD_MISALIGNED  5'd4
`define EXC_LOAD_FAULT       5'd5
`define EXC_STORE_MISALIGNED 5'd6
`define EXC_STORE_FAULT      5'd7
`define EXC_ECALL_M          5'd11

// CSR addresses
`define CSR_FFLAGS        12'h001
`define CSR_FRM           12'h002
`define CSR_FCSR          12'h003
`define CSR_MSTATUS       12'h300
`define CSR_MISA          12'h301
`define CSR_MIE           12'h304
`define CSR_MTVEC         12'h305
`define CSR_MSTATUSH      12'h310
`define CSR_MCOUNTINHIBIT 12'h320
`define CSR_MSCRATCH      12'h340
`define CSR_MEPC          12'h341
`define CSR_MCAUSE        12'h342
`define CSR_MTVAL         12'h343
`define CSR_MIP           12'h344
`define CSR_TSELECT       12'h7A0
`define CSR_TDATA1        12'h7A1
`define CSR_TDATA2        12'h7A2
`define CSR_TDATA3        12'h7A3
`define CSR_MCYCLE        12'hB00
`define CSR_MINSTRET      12'hB02
`define CSR_MCYCLEH       12'hB80
`define CSR_MINSTRETH     12'hB82
`define CSR_CYCLE         12'hC00
`define CSR_TIME          12'hC01
`define CSR_INSTRET       12'hC02
`define CSR_CYCLEH        12'hC80
`define CSR_TIMEH         12'hC81
`define CSR_INSTRETH      12'hC82
`define CSR_MVENDORID     12'hF11
`define CSR_MARCHID       12'hF12
`define CSR_MIMPID        12'hF13
`define CSR_MHARTID       12'hF14
`define CSR_MCONFIGPTR    12'hF15

`endif
