/*
CSR Unit
This module contains the CSRs, takes traps and returns from them.
CSR instructions, traps and mret commit when they leave the MEM stage.
*/
`include "hornet_defs.vh"

//bits in the CSRs
`define mstatus_mie mstatus_mie_q
`define mstatus_mpie mstatus_mpie_q

module csr_unit #(parameter MTVEC_RESET = 32'h0000_0000,
                  parameter HART_ID     = 32'd0,
                  parameter IMP_ID      = 32'd0)
(input             clk_i,
 input             rst_ni,

 //CSR instruction in MEM
 input      [11:0] csr_addr_i,
 input      [1:0]  csr_op_i,   //01: write, 10: set, 11: clear
 input      [31:0] csr_src_i,
 input             csr_we_i,   //commits a write this cycle
 output reg [31:0] csr_rdata_o,

 //traps
 input             trap_i,     //take a trap this cycle
 input             trap_intr_i,
 input      [4:0]  trap_cause_i,
 input      [31:0] trap_pc_i,
 input      [31:0] trap_tval_i,
 output     [31:0] trap_vector_o, //handler address for trap_intr_i/trap_cause_i
 input             mret_i,
 output     [31:0] mepc_o,

 input             retire_i,   //an instruction retires (minstret)
 input             unretire_i, //the last retired instruction faulted in WB
 input             fp_dirty_i,
 input      [4:0]  fflags_i,   //accumulated into fflags

 //interrupts
 input             msip_i, mtip_i, meip_i,
 input      [15:0] fast_irq_i,
 input      [63:0] mtime_i,
 output            irq_pending_o,
 output reg [4:0]  irq_cause_o,

 output            fs_off_o,
 output     [2:0]  frm_o,

 //state for RVFI
 output     [63:0] mcycle_o, minstret_o);

reg         mstatus_mie_q, mstatus_mpie_q;
reg  [1:0]  mstatus_fs_q;
reg  [31:0] mie_q;
reg  [31:0] mtvec_q;
reg  [2:0]  mcountinhibit_q; //bit 1 is always 0
reg  [31:0] mscratch_q, mepc_q, mcause_q, mtval_q;
reg  [63:0] mcycle_q, minstret_q;
reg  [4:0]  fflags_q;
reg  [2:0]  frm_q;

wire [31:0] mstatus = {mstatus_fs_q == 2'b11, 16'b0, mstatus_fs_q, 2'b11, 3'b0, `mstatus_mpie, 3'b0, `mstatus_mie, 3'b0};
wire [31:0] mip     = {fast_irq_i, 4'b0, meip_i, 3'b0, mtip_i, 3'b0, msip_i, 3'b0};
wire [31:0] misa    = 32'h4000_1120; //RV32IMF

assign fs_off_o   = mstatus_fs_q == 2'b00;
assign frm_o      = frm_q;
assign mepc_o     = mepc_q;
assign mcycle_o   = mcycle_q;
assign minstret_o = minstret_q;

always @*
begin
    casez(csr_addr_i)
        `CSR_FFLAGS:        csr_rdata_o = {27'b0, fflags_q};
        `CSR_FRM:           csr_rdata_o = {29'b0, frm_q};
        `CSR_FCSR:          csr_rdata_o = {24'b0, frm_q, fflags_q};
        `CSR_MSTATUS:       csr_rdata_o = mstatus;
        `CSR_MISA:          csr_rdata_o = misa;
        `CSR_MIE:           csr_rdata_o = mie_q;
        `CSR_MTVEC:         csr_rdata_o = mtvec_q;
        `CSR_MCOUNTINHIBIT: csr_rdata_o = {29'b0, mcountinhibit_q};
        `CSR_MSCRATCH:      csr_rdata_o = mscratch_q;
        `CSR_MEPC:          csr_rdata_o = mepc_q;
        `CSR_MCAUSE:        csr_rdata_o = mcause_q;
        `CSR_MTVAL:         csr_rdata_o = mtval_q;
        `CSR_MIP:           csr_rdata_o = mip;
        `CSR_MCYCLE, `CSR_CYCLE:      csr_rdata_o = mcycle_q[31:0];
        `CSR_MCYCLEH, `CSR_CYCLEH:    csr_rdata_o = mcycle_q[63:32];
        `CSR_MINSTRET, `CSR_INSTRET:  csr_rdata_o = minstret_q[31:0];
        `CSR_MINSTRETH, `CSR_INSTRETH:csr_rdata_o = minstret_q[63:32];
        `CSR_TIME:          csr_rdata_o = mtime_i[31:0];
        `CSR_TIMEH:         csr_rdata_o = mtime_i[63:32];
        `CSR_MHARTID:       csr_rdata_o = HART_ID;
        `CSR_MIMPID:        csr_rdata_o = IMP_ID;
        default:            csr_rdata_o = 32'b0; //read-zero CSRs; illegal ones never get here
    endcase
end

wire [31:0] wdata = csr_op_i == 2'b01 ? csr_src_i
                  : csr_op_i == 2'b10 ? csr_rdata_o | csr_src_i
                  : csr_rdata_o & ~csr_src_i;

wire wr_mcycle    = csr_we_i && csr_addr_i == `CSR_MCYCLE;
wire wr_mcycleh   = csr_we_i && csr_addr_i == `CSR_MCYCLEH;
wire wr_minstret  = csr_we_i && csr_addr_i == `CSR_MINSTRET;
wire wr_minstreth = csr_we_i && csr_addr_i == `CSR_MINSTRETH;
wire wr_fp        = csr_we_i && (csr_addr_i == `CSR_FFLAGS || csr_addr_i == `CSR_FRM || csr_addr_i == `CSR_FCSR);

//vectored mode sends interrupts to BASE + 4 * cause
wire [31:0] base = {mtvec_q[31:2], 2'b0};
assign trap_vector_o = mtvec_q[0] && trap_intr_i ? base + {25'b0, trap_cause_i, 2'b0} : base;

//interrupts: fast lines 31..16, then MEI, MSI, MTI
wire [31:0] pending = mip & mie_q;
assign irq_pending_o = `mstatus_mie && pending != 32'b0;
integer k;
always @*
begin
    irq_cause_o = 5'd7;
    if(pending[11])
        irq_cause_o = 5'd11;
    else if(pending[3])
        irq_cause_o = 5'd3;
    for(k = 16; k < 32; k = k + 1)
        if(pending[k])
            irq_cause_o = k[4:0];
end

always @(posedge clk_i or negedge rst_ni)
begin
    if(!rst_ni)
    begin
        mstatus_mie_q <= 1'b0;
        mstatus_mpie_q <= 1'b0;
        mstatus_fs_q <= 2'b00;
        mie_q <= 32'b0;
        mtvec_q <= MTVEC_RESET;
        mcountinhibit_q <= 3'b0;
        mcause_q <= 32'b0;
        fflags_q <= 5'b0;
        frm_q <= 3'b0;
    end
    else
    begin
        if(trap_i)
        begin
            `mstatus_mpie <= `mstatus_mie;
            `mstatus_mie <= 1'b0;
            mepc_q <= {trap_pc_i[31:2], 2'b0};
            mcause_q <= {trap_intr_i, 26'b0, trap_cause_i};
            mtval_q <= trap_tval_i;
        end
        else if(mret_i)
        begin
            `mstatus_mie <= `mstatus_mpie;
            `mstatus_mpie <= 1'b1;
        end
        else if(csr_we_i)
        begin
            case(csr_addr_i)
                `CSR_MSTATUS:
                begin
                    `mstatus_mie <= wdata[3];
                    `mstatus_mpie <= wdata[7];
                    mstatus_fs_q <= wdata[14:13];
                end
                `CSR_MIE:           mie_q <= wdata & 32'hFFFF_0888;
                `CSR_MTVEC:         mtvec_q <= {wdata[31:2], 1'b0, wdata[1] ? mtvec_q[0] : wdata[0]};
                `CSR_MCOUNTINHIBIT: mcountinhibit_q <= {wdata[2], 1'b0, wdata[0]};
                `CSR_MSCRATCH:      mscratch_q <= wdata;
                `CSR_MEPC:          mepc_q <= {wdata[31:2], 2'b0};
                `CSR_MCAUSE:        mcause_q <= wdata;
                `CSR_MTVAL:         mtval_q <= wdata;
                `CSR_FFLAGS:        fflags_q <= wdata[4:0];
                `CSR_FRM:           frm_q <= wdata[2:0];
                `CSR_FCSR:          {frm_q, fflags_q} <= wdata[7:0];
                default: ;
            endcase
        end

        if(retire_i && fflags_i != 5'b0)
            fflags_q <= fflags_q | fflags_i;
        //a write to mstatus.FS wins over the dirty update of the same instruction
        if((fp_dirty_i || wr_fp) && !(csr_we_i && csr_addr_i == `CSR_MSTATUS))
            mstatus_fs_q <= 2'b11;
    end
end

//counters: an explicit write replaces the increment of the same instruction
always @(posedge clk_i or negedge rst_ni)
begin
    if(!rst_ni)
    begin
        mcycle_q <= 64'b0;
        minstret_q <= 64'b0;
    end
    else
    begin
        if(wr_mcycle)
            mcycle_q[31:0] <= wdata;
        else if(wr_mcycleh)
            mcycle_q[63:32] <= wdata;
        else if(!mcountinhibit_q[0])
            mcycle_q <= mcycle_q + 64'd1;

        if(wr_minstret)
            minstret_q[31:0] <= wdata;
        else if(wr_minstreth)
            minstret_q[63:32] <= wdata;
        else if(!mcountinhibit_q[2])
        begin
            if(retire_i)
                minstret_q <= minstret_q + 64'd1;
            else if(unretire_i)
                minstret_q <= minstret_q - 64'd1;
        end
    end
end

endmodule
