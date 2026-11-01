// ID: decode, operand read, JAL redirect, interrupt tagging and the ID/EX register
`include "hornet_defs.vh"

module id_stage #(parameter RV_M = 1, parameter RV_F = 1)
               (input             clk_i,
                input             rst_ni,

                input             valid_i,
                input      [31:0] pc_i,
                input      [31:0] instr_i,
                input             fault_i,

                input             fs_off_i,
                input      [2:0]  frm_i,
                input             irq_i,      //take an interrupt on this instruction
                input      [4:0]  irq_cause_i,

                //register file read
                output     [4:0]  rs1_o, rs2_o, rs3_o,
                output            rs1_fp_o, rs2_fp_o,
                input      [31:0] rs1_data_i, rs2_data_i, rs3_data_i,

                //to the hazard unit
                output            rs1_used_o, rs2_used_o, rs3_used_o,
                output            jal_redirect_o,
                output     [31:0] jal_target_o,

                input             hold_i,   //ID/EX keeps its contents
                input             bubble_i, //ID/EX gets a bubble
                input             flush_i,  //ID/EX is cleared

                output reg        valid_o,
                output reg [31:0] pc_o,
                output reg [31:0] instr_o,
                output reg [31:0] next_pc_o,
                output reg [4:0]  rs1_q_o, rs2_q_o, rs3_q_o,
                output reg        rs1_fp_q_o, rs2_fp_q_o,
                output reg        rs1_used_q_o, rs2_used_q_o, rs3_used_q_o,
                output reg [31:0] rs1_data_o, rs2_data_o, rs3_data_o,
                output reg [4:0]  rd_o,
                output reg        rd_we_o, rd_fp_o,
                output reg [31:0] imm_o,
                output reg [3:0]  alu_func_o,
                output reg        alu_a_pc_o, alu_b_imm_o,
                output reg [1:0]  res_sel_o,
                output reg        branch_o, jalr_o,
                output reg        load_o, store_o,
                output reg [1:0]  mem_size_o,
                output reg        mem_unsigned_o,
                output reg        mul_o, div_o,
                output reg        fpu_o,
                output reg [4:0]  fpu_op_o,
                output reg [2:0]  fpu_rm_o,
                output reg        csr_o, csr_we_o, csr_imm_o,
                output reg        mret_o, fence_i_o,
                output reg        trap_o, trap_intr_o,
                output reg [4:0]  trap_cause_o,
                output reg [31:0] trap_tval_o);

wire        illegal, ecall, ebreak, mret, fence_i;
wire        rs1_used, rs1_fp, rs2_used, rs2_fp, rs3_used, rd_we, rd_fp;
wire [3:0]  alu_func;
wire        alu_a_pc, alu_b_imm;
wire [1:0]  res_sel;
wire        branch, jal, jalr, load, store;
wire [1:0]  mem_size;
wire        mem_unsigned, mul, div, fpu;
wire [4:0]  fpu_op;
wire [2:0]  fpu_rm;
wire        csr, csr_we, csr_imm;
wire [31:0] imm;

control_unit #(.RV_M(RV_M), .RV_F(RV_F)) CTRL_UNIT(.instr_i(instr_i),
                       .fs_off_i(fs_off_i),
                       .frm_i(frm_i),
                       .illegal_o(illegal),
                       .ecall_o(ecall),
                       .ebreak_o(ebreak),
                       .mret_o(mret),
                       .fence_i_o(fence_i),
                       .rs1_used_o(rs1_used),
                       .rs1_fp_o(rs1_fp),
                       .rs2_used_o(rs2_used),
                       .rs2_fp_o(rs2_fp),
                       .rs3_used_o(rs3_used),
                       .rd_we_o(rd_we),
                       .rd_fp_o(rd_fp),
                       .alu_func_o(alu_func),
                       .alu_a_pc_o(alu_a_pc),
                       .alu_b_imm_o(alu_b_imm),
                       .res_sel_o(res_sel),
                       .branch_o(branch),
                       .jal_o(jal),
                       .jalr_o(jalr),
                       .load_o(load),
                       .store_o(store),
                       .mem_size_o(mem_size),
                       .mem_unsigned_o(mem_unsigned),
                       .mul_o(mul),
                       .div_o(div),
                       .fpu_o(fpu),
                       .fpu_op_o(fpu_op),
                       .fpu_rm_o(fpu_rm),
                       .csr_o(csr),
                       .csr_we_o(csr_we),
                       .csr_imm_o(csr_imm));

imm_decoder IMM_DEC(.instr_in(instr_i[31:2]), .imm_out(imm));

assign rs1_o    = instr_i[19:15];
assign rs2_o    = instr_i[24:20];
assign rs3_o    = instr_i[31:27];
assign rs1_fp_o = rs1_fp;
assign rs2_fp_o = rs2_fp;

//an interrupt carrier and a faulting fetch have no side effects
wire live = valid_i && !irq_i && !fault_i;

assign rs1_used_o = live && rs1_used;
assign rs2_used_o = live && rs2_used;
assign rs3_used_o = live && rs3_used;

assign jal_target_o   = pc_i + imm;
wire   jal_misaligned = jal_target_o[1];
assign jal_redirect_o = live && jal && !jal_misaligned;

reg        trap;
reg [4:0]  cause;
reg [31:0] tval;
always @*
begin
    trap  = 1'b1;
    cause = `EXC_ILLEGAL;
    tval  = 32'b0;
    if(irq_i)
        cause = irq_cause_i;
    else if(fault_i)
    begin
        cause = `EXC_INSN_FAULT;
        tval  = pc_i;
    end
    else if(illegal)
        tval  = instr_i;
    else if(ecall)
        cause = `EXC_ECALL_M;
    else if(ebreak)
    begin
        cause = `EXC_BREAKPOINT;
        tval  = pc_i;
    end
    else if(jal && jal_misaligned)
    begin
        cause = `EXC_INSN_MISALIGNED;
        tval  = jal_target_o;
    end
    else
        trap  = 1'b0;
end

always @(posedge clk_i or negedge rst_ni)
begin
    if(!rst_ni)
    begin
        valid_o <= 1'b0;
        pc_o <= 32'b0;
        instr_o <= 32'b0;
        next_pc_o <= 32'b0;
        {rs1_q_o, rs2_q_o, rs3_q_o} <= 15'b0;
        {rs1_fp_q_o, rs2_fp_q_o} <= 2'b0;
        {rs1_used_q_o, rs2_used_q_o, rs3_used_q_o} <= 3'b0;
        {rs1_data_o, rs2_data_o, rs3_data_o} <= 96'b0;
        rd_o <= 5'b0;
        {rd_we_o, rd_fp_o} <= 2'b0;
        imm_o <= 32'b0;
        alu_func_o <= 4'b0;
        {alu_a_pc_o, alu_b_imm_o} <= 2'b0;
        res_sel_o <= 2'b0;
        {branch_o, jalr_o, load_o, store_o} <= 4'b0;
        mem_size_o <= 2'b0;
        mem_unsigned_o <= 1'b0;
        {mul_o, div_o, fpu_o} <= 3'b0;
        fpu_op_o <= 5'b0;
        fpu_rm_o <= 3'b0;
        {csr_o, csr_we_o, csr_imm_o, mret_o, fence_i_o} <= 5'b0;
        {trap_o, trap_intr_o} <= 2'b0;
        trap_cause_o <= 5'b0;
        trap_tval_o <= 32'b0;
    end
    else if(flush_i || (bubble_i && !hold_i))
        valid_o <= 1'b0;
    else if(!hold_i)
    begin
        valid_o <= valid_i;
        pc_o <= pc_i;
        instr_o <= instr_i;
        next_pc_o <= jal_redirect_o ? jal_target_o : pc_i + 32'd4;
        rs1_q_o <= rs1_o;
        rs2_q_o <= rs2_o;
        rs3_q_o <= rs3_o;
        rs1_fp_q_o <= rs1_fp;
        rs2_fp_q_o <= rs2_fp;
        rs1_used_q_o <= rs1_used_o;
        rs2_used_q_o <= rs2_used_o;
        rs3_used_q_o <= rs3_used_o;
        rs1_data_o <= rs1_data_i;
        rs2_data_o <= rs2_data_i;
        rs3_data_o <= rs3_data_i;
        rd_o <= instr_i[11:7];
        rd_we_o <= live && rd_we && !trap;
        rd_fp_o <= rd_fp;
        imm_o <= imm;
        alu_func_o <= alu_func;
        alu_a_pc_o <= alu_a_pc;
        alu_b_imm_o <= alu_b_imm;
        res_sel_o <= res_sel;
        branch_o <= live && branch;
        jalr_o <= live && jalr;
        load_o <= live && load;
        store_o <= live && store;
        mem_size_o <= mem_size;
        mem_unsigned_o <= mem_unsigned;
        mul_o <= live && mul;
        div_o <= live && div;
        fpu_o <= live && fpu;
        fpu_op_o <= fpu_op;
        fpu_rm_o <= fpu_rm;
        csr_o <= live && csr;
        csr_we_o <= live && csr_we;
        csr_imm_o <= csr_imm;
        mret_o <= live && mret;
        fence_i_o <= live && fence_i;
        trap_o <= trap;
        trap_intr_o <= irq_i;
        trap_cause_o <= cause;
        trap_tval_o <= tval;
    end
end

endmodule
