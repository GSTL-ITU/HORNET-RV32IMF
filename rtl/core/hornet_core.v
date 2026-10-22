// HORNET RV32IMF core: five-stage pipeline with request/grant/valid memory ports
module hornet_core #(parameter RESET_VECTOR = 32'h0000_0000,
                     parameter MTVEC_RESET  = 32'h0000_0000,
                     parameter HART_ID      = 32'd0)
(input         clk_i,
 input         rst_ni,

 //instruction port
 output        instr_req_o,
 input         instr_gnt_i,
 output [31:0] instr_addr_o,
 input         instr_rvalid_i,
 input  [31:0] instr_rdata_i,
 input         instr_err_i,

 //data port
 output        data_req_o,
 input         data_gnt_i,
 output        data_we_o,
 output [3:0]  data_be_o,
 output [31:0] data_addr_o,
 output [31:0] data_wdata_o,
 input         data_rvalid_i,
 input  [31:0] data_rdata_i,
 input         data_err_i,

 //interrupts
 input         msip_i, mtip_i, meip_i,
 input  [15:0] fast_irq_i,
 input  [63:0] mtime_i,

 //RVFI
 output        rvfi_valid,
 output [63:0] rvfi_order,
 output [31:0] rvfi_insn,
 output        rvfi_trap,
 output        rvfi_halt,
 output        rvfi_intr,
 output [1:0]  rvfi_mode,
 output [1:0]  rvfi_ixl,
 output [4:0]  rvfi_rs1_addr,
 output [4:0]  rvfi_rs2_addr,
 output [31:0] rvfi_rs1_rdata,
 output [31:0] rvfi_rs2_rdata,
 output [4:0]  rvfi_rd_addr,
 output [31:0] rvfi_rd_wdata,
 output [31:0] rvfi_pc_rdata,
 output [31:0] rvfi_pc_wdata,
 output [31:0] rvfi_mem_addr,
 output [3:0]  rvfi_mem_rmask,
 output [3:0]  rvfi_mem_wmask,
 output [31:0] rvfi_mem_rdata,
 output [31:0] rvfi_mem_wdata,
 output        rvfi_frd_we,
 output [4:0]  rvfi_frd_addr,
 output [31:0] rvfi_frd_wdata,
 output [4:0]  rvfi_fflags,
 output [63:0] rvfi_mcycle,
 output [63:0] rvfi_minstret);

//hazard unit
wire        hold, if_stall, id_hold, id_bubble, id_flush, ex_flush;
wire        redirect;
wire [31:0] redirect_pc;
wire [1:0]  fwd_a, fwd_b, fwd_c;

//IF/ID
wire        if_valid, if_fault;
wire [31:0] if_pc, if_instr;

//ID
wire [4:0]  rf_rs1, rf_rs2, rf_rs3;
wire        rf_rs1_fp, rf_rs2_fp;
wire [31:0] rf_rs1_data, rf_rs2_data, rf_rs3_data;
wire        id_rs1_used, id_rs2_used, id_rs3_used;
wire        id_jal;
wire [31:0] id_jal_pc;

//ID/EX
wire        de_valid;
wire [31:0] de_pc, de_instr, de_next_pc;
wire [4:0]  de_rs1, de_rs2, de_rs3;
wire        de_rs1_fp, de_rs2_fp, de_rs1_used, de_rs2_used, de_rs3_used;
wire [31:0] de_rs1_data, de_rs2_data, de_rs3_data;
wire [4:0]  de_rd;
wire        de_rd_we, de_rd_fp;
wire [31:0] de_imm;
wire [3:0]  de_alu_func;
wire        de_alu_a_pc, de_alu_b_imm;
wire [1:0]  de_res_sel;
wire        de_branch, de_jalr, de_load, de_store;
wire [1:0]  de_mem_size;
wire        de_mem_unsigned, de_mul, de_div, de_fpu;
wire [4:0]  de_fpu_op;
wire [2:0]  de_fpu_rm;
wire        de_csr, de_csr_we, de_csr_imm, de_mret, de_fence_i;
wire        de_trap, de_trap_intr;
wire [4:0]  de_trap_cause;
wire [31:0] de_trap_tval;

//EX
wire        ex_busy, ex_redirect;
wire [31:0] ex_redirect_pc;

//EX/MEM
wire        em_valid;
wire [31:0] em_pc, em_instr, em_next_pc;
wire [4:0]  em_rs1, em_rs2;
wire        em_rs1_fp, em_rs2_fp, em_rs1_used, em_rs2_used;
wire [31:0] em_rs1_data, em_rs2_data;
wire [4:0]  em_rd;
wire        em_rd_we, em_rd_fp;
wire [31:0] em_result;
wire        em_load, em_store;
wire [1:0]  em_mem_size;
wire        em_mem_unsigned, em_mul, em_fpu;
wire [4:0]  em_fflags;
wire        em_csr, em_csr_we, em_mret, em_fence_i;
wire        em_trap, em_trap_intr;
wire [4:0]  em_trap_cause;
wire [31:0] em_trap_tval;

//MEM
wire        mem_wait, mem_trap, mem_mret, mem_retire;
wire [4:0]  mem_trap_cause;
wire [31:0] mem_trap_tval;
wire        mem_csr_we, mem_fp_dirty;
wire [4:0]  mem_fflags;
wire        mem_redirect;
wire [31:0] mem_redirect_pc;

//MEM/WB
wire        mw_valid, mw_intr;
wire [31:0] mw_pc, mw_instr, mw_next_pc;
wire [4:0]  mw_rs1, mw_rs2;
wire        mw_rs1_fp, mw_rs2_fp, mw_rs1_used, mw_rs2_used;
wire [31:0] mw_rs1_data, mw_rs2_data;
wire [4:0]  mw_rd;
wire        mw_rd_we, mw_rd_fp;
wire [31:0] mw_result;
wire        mw_load, mw_store;
wire [1:0]  mw_mem_size;
wire        mw_mem_unsigned;
wire [1:0]  mw_addr_lo;
wire [31:0] mw_mem_addr;
wire [3:0]  mw_mem_be;
wire [31:0] mw_mem_wdata;
wire        mw_trap;
wire [4:0]  mw_fflags;

//WB
wire        wb_pending, wb_wait, wb_fault;
wire [4:0]  wb_fault_cause;
wire [31:0] wb_fault_tval;
wire        wb_we, wb_fp;
wire [4:0]  wb_rd;
wire [31:0] wb_data;

//CSR unit
wire [31:0] csr_rdata, trap_vector, mepc;
wire        irq_pending, fs_off;
wire [4:0]  irq_cause;
wire [2:0]  frm;

//traps from WB (access faults) win over MEM
wire        trap_take  = wb_fault || mem_trap;
wire        trap_intr  = wb_fault ? 1'b0 : em_trap_intr;
wire [4:0]  trap_cause = wb_fault ? wb_fault_cause : mem_trap_cause;
wire [31:0] trap_pc    = wb_fault ? mw_pc : em_pc;
wire [31:0] trap_tval  = wb_fault ? wb_fault_tval : mem_trap_tval;

if_stage #(.RESET_VECTOR(RESET_VECTOR)) IF_STAGE
    (.clk_i(clk_i),
     .rst_ni(rst_ni),
     .instr_req_o(instr_req_o),
     .instr_gnt_i(instr_gnt_i),
     .instr_addr_o(instr_addr_o),
     .instr_rvalid_i(instr_rvalid_i),
     .instr_rdata_i(instr_rdata_i),
     .instr_err_i(instr_err_i),
     .redirect_i(redirect),
     .redirect_pc_i(redirect_pc),
     .stall_i(if_stall),
     .valid_o(if_valid),
     .pc_o(if_pc),
     .instr_o(if_instr),
     .fault_o(if_fault));

regfile REGFILE
    (.clk_i(clk_i),
     .rs1_i(rf_rs1),
     .rs2_i(rf_rs2),
     .rs3_i(rf_rs3),
     .rs1_fp_i(rf_rs1_fp),
     .rs2_fp_i(rf_rs2_fp),
     .rs1_data_o(rf_rs1_data),
     .rs2_data_o(rf_rs2_data),
     .rs3_data_o(rf_rs3_data),
     .we_i(wb_we),
     .rd_fp_i(wb_fp),
     .rd_i(wb_rd),
     .rd_data_i(wb_data));

id_stage ID_STAGE
    (.clk_i(clk_i),
     .rst_ni(rst_ni),
     .valid_i(if_valid),
     .pc_i(if_pc),
     .instr_i(if_instr),
     .fault_i(if_fault),
     .fs_off_i(fs_off),
     .frm_i(frm),
     .irq_i(irq_pending && if_valid),
     .irq_cause_i(irq_cause),
     .rs1_o(rf_rs1),
     .rs2_o(rf_rs2),
     .rs3_o(rf_rs3),
     .rs1_fp_o(rf_rs1_fp),
     .rs2_fp_o(rf_rs2_fp),
     .rs1_data_i(rf_rs1_data),
     .rs2_data_i(rf_rs2_data),
     .rs3_data_i(rf_rs3_data),
     .rs1_used_o(id_rs1_used),
     .rs2_used_o(id_rs2_used),
     .rs3_used_o(id_rs3_used),
     .jal_redirect_o(id_jal),
     .jal_target_o(id_jal_pc),
     .hold_i(id_hold),
     .bubble_i(id_bubble),
     .flush_i(id_flush),
     .valid_o(de_valid),
     .pc_o(de_pc),
     .instr_o(de_instr),
     .next_pc_o(de_next_pc),
     .rs1_q_o(de_rs1),
     .rs2_q_o(de_rs2),
     .rs3_q_o(de_rs3),
     .rs1_fp_q_o(de_rs1_fp),
     .rs2_fp_q_o(de_rs2_fp),
     .rs1_used_q_o(de_rs1_used),
     .rs2_used_q_o(de_rs2_used),
     .rs3_used_q_o(de_rs3_used),
     .rs1_data_o(de_rs1_data),
     .rs2_data_o(de_rs2_data),
     .rs3_data_o(de_rs3_data),
     .rd_o(de_rd),
     .rd_we_o(de_rd_we),
     .rd_fp_o(de_rd_fp),
     .imm_o(de_imm),
     .alu_func_o(de_alu_func),
     .alu_a_pc_o(de_alu_a_pc),
     .alu_b_imm_o(de_alu_b_imm),
     .res_sel_o(de_res_sel),
     .branch_o(de_branch),
     .jalr_o(de_jalr),
     .load_o(de_load),
     .store_o(de_store),
     .mem_size_o(de_mem_size),
     .mem_unsigned_o(de_mem_unsigned),
     .mul_o(de_mul),
     .div_o(de_div),
     .fpu_o(de_fpu),
     .fpu_op_o(de_fpu_op),
     .fpu_rm_o(de_fpu_rm),
     .csr_o(de_csr),
     .csr_we_o(de_csr_we),
     .csr_imm_o(de_csr_imm),
     .mret_o(de_mret),
     .fence_i_o(de_fence_i),
     .trap_o(de_trap),
     .trap_intr_o(de_trap_intr),
     .trap_cause_o(de_trap_cause),
     .trap_tval_o(de_trap_tval));

hazard_unit HAZARD_UNIT
    (.id_valid_i(if_valid),
     .id_rs1_i(rf_rs1),
     .id_rs2_i(rf_rs2),
     .id_rs3_i(rf_rs3),
     .id_rs1_fp_i(rf_rs1_fp),
     .id_rs2_fp_i(rf_rs2_fp),
     .id_rs1_used_i(id_rs1_used),
     .id_rs2_used_i(id_rs2_used),
     .id_rs3_used_i(id_rs3_used),
     .id_jal_i(id_jal),
     .id_jal_pc_i(id_jal_pc),
     .ex_valid_i(de_valid),
     .ex_rs1_i(de_rs1),
     .ex_rs2_i(de_rs2),
     .ex_rs3_i(de_rs3),
     .ex_rs1_fp_i(de_rs1_fp),
     .ex_rs2_fp_i(de_rs2_fp),
     .ex_rd_i(de_rd),
     .ex_rd_we_i(de_rd_we),
     .ex_rd_fp_i(de_rd_fp),
     .ex_late_i(de_load || de_mul || de_csr),
     .ex_busy_i(ex_busy),
     .ex_redirect_i(ex_redirect),
     .ex_redirect_pc_i(ex_redirect_pc),
     .mem_valid_i(em_valid),
     .mem_rd_i(em_rd),
     .mem_rd_we_i(em_rd_we),
     .mem_rd_fp_i(em_rd_fp),
     .mem_wait_i(mem_wait),
     .mem_redirect_i(mem_redirect),
     .mem_redirect_pc_i(mem_redirect_pc),
     .wb_rd_i(wb_rd),
     .wb_rd_we_i(wb_we),
     .wb_rd_fp_i(wb_fp),
     .wb_wait_i(wb_wait),
     .wb_fault_i(wb_fault),
     .wb_fault_pc_i(trap_vector),
     .hold_o(hold),
     .if_stall_o(if_stall),
     .id_hold_o(id_hold),
     .id_bubble_o(id_bubble),
     .id_flush_o(id_flush),
     .ex_flush_o(ex_flush),
     .redirect_o(redirect),
     .redirect_pc_o(redirect_pc),
     .fwd_a_o(fwd_a),
     .fwd_b_o(fwd_b),
     .fwd_c_o(fwd_c));

ex_stage EX_STAGE
    (.clk_i(clk_i),
     .rst_ni(rst_ni),
     .valid_i(de_valid),
     .pc_i(de_pc),
     .instr_i(de_instr),
     .next_pc_i(de_next_pc),
     .rs1_i(de_rs1),
     .rs2_i(de_rs2),
     .rs1_fp_i(de_rs1_fp),
     .rs2_fp_i(de_rs2_fp),
     .rs1_used_i(de_rs1_used),
     .rs2_used_i(de_rs2_used),
     .rs3_used_i(de_rs3_used),
     .rs1_data_i(de_rs1_data),
     .rs2_data_i(de_rs2_data),
     .rs3_data_i(de_rs3_data),
     .rd_i(de_rd),
     .rd_we_i(de_rd_we),
     .rd_fp_i(de_rd_fp),
     .imm_i(de_imm),
     .alu_func_i(de_alu_func),
     .alu_a_pc_i(de_alu_a_pc),
     .alu_b_imm_i(de_alu_b_imm),
     .res_sel_i(de_res_sel),
     .branch_i(de_branch),
     .jalr_i(de_jalr),
     .load_i(de_load),
     .store_i(de_store),
     .mem_size_i(de_mem_size),
     .mem_unsigned_i(de_mem_unsigned),
     .mul_i(de_mul),
     .div_i(de_div),
     .fpu_i(de_fpu),
     .fpu_op_i(de_fpu_op),
     .fpu_rm_i(de_fpu_rm),
     .csr_i(de_csr),
     .csr_we_i(de_csr_we),
     .csr_imm_i(de_csr_imm),
     .mret_i(de_mret),
     .fence_i_i(de_fence_i),
     .trap_i(de_trap),
     .trap_intr_i(de_trap_intr),
     .trap_cause_i(de_trap_cause),
     .trap_tval_i(de_trap_tval),
     .fwd_a_i(fwd_a),
     .fwd_b_i(fwd_b),
     .fwd_c_i(fwd_c),
     .mem_fwd_i(em_result),
     .wb_fwd_i(wb_data),
     .hold_i(hold),
     .flush_i(ex_flush),
     .busy_o(ex_busy),
     .redirect_o(ex_redirect),
     .redirect_pc_o(ex_redirect_pc),
     .valid_o(em_valid),
     .pc_o(em_pc),
     .instr_o(em_instr),
     .next_pc_o(em_next_pc),
     .rs1_o(em_rs1),
     .rs2_o(em_rs2),
     .rs1_fp_o(em_rs1_fp),
     .rs2_fp_o(em_rs2_fp),
     .rs1_used_o(em_rs1_used),
     .rs2_used_o(em_rs2_used),
     .rs1_data_o(em_rs1_data),
     .rs2_data_o(em_rs2_data),
     .rd_o(em_rd),
     .rd_we_o(em_rd_we),
     .rd_fp_o(em_rd_fp),
     .result_o(em_result),
     .load_o(em_load),
     .store_o(em_store),
     .mem_size_o(em_mem_size),
     .mem_unsigned_o(em_mem_unsigned),
     .mul_o(em_mul),
     .fpu_o(em_fpu),
     .fflags_o(em_fflags),
     .csr_o(em_csr),
     .csr_we_o(em_csr_we),
     .mret_o(em_mret),
     .fence_i_o(em_fence_i),
     .trap_o(em_trap),
     .trap_intr_o(em_trap_intr),
     .trap_cause_o(em_trap_cause),
     .trap_tval_o(em_trap_tval));

mem_stage MEM_STAGE
    (.clk_i(clk_i),
     .rst_ni(rst_ni),
     .valid_i(em_valid),
     .pc_i(em_pc),
     .instr_i(em_instr),
     .next_pc_i(em_next_pc),
     .rs1_i(em_rs1),
     .rs2_i(em_rs2),
     .rs1_fp_i(em_rs1_fp),
     .rs2_fp_i(em_rs2_fp),
     .rs1_used_i(em_rs1_used),
     .rs2_used_i(em_rs2_used),
     .rs1_data_i(em_rs1_data),
     .rs2_data_i(em_rs2_data),
     .rd_i(em_rd),
     .rd_we_i(em_rd_we),
     .rd_fp_i(em_rd_fp),
     .result_i(em_result),
     .load_i(em_load),
     .store_i(em_store),
     .mem_size_i(em_mem_size),
     .mem_unsigned_i(em_mem_unsigned),
     .mul_i(em_mul),
     .fpu_i(em_fpu),
     .fflags_i(em_fflags),
     .csr_i(em_csr),
     .csr_we_i(em_csr_we),
     .mret_i(em_mret),
     .fence_i_i(em_fence_i),
     .trap_i(em_trap),
     .trap_intr_i(em_trap_intr),
     .trap_cause_i(em_trap_cause),
     .trap_tval_i(em_trap_tval),
     .data_req_o(data_req_o),
     .data_gnt_i(data_gnt_i),
     .data_we_o(data_we_o),
     .data_be_o(data_be_o),
     .data_addr_o(data_addr_o),
     .data_wdata_o(data_wdata_o),
     .data_rvalid_i(data_rvalid_i),
     .wb_pending_i(wb_pending),
     .wb_fault_i(wb_fault),
     .hold_i(hold),
     .wait_o(mem_wait),
     .trap_o(mem_trap),
     .trap_cause_o(mem_trap_cause),
     .trap_tval_o(mem_trap_tval),
     .mret_o(mem_mret),
     .retire_o(mem_retire),
     .csr_we_o(mem_csr_we),
     .fp_dirty_o(mem_fp_dirty),
     .fflags_o(mem_fflags),
     .csr_rdata_i(csr_rdata),
     .trap_pc_i(trap_vector),
     .mepc_i(mepc),
     .redirect_o(mem_redirect),
     .redirect_pc_o(mem_redirect_pc),
     .valid_o(mw_valid),
     .intr_o(mw_intr),
     .pc_o(mw_pc),
     .instr_o(mw_instr),
     .next_pc_o(mw_next_pc),
     .rs1_o(mw_rs1),
     .rs2_o(mw_rs2),
     .rs1_fp_o(mw_rs1_fp),
     .rs2_fp_o(mw_rs2_fp),
     .rs1_used_o(mw_rs1_used),
     .rs2_used_o(mw_rs2_used),
     .rs1_data_o(mw_rs1_data),
     .rs2_data_o(mw_rs2_data),
     .rd_o(mw_rd),
     .rd_we_o(mw_rd_we),
     .rd_fp_o(mw_rd_fp),
     .result_o(mw_result),
     .load_o(mw_load),
     .store_o(mw_store),
     .mem_size_o(mw_mem_size),
     .mem_unsigned_o(mw_mem_unsigned),
     .addr_lo_o(mw_addr_lo),
     .mem_addr_o(mw_mem_addr),
     .mem_be_o(mw_mem_be),
     .mem_wdata_o(mw_mem_wdata),
     .trap_q_o(mw_trap),
     .fflags_q_o(mw_fflags));

csr_unit #(.MTVEC_RESET(MTVEC_RESET), .HART_ID(HART_ID)) CSR_UNIT
    (.clk_i(clk_i),
     .rst_ni(rst_ni),
     .csr_addr_i(em_instr[31:20]),
     .csr_op_i(em_instr[13:12]),
     .csr_src_i(em_result),
     .csr_we_i(mem_csr_we),
     .csr_rdata_o(csr_rdata),
     .trap_i(trap_take),
     .trap_intr_i(trap_intr),
     .trap_cause_i(trap_cause),
     .trap_pc_i(trap_pc),
     .trap_tval_i(trap_tval),
     .trap_vector_o(trap_vector),
     .mret_i(mem_mret),
     .mepc_o(mepc),
     .retire_i(mem_retire),
     .unretire_i(wb_fault),
     .fp_dirty_i(mem_fp_dirty),
     .fflags_i(mem_fflags),
     .msip_i(msip_i),
     .mtip_i(mtip_i),
     .meip_i(meip_i),
     .fast_irq_i(fast_irq_i),
     .mtime_i(mtime_i),
     .irq_pending_o(irq_pending),
     .irq_cause_o(irq_cause),
     .fs_off_o(fs_off),
     .frm_o(frm),
     .mcycle_o(rvfi_mcycle),
     .minstret_o(rvfi_minstret));

wb_stage WB_STAGE
    (.clk_i(clk_i),
     .rst_ni(rst_ni),
     .valid_i(mw_valid),
     .intr_i(mw_intr),
     .pc_i(mw_pc),
     .instr_i(mw_instr),
     .next_pc_i(mw_next_pc),
     .rs1_i(mw_rs1),
     .rs2_i(mw_rs2),
     .rs1_fp_i(mw_rs1_fp),
     .rs2_fp_i(mw_rs2_fp),
     .rs1_used_i(mw_rs1_used),
     .rs2_used_i(mw_rs2_used),
     .rs1_data_i(mw_rs1_data),
     .rs2_data_i(mw_rs2_data),
     .rd_i(mw_rd),
     .rd_we_i(mw_rd_we),
     .rd_fp_i(mw_rd_fp),
     .result_i(mw_result),
     .load_i(mw_load),
     .store_i(mw_store),
     .mem_size_i(mw_mem_size),
     .mem_unsigned_i(mw_mem_unsigned),
     .addr_lo_i(mw_addr_lo),
     .mem_addr_i(mw_mem_addr),
     .mem_be_i(mw_mem_be),
     .mem_wdata_i(mw_mem_wdata),
     .trap_i(mw_trap),
     .fflags_i(mw_fflags),
     .data_rvalid_i(data_rvalid_i),
     .data_rdata_i(data_rdata_i),
     .data_err_i(data_err_i),
     .hold_i(hold),
     .pending_o(wb_pending),
     .wait_o(wb_wait),
     .fault_o(wb_fault),
     .fault_cause_o(wb_fault_cause),
     .fault_tval_o(wb_fault_tval),
     .trap_pc_i(trap_vector),
     .rf_we_o(wb_we),
     .rf_fp_o(wb_fp),
     .rf_rd_o(wb_rd),
     .rf_data_o(wb_data),
     .rvfi_valid(rvfi_valid),
     .rvfi_order(rvfi_order),
     .rvfi_insn(rvfi_insn),
     .rvfi_trap(rvfi_trap),
     .rvfi_halt(rvfi_halt),
     .rvfi_intr(rvfi_intr),
     .rvfi_mode(rvfi_mode),
     .rvfi_ixl(rvfi_ixl),
     .rvfi_rs1_addr(rvfi_rs1_addr),
     .rvfi_rs2_addr(rvfi_rs2_addr),
     .rvfi_rs1_rdata(rvfi_rs1_rdata),
     .rvfi_rs2_rdata(rvfi_rs2_rdata),
     .rvfi_rd_addr(rvfi_rd_addr),
     .rvfi_rd_wdata(rvfi_rd_wdata),
     .rvfi_pc_rdata(rvfi_pc_rdata),
     .rvfi_pc_wdata(rvfi_pc_wdata),
     .rvfi_mem_addr(rvfi_mem_addr),
     .rvfi_mem_rmask(rvfi_mem_rmask),
     .rvfi_mem_wmask(rvfi_mem_wmask),
     .rvfi_mem_rdata(rvfi_mem_rdata),
     .rvfi_mem_wdata(rvfi_mem_wdata),
     .rvfi_frd_we(rvfi_frd_we),
     .rvfi_frd_addr(rvfi_frd_addr),
     .rvfi_frd_wdata(rvfi_frd_wdata),
     .rvfi_fflags(rvfi_fflags));

endmodule
