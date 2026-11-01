// EX: forwarding, ALU, branches, divider, FPU and the EX/MEM register
`include "hornet_defs.vh"

module ex_stage #(parameter RV_M = 1, parameter RV_F = 1)
               (input             clk_i,
                input             rst_ni,

                //from ID/EX
                input             valid_i,
                input      [31:0] pc_i,
                input      [31:0] instr_i,
                input      [31:0] next_pc_i,
                input      [4:0]  rs1_i, rs2_i,
                input             rs1_fp_i, rs2_fp_i,
                input             rs1_used_i, rs2_used_i, rs3_used_i,
                input      [31:0] rs1_data_i, rs2_data_i, rs3_data_i,
                input      [4:0]  rd_i,
                input             rd_we_i, rd_fp_i,
                input      [31:0] imm_i,
                input      [3:0]  alu_func_i,
                input             alu_a_pc_i, alu_b_imm_i,
                input      [1:0]  res_sel_i,
                input             branch_i, jalr_i,
                input             load_i, store_i,
                input      [1:0]  mem_size_i,
                input             mem_unsigned_i,
                input             mul_i, div_i,
                input             fpu_i,
                input      [4:0]  fpu_op_i,
                input      [2:0]  fpu_rm_i,
                input             csr_i, csr_we_i, csr_imm_i,
                input             mret_i, fence_i_i,
                input             trap_i, trap_intr_i,
                input      [4:0]  trap_cause_i,
                input      [31:0] trap_tval_i,

                //forwarding: 0 = ID/EX, 1 = MEM, 2 = WB
                input      [1:0]  fwd_a_i, fwd_b_i, fwd_c_i,
                input      [31:0] mem_fwd_i, wb_fwd_i,

                input             hold_i,   //memory wait: everything stays
                input             flush_i,  //EX/MEM is cleared, the instruction in EX is killed
                output            busy_o,   //a multi-cycle unit is not done
                output            redirect_o,
                output     [31:0] redirect_pc_o,
                output     [31:0] redirect_pc4_o,

                output reg        valid_o,
                output reg [31:0] pc_o,
                output reg [31:0] instr_o,
                output reg [31:0] next_pc_o,
                output reg [4:0]  rs1_o, rs2_o,
                output reg        rs1_fp_o, rs2_fp_o,
                output reg        rs1_used_o, rs2_used_o,
                output reg [31:0] rs1_data_o, rs2_data_o,
                output reg [4:0]  rd_o,
                output reg        rd_we_o, rd_fp_o,
                output reg [31:0] result_o,
                output reg        load_o, store_o,
                output reg [1:0]  mem_size_o,
                output reg        mem_unsigned_o,
                output reg        mul_o,
                output reg        fpu_o,
                output reg [4:0]  fflags_o,
                output reg        csr_o, csr_we_o,
                output reg        mret_o, fence_i_o,
                output reg        trap_o, trap_intr_o,
                output reg [4:0]  trap_cause_o,
                output reg [31:0] trap_tval_o);

wire [31:0] rs1_fwd = fwd_a_i == 2'd1 ? mem_fwd_i : fwd_a_i == 2'd2 ? wb_fwd_i : rs1_data_i;
wire [31:0] rs2_fwd = fwd_b_i == 2'd1 ? mem_fwd_i : fwd_b_i == 2'd2 ? wb_fwd_i : rs2_data_i;
wire [31:0] rs3_fwd = fwd_c_i == 2'd1 ? mem_fwd_i : fwd_c_i == 2'd2 ? wb_fwd_i : rs3_data_i;

//unused operands are reported as zero
wire [31:0] op_a = rs1_used_i ? rs1_fwd : 32'b0;
wire [31:0] op_b = rs2_used_i ? rs2_fwd : 32'b0;
wire [31:0] op_c = rs3_used_i ? rs3_fwd : 32'b0;

//ALU
wire [31:0] alu_out;
ALU ALU(.src1(alu_a_pc_i ? pc_i : op_a),
        .src2(alu_b_imm_i ? imm_i : op_b),
        .func(alu_func_i),
        .alu_out(alu_out));

//branches and JALR
wire [31:0] jalr_sum   = op_a + imm_i;
wire [31:0] target     = jalr_i ? {jalr_sum[31:1], 1'b0} : pc_i + imm_i;
wire        taken      = jalr_i || (branch_i && alu_out[0]);
wire        misaligned = taken && target[1];
wire [31:0] pc4        = pc_i + 32'd4;
//target + 4 for the fetch unit, in parallel with the target
wire [31:0] jalr_sum4  = op_a + (imm_i + 32'd4);
wire [31:0] target4    = jalr_i ? {jalr_sum4[31:1], 1'b0} : pc4 + imm_i;
assign redirect_pc4_o  = target4;

assign redirect_o    = valid_i && taken && !misaligned;
assign redirect_pc_o = target;

//multi-cycle units leave EX by advancing or by a flush
wire leave = flush_i || (!hold_i && !busy_o);

//operands of a multi-cycle unit, captured in its first cycle
reg         started_q;
reg  [31:0] cap_a, cap_b, cap_c;
wire        start = valid_i && (div_i || fpu_i) && !started_q && !hold_i && !flush_i;

always @(posedge clk_i or negedge rst_ni)
begin
    if(!rst_ni)
    begin
        started_q <= 1'b0;
        {cap_a, cap_b, cap_c} <= 96'b0;
    end
    else if(leave)
        started_q <= 1'b0;
    else if(start)
    begin
        started_q <= 1'b1;
        cap_a <= op_a;
        cap_b <= op_b;
        cap_c <= op_c;
    end
end

wire [31:0] use_a = started_q ? cap_a : op_a;
wire [31:0] use_b = started_q ? cap_b : op_b;
wire [31:0] use_c = started_q ? cap_c : op_c;

//divider (M extension)
wire        div_done;
wire [31:0] div_out;
generate
if(RV_M != 0)
begin : M_DIV
    div DIV(.clk_i(clk_i),
            .rst_ni(rst_ni),
            .start_i(start && div_i),
            .kill_i(leave),
            .op_i(instr_i[13:12]),
            .a_i(op_a),
            .b_i(op_b),
            .done_o(div_done),
            .result_o(div_out));
end
else
begin : NO_DIV
    assign div_done = 1'b1;
    assign div_out  = 32'b0;
end
endgenerate

//FPU (F extension)
wire        fpu_multi, fpu_done;
wire [31:0] fpu_out;
wire [4:0]  fpu_flags;
generate
if(RV_F != 0)
begin : F_FPU
    fpu_top FPU(.clk_i(clk_i),
                .rst_ni(rst_ni),
                .start_i(start && fpu_i),
                .kill_i(leave),
                .op_i(fpu_op_i),
                .rm_i(fpu_rm_i),
                .a_i(use_a),
                .b_i(use_b),
                .c_i(use_c),
                .multi_o(fpu_multi),
                .done_o(fpu_done),
                .result_o(fpu_out),
                .flags_o(fpu_flags));
end
else
begin : NO_FPU
    assign fpu_multi = 1'b0;
    assign fpu_done  = 1'b1;
    assign fpu_out   = 32'b0;
    assign fpu_flags = 5'b0;
end
endgenerate

assign busy_o = valid_i && ((div_i && !div_done) || (fpu_i && fpu_multi && !fpu_done));

reg [31:0] result;
always @*
begin
    if(csr_i)
        result = csr_imm_i ? imm_i : op_a; //CSR source operand
    else
        case(res_sel_i)
            `RES_PC4: result = pc4;
            `RES_DIV: result = div_out;
            `RES_FPU: result = fpu_out;
            default:  result = alu_out;
        endcase
end

always @(posedge clk_i or negedge rst_ni)
begin
    if(!rst_ni)
    begin
        valid_o <= 1'b0;
        pc_o <= 32'b0;
        instr_o <= 32'b0;
        next_pc_o <= 32'b0;
        {rs1_o, rs2_o} <= 10'b0;
        {rs1_fp_o, rs2_fp_o, rs1_used_o, rs2_used_o} <= 4'b0;
        {rs1_data_o, rs2_data_o} <= 64'b0;
        rd_o <= 5'b0;
        {rd_we_o, rd_fp_o} <= 2'b0;
        result_o <= 32'b0;
        {load_o, store_o} <= 2'b0;
        mem_size_o <= 2'b0;
        mem_unsigned_o <= 1'b0;
        {mul_o, fpu_o} <= 2'b0;
        fflags_o <= 5'b0;
        {csr_o, csr_we_o, mret_o, fence_i_o} <= 4'b0;
        {trap_o, trap_intr_o} <= 2'b0;
        trap_cause_o <= 5'b0;
        trap_tval_o <= 32'b0;
    end
    else if(flush_i || (busy_o && !hold_i))
        valid_o <= 1'b0;
    else if(!hold_i)
    begin
        valid_o <= valid_i;
        pc_o <= pc_i;
        instr_o <= instr_i;
        next_pc_o <= branch_i || jalr_i ? (taken ? target : pc4) : next_pc_i;
        rs1_o <= rs1_i;
        rs2_o <= rs2_i;
        rs1_fp_o <= rs1_fp_i;
        rs2_fp_o <= rs2_fp_i;
        rs1_used_o <= rs1_used_i;
        rs2_used_o <= rs2_used_i;
        rs1_data_o <= use_a;
        rs2_data_o <= use_b;
        rd_o <= rd_i;
        rd_we_o <= rd_we_i && !misaligned;
        rd_fp_o <= rd_fp_i;
        result_o <= result;
        load_o <= load_i;
        store_o <= store_i;
        mem_size_o <= mem_size_i;
        mem_unsigned_o <= mem_unsigned_i;
        mul_o <= mul_i;
        fpu_o <= fpu_i;
        fflags_o <= fpu_i ? fpu_flags : 5'b0;
        csr_o <= csr_i;
        csr_we_o <= csr_we_i;
        mret_o <= mret_i;
        fence_i_o <= fence_i_i;
        if(!trap_i && misaligned)
        begin
            trap_o <= 1'b1;
            trap_intr_o <= 1'b0;
            trap_cause_o <= `EXC_INSN_MISALIGNED;
            trap_tval_o <= target;
        end
        else
        begin
            trap_o <= trap_i;
            trap_intr_o <= trap_intr_i;
            trap_cause_o <= trap_cause_i;
            trap_tval_o <= trap_tval_i;
        end
    end
end

endmodule
