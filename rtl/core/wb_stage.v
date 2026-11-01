// WB: data response, load extension, register write, access faults and RVFI
`include "hornet_defs.vh"

module wb_stage(input             clk_i,
                input             rst_ni,

                //from MEM/WB
                input             valid_i,
                input             intr_i,
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
                input      [1:0]  addr_lo_i,
                input      [31:0] mem_addr_i,
                input      [3:0]  mem_be_i,
                input      [31:0] mem_wdata_i,
                input             trap_i,
                input      [4:0]  fflags_i,
                input             csr_i, csr_we_i,
                input      [31:0] csr_wdata_i,
                input      [63:0] mcycle_i, minstret_i,

                input             data_rvalid_i,
                input      [31:0] data_rdata_i,
                input             data_err_i,

                input             hold_i,
                output            pending_o, //waiting for the response, or receiving it now
                output            wait_o,    //the response has not arrived
                output            fault_o,   //access fault, taken in this cycle
                output     [4:0]  fault_cause_o,
                output     [31:0] fault_tval_o,
                input      [31:0] trap_pc_i, //handler address for the fault

                //register file write; also the WB forwarding value
                output            rf_we_o,
                output            rf_fp_o,
                output     [4:0]  rf_rd_o,
                output     [31:0] rf_data_o,

                output            rvfi_valid,
                output reg [63:0] rvfi_order,
                output     [31:0] rvfi_insn,
                output            rvfi_trap,
                output            rvfi_halt,
                output            rvfi_intr,
                output     [1:0]  rvfi_mode,
                output     [1:0]  rvfi_ixl,
                output     [4:0]  rvfi_rs1_addr,
                output     [4:0]  rvfi_rs2_addr,
                output     [31:0] rvfi_rs1_rdata,
                output     [31:0] rvfi_rs2_rdata,
                output     [4:0]  rvfi_rd_addr,
                output     [31:0] rvfi_rd_wdata,
                output     [31:0] rvfi_pc_rdata,
                output     [31:0] rvfi_pc_wdata,
                output     [31:0] rvfi_mem_addr,
                output     [3:0]  rvfi_mem_rmask,
                output     [3:0]  rvfi_mem_wmask,
                output     [31:0] rvfi_mem_rdata,
                output     [31:0] rvfi_mem_wdata,
                //float writes, not part of RVFI
                output            rvfi_frd_we,
                output     [4:0]  rvfi_frd_addr,
                output     [31:0] rvfi_frd_wdata,
                output     [4:0]  rvfi_fflags,
                //CSR access of a retired CSR instruction (riscv-formal CSR ports)
                output            rvfi_csr_valid,
                output     [11:0] rvfi_csr_addr,
                output            rvfi_csr_we,
                output     [31:0] rvfi_csr_rdata,
                output     [31:0] rvfi_csr_wdata,
                output     [63:0] rvfi_csr_mcycle,
                output     [63:0] rvfi_csr_minstret);

//a response that arrives while the pipeline is held is kept
reg        resp_q;
reg [31:0] resp_data_q;

wire access = valid_i && (load_i || store_i);
assign pending_o = access && !resp_q;
assign wait_o    = pending_o && !data_rvalid_i;
assign fault_o   = pending_o && data_rvalid_i && data_err_i;
assign fault_cause_o = load_i ? `EXC_LOAD_FAULT : `EXC_STORE_FAULT;
assign fault_tval_o  = {mem_addr_i[31:2], addr_lo_i};

always @(posedge clk_i or negedge rst_ni)
begin
    if(!rst_ni)
    begin
        resp_q <= 1'b0;
        resp_data_q <= 32'b0;
    end
    else if(!hold_i)
        resp_q <= 1'b0;
    else if(pending_o && data_rvalid_i)
    begin
        resp_q <= 1'b1;
        resp_data_q <= data_rdata_i;
    end
end

//load alignment and extension
wire [31:0] rdata   = resp_q ? resp_data_q : data_rdata_i;
wire [31:0] shifted = rdata >> {addr_lo_i, 3'b0};
reg  [31:0] load_data;
always @*
begin
    case(mem_size_i)
        2'd0: load_data = {{24{!mem_unsigned_i & shifted[7]}}, shifted[7:0]};
        2'd1: load_data = {{16{!mem_unsigned_i & shifted[15]}}, shifted[15:0]};
        default: load_data = shifted;
    endcase
end

wire trap = trap_i || fault_o;

assign rf_we_o   = valid_i && rd_we_i && !wait_o && !fault_o;
assign rf_fp_o   = rd_fp_i;
assign rf_rd_o   = rd_i;
assign rf_data_o = load_i ? load_data : result_i;

//RVFI
assign rvfi_valid     = valid_i && !hold_i;
assign rvfi_insn      = instr_i;
assign rvfi_trap      = trap;
assign rvfi_halt      = 1'b0;
assign rvfi_intr      = intr_i;
assign rvfi_mode      = 2'd3;
assign rvfi_ixl       = 2'd1;
assign rvfi_rs1_addr  = rs1_used_i && !rs1_fp_i ? rs1_i : 5'd0;
assign rvfi_rs2_addr  = rs2_used_i && !rs2_fp_i ? rs2_i : 5'd0;
assign rvfi_rs1_rdata = rvfi_rs1_addr != 5'd0 ? rs1_data_i : 32'b0;
assign rvfi_rs2_rdata = rvfi_rs2_addr != 5'd0 ? rs2_data_i : 32'b0;
assign rvfi_rd_addr   = rf_we_o && !rd_fp_i ? rd_i : 5'd0;
assign rvfi_rd_wdata  = rvfi_rd_addr != 5'd0 ? rf_data_o : 32'b0;
assign rvfi_pc_rdata  = pc_i;
assign rvfi_pc_wdata  = fault_o ? trap_pc_i : next_pc_i;
assign rvfi_mem_addr  = mem_addr_i;
assign rvfi_mem_rmask = load_i ? mem_be_i : 4'b0;
assign rvfi_mem_wmask = store_i ? mem_be_i : 4'b0;
assign rvfi_mem_rdata = load_i ? rdata : 32'b0;
assign rvfi_mem_wdata = store_i ? mem_wdata_i : 32'b0;
assign rvfi_frd_we    = rf_we_o && rd_fp_i;
assign rvfi_frd_addr  = rd_i;
assign rvfi_frd_wdata = rf_data_o;
assign rvfi_fflags    = fflags_i;
assign rvfi_csr_valid    = csr_i;
assign rvfi_csr_addr     = instr_i[31:20];
assign rvfi_csr_we       = csr_we_i;
assign rvfi_csr_rdata    = result_i;
assign rvfi_csr_wdata    = csr_wdata_i;
assign rvfi_csr_mcycle   = mcycle_i;
assign rvfi_csr_minstret = minstret_i;

always @(posedge clk_i or negedge rst_ni)
begin
    if(!rst_ni)
        rvfi_order <= 64'b0;
    else if(rvfi_valid)
        rvfi_order <= rvfi_order + 64'd1;
end

endmodule
