/*
Control Unit
This module is responsible for generating the necessary control signals for the core.
*/
`include "hornet_defs.vh"

module control_unit #(parameter RV_M = 1,  //M extension: multiply and divide
                      parameter RV_F = 1)  //F extension: single-precision floating point
                    (input [31:0] instr_i,
                    input        fs_off_i, //mstatus.FS == Off: F instructions are illegal
                    input  [2:0] frm_i,    //dynamic rounding mode

                    output reg       illegal_o, //illegal instruction exception
                    output reg       ecall_o, ebreak_o, mret_o, fence_i_o,
                    output reg       rs1_used_o, rs1_fp_o,
                    output reg       rs2_used_o, rs2_fp_o,
                    output reg       rs3_used_o,
                    output reg       rd_we_o, rd_fp_o,
                    output reg [3:0] alu_func_o,
                    output reg       alu_a_pc_o, alu_b_imm_o,
                    output reg [1:0] res_sel_o,
                    output reg       branch_o, jal_o, jalr_o,
                    output reg       load_o, store_o,
                    output reg [1:0] mem_size_o, //0: byte, 1: half, 2: word
                    output reg       mem_unsigned_o,
                    output reg       mul_o, div_o,
                    output reg       fpu_o,
                    output reg [4:0] fpu_op_o,
                    output reg [2:0] fpu_rm_o,
                    output reg       csr_o, csr_we_o, csr_imm_o);

wire [6:0] opcode = instr_i[6:0];
wire [2:0] funct3 = instr_i[14:12];
wire [6:0] funct7 = instr_i[31:25];
wire [4:0] rs1    = instr_i[19:15];
wire [4:0] rs2    = instr_i[24:20];
wire [11:0] csr   = instr_i[31:20];

//F instructions and CSRs exist only with the F extension and mstatus.FS != Off
wire f_ok = RV_F != 0 && !fs_off_i;

//rounding mode: static field or frm
wire       rm_dyn = funct3 == 3'b111;
wire [2:0] rm     = rm_dyn ? frm_i : funct3;
wire       rm_ok  = rm <= 3'd4;

reg csr_exists;
always @*
begin
    casez(csr)
        `CSR_FFLAGS, `CSR_FRM, `CSR_FCSR: csr_exists = f_ok;
        `CSR_MSTATUS, `CSR_MISA, `CSR_MIE, `CSR_MTVEC, `CSR_MSTATUSH,
        `CSR_MCOUNTINHIBIT, `CSR_MSCRATCH, `CSR_MEPC, `CSR_MCAUSE,
        `CSR_MTVAL, `CSR_MIP: csr_exists = 1'b1;
        12'h32?, 12'h33?: csr_exists = csr[4:0] >= 5'd3; //mhpmevent3..31
        12'h7A0, 12'h7A1, 12'h7A2, 12'h7A3: csr_exists = 1'b1;
        12'hB0?, 12'hB1?, 12'hB8?, 12'hB9?: csr_exists = csr[4:0] != 5'd1; //mcycle, minstret, mhpmcounter3..31
        `CSR_CYCLE, `CSR_TIME, `CSR_INSTRET,
        `CSR_CYCLEH, `CSR_TIMEH, `CSR_INSTRETH: csr_exists = 1'b1;
        `CSR_MVENDORID, `CSR_MARCHID, `CSR_MIMPID,
        `CSR_MHARTID, `CSR_MCONFIGPTR: csr_exists = 1'b1;
        default: csr_exists = 1'b0;
    endcase
end

reg legal;
always @*
begin
    legal          = 1'b0;
    ecall_o        = 1'b0;
    ebreak_o       = 1'b0;
    mret_o         = 1'b0;
    fence_i_o      = 1'b0;
    rs1_used_o     = 1'b0;
    rs1_fp_o       = 1'b0;
    rs2_used_o     = 1'b0;
    rs2_fp_o       = 1'b0;
    rs3_used_o     = 1'b0;
    rd_we_o        = 1'b0;
    rd_fp_o        = 1'b0;
    alu_func_o     = `ALU_ADD;
    alu_a_pc_o     = 1'b0;
    alu_b_imm_o    = 1'b0;
    res_sel_o      = `RES_ALU;
    branch_o       = 1'b0;
    jal_o          = 1'b0;
    jalr_o         = 1'b0;
    load_o         = 1'b0;
    store_o        = 1'b0;
    mem_size_o     = funct3[1:0];
    mem_unsigned_o = funct3[2];
    mul_o          = 1'b0;
    div_o          = 1'b0;
    fpu_o          = 1'b0;
    fpu_op_o       = `FPU_ADD;
    fpu_rm_o       = rm;
    csr_o          = 1'b0;
    csr_we_o       = 1'b0;
    csr_imm_o      = funct3[2];

    case(opcode)
        `OP_LUI:
        begin
            legal = 1'b1;
            rd_we_o = 1'b1;
            alu_func_o = `ALU_PASS;
            alu_b_imm_o = 1'b1;
        end

        `OP_AUIPC:
        begin
            legal = 1'b1;
            rd_we_o = 1'b1;
            alu_a_pc_o = 1'b1;
            alu_b_imm_o = 1'b1;
        end

        `OP_JAL:
        begin
            legal = 1'b1;
            rd_we_o = 1'b1;
            res_sel_o = `RES_PC4;
            jal_o = 1'b1;
        end

        `OP_JALR:
        begin
            legal = funct3 == 3'd0;
            rs1_used_o = 1'b1;
            rd_we_o = 1'b1;
            res_sel_o = `RES_PC4;
            jalr_o = 1'b1;
        end

        //BEQ, BNE, BLT, BGE, BLTU, BGEU
        `OP_BRANCH:
        begin
            legal = funct3[2:1] != 2'b01;
            rs1_used_o = 1'b1;
            rs2_used_o = 1'b1;
            branch_o = 1'b1;
            case(funct3)
                3'b000: alu_func_o = `ALU_EQ;
                3'b001: alu_func_o = `ALU_NE;
                3'b100: alu_func_o = `ALU_SLT;
                3'b101: alu_func_o = `ALU_GE;
                3'b110: alu_func_o = `ALU_SLTU;
                default: alu_func_o = `ALU_GEU;
            endcase
        end

        //LB, LH, LW, LBU, LHU
        `OP_LOAD:
        begin
            legal = funct3 != 3'd3 && funct3 != 3'd6 && funct3 != 3'd7;
            rs1_used_o = 1'b1;
            rd_we_o = 1'b1;
            alu_b_imm_o = 1'b1;
            load_o = 1'b1;
        end

        //SB, SH, SW
        `OP_STORE:
        begin
            legal = funct3 <= 3'd2;
            rs1_used_o = 1'b1;
            rs2_used_o = 1'b1;
            alu_b_imm_o = 1'b1;
            store_o = 1'b1;
        end

        `OP_IMM:
        begin
            if(funct3 == 3'b001)
                legal = funct7 == 7'b0000000;
            else if(funct3 == 3'b101)
                legal = funct7 == 7'b0000000 || funct7 == 7'b0100000;
            else
                legal = 1'b1;
            rs1_used_o = 1'b1;
            rd_we_o = 1'b1;
            alu_b_imm_o = 1'b1;
            case(funct3)
                3'b000: alu_func_o = `ALU_ADD;
                3'b001: alu_func_o = `ALU_SLL;
                3'b010: alu_func_o = `ALU_SLT;
                3'b011: alu_func_o = `ALU_SLTU;
                3'b100: alu_func_o = `ALU_XOR;
                3'b101: alu_func_o = funct7[5] ? `ALU_SRA : `ALU_SRL;
                3'b110: alu_func_o = `ALU_OR;
                default: alu_func_o = `ALU_AND;
            endcase
        end

        `OP_OP:
        begin
            rs1_used_o = 1'b1;
            rs2_used_o = 1'b1;
            rd_we_o = 1'b1;
            if(funct7 == 7'b0000001) //M extension
            begin
                legal = RV_M != 0;
                mul_o = !funct3[2];
                div_o = funct3[2];
                res_sel_o = `RES_DIV;
            end
            else
            begin
                if(funct7 == 7'b0100000)
                    legal = funct3 == 3'b000 || funct3 == 3'b101;
                else
                    legal = funct7 == 7'b0000000;
                case(funct3)
                    3'b000: alu_func_o = funct7[5] ? `ALU_SUB : `ALU_ADD;
                    3'b001: alu_func_o = `ALU_SLL;
                    3'b010: alu_func_o = `ALU_SLT;
                    3'b011: alu_func_o = `ALU_SLTU;
                    3'b100: alu_func_o = `ALU_XOR;
                    3'b101: alu_func_o = funct7[5] ? `ALU_SRA : `ALU_SRL;
                    3'b110: alu_func_o = `ALU_OR;
                    default: alu_func_o = `ALU_AND;
                endcase
            end
        end

        //FENCE is a no-op, FENCE.I refetches
        `OP_MISC_MEM:
        begin
            legal = funct3 == 3'b000 || funct3 == 3'b001;
            fence_i_o = funct3 == 3'b001;
        end

        `OP_SYSTEM:
        begin
            if(funct3 == 3'b000)
            begin
                ecall_o  = instr_i == 32'h0000_0073;
                ebreak_o = instr_i == 32'h0010_0073;
                mret_o   = instr_i == 32'h3020_0073;
                legal    = ecall_o || ebreak_o || mret_o || instr_i == 32'h1050_0073; //WFI is a no-op
            end
            else if(funct3 != 3'b100)
            begin
                csr_o = 1'b1;
                csr_we_o = funct3[1:0] == 2'b01 || rs1 != 5'd0;
                rs1_used_o = !funct3[2];
                rd_we_o = 1'b1;
                alu_b_imm_o = 1'b1;
                legal = csr_exists && !(csr_we_o && csr[11:10] == 2'b11);
            end
        end

        `OP_LOAD_FP:
        begin
            legal = funct3 == 3'b010 && f_ok;
            rs1_used_o = 1'b1;
            rd_we_o = 1'b1;
            rd_fp_o = 1'b1;
            alu_b_imm_o = 1'b1;
            load_o = 1'b1;
        end

        `OP_STORE_FP:
        begin
            legal = funct3 == 3'b010 && f_ok;
            rs1_used_o = 1'b1;
            rs2_used_o = 1'b1;
            rs2_fp_o = 1'b1;
            alu_b_imm_o = 1'b1;
            store_o = 1'b1;
        end

        `OP_MADD, `OP_MSUB, `OP_NMSUB, `OP_NMADD:
        begin
            legal = funct7[1:0] == 2'b00 && rm_ok && f_ok;
            rs1_used_o = 1'b1;
            rs1_fp_o = 1'b1;
            rs2_used_o = 1'b1;
            rs2_fp_o = 1'b1;
            rs3_used_o = 1'b1;
            rd_we_o = 1'b1;
            rd_fp_o = 1'b1;
            fpu_o = 1'b1;
            res_sel_o = `RES_FPU;
            case(opcode[3:2])
                2'b00: fpu_op_o = `FPU_MADD;
                2'b01: fpu_op_o = `FPU_MSUB;
                2'b10: fpu_op_o = `FPU_NMSUB;
                default: fpu_op_o = `FPU_NMADD;
            endcase
        end

        `OP_FP:
        begin
            fpu_o = 1'b1;
            res_sel_o = `RES_FPU;
            rs1_used_o = 1'b1;
            rs1_fp_o = 1'b1;
            rd_we_o = 1'b1;
            rd_fp_o = 1'b1;
            case(funct7)
                7'b0000000, 7'b0000100, 7'b0001000, 7'b0001100: //FADD, FSUB, FMUL, FDIV
                begin
                    legal = rm_ok;
                    rs2_used_o = 1'b1;
                    rs2_fp_o = 1'b1;
                    case(funct7[3:2])
                        2'b00: fpu_op_o = `FPU_ADD;
                        2'b01: fpu_op_o = `FPU_SUB;
                        2'b10: fpu_op_o = `FPU_MUL;
                        default: fpu_op_o = `FPU_DIV;
                    endcase
                end
                7'b0101100: //FSQRT
                begin
                    legal = rm_ok && rs2 == 5'd0;
                    fpu_op_o = `FPU_SQRT;
                end
                7'b0010000: //FSGNJ, FSGNJN, FSGNJX
                begin
                    legal = funct3 <= 3'd2;
                    rs2_used_o = 1'b1;
                    rs2_fp_o = 1'b1;
                    fpu_op_o = funct3 == 3'd0 ? `FPU_SGNJ : funct3 == 3'd1 ? `FPU_SGNJN : `FPU_SGNJX;
                end
                7'b0010100: //FMIN, FMAX
                begin
                    legal = funct3 <= 3'd1;
                    rs2_used_o = 1'b1;
                    rs2_fp_o = 1'b1;
                    fpu_op_o = funct3[0] ? `FPU_MAX : `FPU_MIN;
                end
                7'b1010000: //FLE, FLT, FEQ
                begin
                    legal = funct3 <= 3'd2;
                    rs2_used_o = 1'b1;
                    rs2_fp_o = 1'b1;
                    rd_fp_o = 1'b0;
                    fpu_op_o = funct3 == 3'd2 ? `FPU_EQ : funct3 == 3'd1 ? `FPU_LT : `FPU_LE;
                end
                7'b1100000: //FCVT.W.S, FCVT.WU.S
                begin
                    legal = rm_ok && rs2[4:1] == 4'd0;
                    rd_fp_o = 1'b0;
                    fpu_op_o = rs2[0] ? `FPU_CVTWUS : `FPU_CVTWS;
                end
                7'b1101000: //FCVT.S.W, FCVT.S.WU
                begin
                    legal = rm_ok && rs2[4:1] == 4'd0;
                    rs1_fp_o = 1'b0;
                    fpu_op_o = rs2[0] ? `FPU_CVTSWU : `FPU_CVTSW;
                end
                7'b1110000: //FMV.X.W, FCLASS
                begin
                    legal = rs2 == 5'd0 && funct3 <= 3'd1;
                    rd_fp_o = 1'b0;
                    fpu_op_o = funct3[0] ? `FPU_CLASS : `FPU_MVXW;
                end
                7'b1111000: //FMV.W.X
                begin
                    legal = rs2 == 5'd0 && funct3 == 3'd0;
                    rs1_fp_o = 1'b0;
                    fpu_op_o = `FPU_MVWX;
                end
                default: legal = 1'b0;
            endcase
            legal = legal && f_ok;
        end

        default: legal = 1'b0;
    endcase

    illegal_o = !legal;
    //an illegal instruction has no side effects
    if(!legal)
    begin
        {ecall_o, ebreak_o, mret_o, fence_i_o} = 4'b0;
        {rs1_used_o, rs2_used_o, rs3_used_o, rd_we_o} = 4'b0;
        {branch_o, jal_o, jalr_o, load_o, store_o} = 5'b0;
        {mul_o, div_o, fpu_o, csr_o, csr_we_o} = 5'b0;
    end
end

endmodule
