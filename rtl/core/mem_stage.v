// MEM: data request, multiplier, CSR access, trap commit and the MEM/WB register
`include "hornet_defs.vh"

module mem_stage(input             clk_i,
                 input             rst_ni,

                 //from EX/MEM
                 input             valid_i,
                 input      [31:0] pc_i,
                 input      [31:0] instr_i,
                 input      [31:0] next_pc_i,
                 input      [4:0]  rs1_i, rs2_i,
                 input             rs1_fp_i, rs2_fp_i,
                 input             rs1_used_i, rs2_used_i,
                 input      [31:0] rs1_data_i, rs2_data_i,
                 input      [4:0]  rd_i,
                 input             rd_we_i, rd_fp_i,
                 input      [31:0] result_i,
                 input             load_i, store_i,
                 input      [1:0]  mem_size_i,
                 input             mem_unsigned_i,
                 input             mul_i,
                 input             fpu_i,
                 input      [4:0]  fflags_i,
                 input             csr_i, csr_we_i,
                 input             mret_i, fence_i_i,
                 input             trap_i, trap_intr_i,
                 input      [4:0]  trap_cause_i,
                 input      [31:0] trap_tval_i,

                 //data port request
                 output            data_req_o,
                 input             data_gnt_i,
                 output            data_we_o,
                 output     [3:0]  data_be_o,
                 output     [31:0] data_addr_o,
                 output     [31:0] data_wdata_o,
                 input             data_rvalid_i,

                 input             wb_pending_i, //WB waits for a response
                 input             wb_fault_i,   //access fault in WB, nothing in MEM commits
                 input             hold_i,
                 output            wait_o,       //request not granted yet

                 //CSR unit
                 output            commit_o,     //the instruction leaves MEM this cycle
                 output            trap_o,       //it traps
                 output            trap_intr_o,
                 output     [4:0]  trap_cause_o,
                 output     [31:0] trap_tval_o,
                 output            mret_o,
                 output            retire_o,     //counts in minstret
                 output            csr_we_o,
                 output            fp_dirty_o,   //sets mstatus.FS to dirty
                 output     [4:0]  fflags_o,     //accumulated into fflags
                 input      [31:0] csr_rdata_i,
                 input      [31:0] trap_pc_i,    //handler address of this trap
                 input      [31:0] mepc_i,
                 output            redirect_o,
                 output reg [31:0] redirect_pc_o,

                 output reg        valid_o,
                 output reg        intr_o,       //next retired instruction starts an interrupt handler
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
                 output reg        load_o, store_o, //a response is expected in WB
                 output reg [1:0]  mem_size_o,
                 output reg        mem_unsigned_o,
                 output reg [1:0]  addr_lo_o,
                 output reg [31:0] mem_addr_o,
                 output reg [3:0]  mem_be_o,
                 output reg [31:0] mem_wdata_o,
                 output reg        trap_q_o,
                 output reg [4:0]  fflags_q_o);

//load/store unit
wire [1:0] lo = result_i[1:0];
wire misaligned = (mem_size_i == 2'd1 && lo[0]) || (mem_size_i == 2'd2 && lo != 2'd0);
wire access = valid_i && (load_i || store_i) && !trap_i;
wire need_req = access && !misaligned;

assign data_addr_o  = {result_i[31:2], 2'b0};
assign data_we_o    = store_i;
assign data_be_o    = mem_size_i == 2'd0 ? 4'b0001 << lo
                    : mem_size_i == 2'd1 ? 4'b0011 << lo
                    : 4'b1111;
assign data_wdata_o = rs2_data_i << {lo, 3'b0};
assign data_req_o   = need_req && (!wb_pending_i || data_rvalid_i) && !wb_fault_i;
assign wait_o       = need_req && !(data_req_o && data_gnt_i) && !wb_fault_i;

//traps
wire       trap  = trap_i || (access && misaligned);
wire [4:0] cause = trap_i ? trap_cause_i : load_i ? `EXC_LOAD_MISALIGNED : `EXC_STORE_MISALIGNED;
wire [31:0] tval = trap_i ? trap_tval_i : result_i;

assign commit_o     = valid_i && !hold_i && !wb_fault_i;
assign trap_o       = commit_o && trap;
assign trap_intr_o  = trap_intr_i;
assign trap_cause_o = cause;
assign trap_tval_o  = tval;
assign mret_o       = commit_o && !trap && mret_i;
assign retire_o     = commit_o && !trap;
assign csr_we_o     = commit_o && !trap && csr_i && csr_we_i;
assign fp_dirty_o   = commit_o && !trap && ((rd_we_i && rd_fp_i) || (fpu_i && fflags_i != 5'b0));
assign fflags_o     = fpu_i ? fflags_i : 5'b0;

wire [11:0] csr_addr = instr_i[31:20];
wire refetch = commit_o && !trap && (fence_i_i ||
               (csr_we_o && (csr_addr == `CSR_MSTATUS || csr_addr == `CSR_MIE ||
                             csr_addr == `CSR_FRM || csr_addr == `CSR_FCSR)));

assign redirect_o = trap_o || mret_o || refetch;
always @*
begin
    if(trap)
        redirect_pc_o = trap_pc_i;
    else if(mret_i)
        redirect_pc_o = mepc_i;
    else
        redirect_pc_o = pc_i + 32'd4;
end

reg intr_pend_q;

//multiplier
wire [31:0] mul_out;
mul MUL(.op_i(instr_i[13:12]), .a_i(rs1_data_i), .b_i(rs2_data_i), .result_o(mul_out));

always @(posedge clk_i or negedge rst_ni)
begin
    if(!rst_ni)
    begin
        valid_o <= 1'b0;
        intr_o <= 1'b0;
        intr_pend_q <= 1'b0;
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
        addr_lo_o <= 2'b0;
        mem_addr_o <= 32'b0;
        mem_be_o <= 4'b0;
        mem_wdata_o <= 32'b0;
        trap_q_o <= 1'b0;
        fflags_q_o <= 5'b0;
    end
    else if(wb_fault_i)
        valid_o <= 1'b0;
    else if(!hold_i)
    begin
        //an interrupt carrier does not retire; the handler's first instruction reports it
        valid_o <= valid_i && !(trap && trap_intr_i);
        if(valid_i && trap && trap_intr_i)
            intr_pend_q <= 1'b1;
        else if(valid_i)
        begin
            intr_o <= intr_pend_q;
            intr_pend_q <= 1'b0;
        end
        pc_o <= pc_i;
        instr_o <= instr_i;
        next_pc_o <= redirect_o ? redirect_pc_o : next_pc_i;
        rs1_o <= rs1_i;
        rs2_o <= rs2_i;
        rs1_fp_o <= rs1_fp_i;
        rs2_fp_o <= rs2_fp_i;
        rs1_used_o <= rs1_used_i;
        rs2_used_o <= rs2_used_i;
        rs1_data_o <= rs1_data_i;
        rs2_data_o <= rs2_data_i;
        rd_o <= rd_i;
        rd_we_o <= rd_we_i && !trap;
        rd_fp_o <= rd_fp_i;
        result_o <= csr_i ? csr_rdata_i : mul_i ? mul_out : result_i;
        load_o <= need_req && load_i;
        store_o <= need_req && store_i;
        mem_size_o <= mem_size_i;
        mem_unsigned_o <= mem_unsigned_i;
        addr_lo_o <= lo;
        mem_addr_o <= data_addr_o;
        mem_be_o <= data_be_o;
        mem_wdata_o <= data_wdata_o;
        trap_q_o <= trap;
        fflags_q_o <= fflags_o;
    end
end

endmodule
