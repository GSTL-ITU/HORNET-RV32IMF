// riscv-formal wrapper for HORNET
//
// Both memory ports see a free environment: grants, response timing and
// data are unconstrained, except that a response only comes for a granted
// request. Bus errors are off (access faults are covered in simulation).
// Interrupt lines and mtime are free inputs. The core's side of the port
// protocol is asserted: a request stays stable until granted, and at most
// one request per port is outstanding.

module rvfi_wrapper (
    input         clock,
    input         reset,
    `RVFI_OUTPUTS
);
    (* keep *) `rvformal_rand_reg        instr_gnt;
    (* keep *) `rvformal_rand_reg        instr_rvalid_any;
    (* keep *) `rvformal_rand_reg [31:0] instr_rdata;
    (* keep *) `rvformal_rand_reg        data_gnt;
    (* keep *) `rvformal_rand_reg        data_rvalid_any;
    (* keep *) `rvformal_rand_reg [31:0] data_rdata;
    (* keep *) `rvformal_rand_reg [18:0] irq;
    (* keep *) `rvformal_rand_reg [63:0] mtime;

    (* keep *) wire        instr_req;
    (* keep *) wire [31:0] instr_addr;
    (* keep *) wire        data_req;
    (* keep *) wire        data_we;
    (* keep *) wire [3:0]  data_be;
    (* keep *) wire [31:0] data_addr;
    (* keep *) wire [31:0] data_wdata;

    reg  [1:0] instr_out, data_out; //granted requests without a response
    wire       instr_rvalid = instr_rvalid_any && instr_out != 0;
    wire       data_rvalid  = data_rvalid_any && data_out != 0;

    always @(posedge clock) begin
        if (reset) begin
            instr_out <= 0;
            data_out <= 0;
        end else begin
            instr_out <= instr_out + (instr_req && instr_gnt) - instr_rvalid;
            data_out <= data_out + (data_req && data_gnt) - data_rvalid;
        end
    end

    reg        past_valid = 0;
    reg        instr_wait, data_wait;
    reg [31:0] instr_addr_q, data_addr_q, data_wdata_q;
    reg [3:0]  data_be_q;
    reg        data_we_q;

    always @(posedge clock) begin
        past_valid   <= !reset;
        instr_wait   <= instr_req && !instr_gnt;
        data_wait    <= data_req && !data_gnt;
        instr_addr_q <= instr_addr;
        data_addr_q  <= data_addr;
        data_wdata_q <= data_wdata;
        data_be_q    <= data_be;
        data_we_q    <= data_we;
    end

    always @* begin
        if (!reset) begin
            assert (instr_out <= 1);
            assert (data_out <= 1);
        end
        if (past_valid && !reset && instr_wait)
            assert (instr_req && instr_addr == instr_addr_q);
        if (past_valid && !reset && data_wait)
            assert (data_req && data_addr == data_addr_q && data_we == data_we_q &&
                    data_be == data_be_q && (!data_we || data_wdata == data_wdata_q));
    end

    (* keep *) wire        core_csr_valid, core_csr_we;
    (* keep *) wire [11:0] core_csr_addr;
    (* keep *) wire [31:0] core_csr_rdata, core_csr_wdata;
    (* keep *) wire [63:0] core_csr_mcycle, core_csr_minstret;

    hornet_core #(.RESET_VECTOR(32'h8000_0000), .MTVEC_RESET(32'h8000_0100), .RV_M(%RV_M%), .RV_F(%RV_F%)) uut (
        .clk_i             (clock),
        .rst_ni            (!reset),
        .instr_req_o       (instr_req),
        .instr_gnt_i       (instr_gnt),
        .instr_addr_o      (instr_addr),
        .instr_rvalid_i    (instr_rvalid),
        .instr_rdata_i     (instr_rdata),
        .instr_err_i       (1'b0),
        .data_req_o        (data_req),
        .data_gnt_i        (data_gnt),
        .data_we_o         (data_we),
        .data_be_o         (data_be),
        .data_addr_o       (data_addr),
        .data_wdata_o      (data_wdata),
        .data_rvalid_i     (data_rvalid),
        .data_rdata_i      (data_rdata),
        .data_err_i        (1'b0),
        .msip_i            (irq[0]),
        .mtip_i            (irq[1]),
        .meip_i            (irq[2]),
        .fast_irq_i        (irq[18:3]),
        .mtime_i           (mtime),
        .rvfi_valid        (rvfi_valid),
        .rvfi_order        (rvfi_order),
        .rvfi_insn         (rvfi_insn),
        .rvfi_trap         (rvfi_trap),
        .rvfi_halt         (rvfi_halt),
        .rvfi_intr         (rvfi_intr),
        .rvfi_mode         (rvfi_mode),
        .rvfi_ixl          (rvfi_ixl),
        .rvfi_rs1_addr     (rvfi_rs1_addr),
        .rvfi_rs2_addr     (rvfi_rs2_addr),
        .rvfi_rs1_rdata    (rvfi_rs1_rdata),
        .rvfi_rs2_rdata    (rvfi_rs2_rdata),
        .rvfi_rd_addr      (rvfi_rd_addr),
        .rvfi_rd_wdata     (rvfi_rd_wdata),
        .rvfi_pc_rdata     (rvfi_pc_rdata),
        .rvfi_pc_wdata     (rvfi_pc_wdata),
        .rvfi_mem_addr     (rvfi_mem_addr),
        .rvfi_mem_rmask    (rvfi_mem_rmask),
        .rvfi_mem_wmask    (rvfi_mem_wmask),
        .rvfi_mem_rdata    (rvfi_mem_rdata),
        .rvfi_mem_wdata    (rvfi_mem_wdata),
        .rvfi_frd_we       (),
        .rvfi_frd_addr     (),
        .rvfi_frd_wdata    (),
        .rvfi_fflags       (),
        .rvfi_csr_valid    (core_csr_valid),
        .rvfi_csr_addr     (core_csr_addr),
        .rvfi_csr_we       (core_csr_we),
        .rvfi_csr_rdata    (core_csr_rdata),
        .rvfi_csr_wdata    (core_csr_wdata),
        .rvfi_csr_mcycle   (core_csr_mcycle),
        .rvfi_csr_minstret (core_csr_minstret)
    );

// CSR ports: every CSR named in checks.cfg (csr_spec 1.12 and [csrs]).
// A retired CSR instruction reports full masks, the old value and the value it wrote.
wire hit_mvendorid = core_csr_valid && core_csr_addr == 12'hF11;
assign rvfi_csr_mvendorid_rmask = {32{hit_mvendorid}};
assign rvfi_csr_mvendorid_wmask = {32{hit_mvendorid}};
assign rvfi_csr_mvendorid_rdata = hit_mvendorid ? core_csr_rdata : 32'b0;
assign rvfi_csr_mvendorid_wdata = hit_mvendorid ? core_csr_wdata : 32'b0;
wire hit_marchid = core_csr_valid && core_csr_addr == 12'hF12;
assign rvfi_csr_marchid_rmask = {32{hit_marchid}};
assign rvfi_csr_marchid_wmask = {32{hit_marchid}};
assign rvfi_csr_marchid_rdata = hit_marchid ? core_csr_rdata : 32'b0;
assign rvfi_csr_marchid_wdata = hit_marchid ? core_csr_wdata : 32'b0;
wire hit_mimpid = core_csr_valid && core_csr_addr == 12'hF13;
assign rvfi_csr_mimpid_rmask = {32{hit_mimpid}};
assign rvfi_csr_mimpid_wmask = {32{hit_mimpid}};
assign rvfi_csr_mimpid_rdata = hit_mimpid ? core_csr_rdata : 32'b0;
assign rvfi_csr_mimpid_wdata = hit_mimpid ? core_csr_wdata : 32'b0;
wire hit_mhartid = core_csr_valid && core_csr_addr == 12'hF14;
assign rvfi_csr_mhartid_rmask = {32{hit_mhartid}};
assign rvfi_csr_mhartid_wmask = {32{hit_mhartid}};
assign rvfi_csr_mhartid_rdata = hit_mhartid ? core_csr_rdata : 32'b0;
assign rvfi_csr_mhartid_wdata = hit_mhartid ? core_csr_wdata : 32'b0;
wire hit_mconfigptr = core_csr_valid && core_csr_addr == 12'hF15;
assign rvfi_csr_mconfigptr_rmask = {32{hit_mconfigptr}};
assign rvfi_csr_mconfigptr_wmask = {32{hit_mconfigptr}};
assign rvfi_csr_mconfigptr_rdata = hit_mconfigptr ? core_csr_rdata : 32'b0;
assign rvfi_csr_mconfigptr_wdata = hit_mconfigptr ? core_csr_wdata : 32'b0;
wire hit_mstatus = core_csr_valid && core_csr_addr == 12'h300;
assign rvfi_csr_mstatus_rmask = {32{hit_mstatus}};
assign rvfi_csr_mstatus_wmask = {32{hit_mstatus}};
assign rvfi_csr_mstatus_rdata = hit_mstatus ? core_csr_rdata : 32'b0;
assign rvfi_csr_mstatus_wdata = hit_mstatus ? core_csr_wdata : 32'b0;
wire hit_misa = core_csr_valid && core_csr_addr == 12'h301;
//misa is constant and read by every instruction model (IALIGN, M)
assign rvfi_csr_misa_rmask = {32{1'b1}};
assign rvfi_csr_misa_wmask = {32{hit_misa}};
assign rvfi_csr_misa_rdata = %MISA%;
assign rvfi_csr_misa_wdata = hit_misa ? core_csr_wdata : %MISA%;
wire hit_mie = core_csr_valid && core_csr_addr == 12'h304;
assign rvfi_csr_mie_rmask = {32{hit_mie}};
assign rvfi_csr_mie_wmask = {32{hit_mie}};
assign rvfi_csr_mie_rdata = hit_mie ? core_csr_rdata : 32'b0;
assign rvfi_csr_mie_wdata = hit_mie ? core_csr_wdata : 32'b0;
wire hit_mtvec = core_csr_valid && core_csr_addr == 12'h305;
assign rvfi_csr_mtvec_rmask = {32{hit_mtvec}};
assign rvfi_csr_mtvec_wmask = {32{hit_mtvec}};
assign rvfi_csr_mtvec_rdata = hit_mtvec ? core_csr_rdata : 32'b0;
assign rvfi_csr_mtvec_wdata = hit_mtvec ? core_csr_wdata : 32'b0;
wire hit_mstatush = core_csr_valid && core_csr_addr == 12'h310;
assign rvfi_csr_mstatush_rmask = {32{hit_mstatush}};
assign rvfi_csr_mstatush_wmask = {32{hit_mstatush}};
assign rvfi_csr_mstatush_rdata = hit_mstatush ? core_csr_rdata : 32'b0;
assign rvfi_csr_mstatush_wdata = hit_mstatush ? core_csr_wdata : 32'b0;
wire hit_mcountinhibit = core_csr_valid && core_csr_addr == 12'h320;
assign rvfi_csr_mcountinhibit_rmask = {32{hit_mcountinhibit}};
assign rvfi_csr_mcountinhibit_wmask = {32{hit_mcountinhibit}};
assign rvfi_csr_mcountinhibit_rdata = hit_mcountinhibit ? core_csr_rdata : 32'b0;
assign rvfi_csr_mcountinhibit_wdata = hit_mcountinhibit ? core_csr_wdata : 32'b0;
wire hit_mscratch = core_csr_valid && core_csr_addr == 12'h340;
assign rvfi_csr_mscratch_rmask = {32{hit_mscratch}};
assign rvfi_csr_mscratch_wmask = {32{hit_mscratch}};
assign rvfi_csr_mscratch_rdata = hit_mscratch ? core_csr_rdata : 32'b0;
assign rvfi_csr_mscratch_wdata = hit_mscratch ? core_csr_wdata : 32'b0;
wire hit_mepc = core_csr_valid && core_csr_addr == 12'h341;
assign rvfi_csr_mepc_rmask = {32{hit_mepc}};
assign rvfi_csr_mepc_wmask = {32{hit_mepc}};
assign rvfi_csr_mepc_rdata = hit_mepc ? core_csr_rdata : 32'b0;
assign rvfi_csr_mepc_wdata = hit_mepc ? core_csr_wdata : 32'b0;
wire hit_mcause = core_csr_valid && core_csr_addr == 12'h342;
assign rvfi_csr_mcause_rmask = {32{hit_mcause}};
assign rvfi_csr_mcause_wmask = {32{hit_mcause}};
assign rvfi_csr_mcause_rdata = hit_mcause ? core_csr_rdata : 32'b0;
assign rvfi_csr_mcause_wdata = hit_mcause ? core_csr_wdata : 32'b0;
wire hit_mtval = core_csr_valid && core_csr_addr == 12'h343;
assign rvfi_csr_mtval_rmask = {32{hit_mtval}};
assign rvfi_csr_mtval_wmask = {32{hit_mtval}};
assign rvfi_csr_mtval_rdata = hit_mtval ? core_csr_rdata : 32'b0;
assign rvfi_csr_mtval_wdata = hit_mtval ? core_csr_wdata : 32'b0;
wire hit_mip = core_csr_valid && core_csr_addr == 12'h344;
assign rvfi_csr_mip_rmask = {32{hit_mip}};
assign rvfi_csr_mip_wmask = {32{hit_mip}};
assign rvfi_csr_mip_rdata = hit_mip ? core_csr_rdata : 32'b0;
assign rvfi_csr_mip_wdata = hit_mip ? core_csr_wdata : 32'b0;
wire hit_mhpmevent3 = core_csr_valid && core_csr_addr == 12'h323;
assign rvfi_csr_mhpmevent3_rmask = {32{hit_mhpmevent3}};
assign rvfi_csr_mhpmevent3_wmask = {32{hit_mhpmevent3}};
assign rvfi_csr_mhpmevent3_rdata = hit_mhpmevent3 ? core_csr_rdata : 32'b0;
assign rvfi_csr_mhpmevent3_wdata = hit_mhpmevent3 ? core_csr_wdata : 32'b0;
wire hit_mhpmevent4 = core_csr_valid && core_csr_addr == 12'h324;
assign rvfi_csr_mhpmevent4_rmask = {32{hit_mhpmevent4}};
assign rvfi_csr_mhpmevent4_wmask = {32{hit_mhpmevent4}};
assign rvfi_csr_mhpmevent4_rdata = hit_mhpmevent4 ? core_csr_rdata : 32'b0;
assign rvfi_csr_mhpmevent4_wdata = hit_mhpmevent4 ? core_csr_wdata : 32'b0;
wire hit_mhpmevent5 = core_csr_valid && core_csr_addr == 12'h325;
assign rvfi_csr_mhpmevent5_rmask = {32{hit_mhpmevent5}};
assign rvfi_csr_mhpmevent5_wmask = {32{hit_mhpmevent5}};
assign rvfi_csr_mhpmevent5_rdata = hit_mhpmevent5 ? core_csr_rdata : 32'b0;
assign rvfi_csr_mhpmevent5_wdata = hit_mhpmevent5 ? core_csr_wdata : 32'b0;
wire hit_mhpmevent6 = core_csr_valid && core_csr_addr == 12'h326;
assign rvfi_csr_mhpmevent6_rmask = {32{hit_mhpmevent6}};
assign rvfi_csr_mhpmevent6_wmask = {32{hit_mhpmevent6}};
assign rvfi_csr_mhpmevent6_rdata = hit_mhpmevent6 ? core_csr_rdata : 32'b0;
assign rvfi_csr_mhpmevent6_wdata = hit_mhpmevent6 ? core_csr_wdata : 32'b0;
wire hit_mhpmevent7 = core_csr_valid && core_csr_addr == 12'h327;
assign rvfi_csr_mhpmevent7_rmask = {32{hit_mhpmevent7}};
assign rvfi_csr_mhpmevent7_wmask = {32{hit_mhpmevent7}};
assign rvfi_csr_mhpmevent7_rdata = hit_mhpmevent7 ? core_csr_rdata : 32'b0;
assign rvfi_csr_mhpmevent7_wdata = hit_mhpmevent7 ? core_csr_wdata : 32'b0;
wire hit_mhpmevent8 = core_csr_valid && core_csr_addr == 12'h328;
assign rvfi_csr_mhpmevent8_rmask = {32{hit_mhpmevent8}};
assign rvfi_csr_mhpmevent8_wmask = {32{hit_mhpmevent8}};
assign rvfi_csr_mhpmevent8_rdata = hit_mhpmevent8 ? core_csr_rdata : 32'b0;
assign rvfi_csr_mhpmevent8_wdata = hit_mhpmevent8 ? core_csr_wdata : 32'b0;
wire hit_mhpmevent9 = core_csr_valid && core_csr_addr == 12'h329;
assign rvfi_csr_mhpmevent9_rmask = {32{hit_mhpmevent9}};
assign rvfi_csr_mhpmevent9_wmask = {32{hit_mhpmevent9}};
assign rvfi_csr_mhpmevent9_rdata = hit_mhpmevent9 ? core_csr_rdata : 32'b0;
assign rvfi_csr_mhpmevent9_wdata = hit_mhpmevent9 ? core_csr_wdata : 32'b0;
wire hit_mhpmevent10 = core_csr_valid && core_csr_addr == 12'h32A;
assign rvfi_csr_mhpmevent10_rmask = {32{hit_mhpmevent10}};
assign rvfi_csr_mhpmevent10_wmask = {32{hit_mhpmevent10}};
assign rvfi_csr_mhpmevent10_rdata = hit_mhpmevent10 ? core_csr_rdata : 32'b0;
assign rvfi_csr_mhpmevent10_wdata = hit_mhpmevent10 ? core_csr_wdata : 32'b0;
wire hit_mhpmevent11 = core_csr_valid && core_csr_addr == 12'h32B;
assign rvfi_csr_mhpmevent11_rmask = {32{hit_mhpmevent11}};
assign rvfi_csr_mhpmevent11_wmask = {32{hit_mhpmevent11}};
assign rvfi_csr_mhpmevent11_rdata = hit_mhpmevent11 ? core_csr_rdata : 32'b0;
assign rvfi_csr_mhpmevent11_wdata = hit_mhpmevent11 ? core_csr_wdata : 32'b0;
wire hit_mhpmevent12 = core_csr_valid && core_csr_addr == 12'h32C;
assign rvfi_csr_mhpmevent12_rmask = {32{hit_mhpmevent12}};
assign rvfi_csr_mhpmevent12_wmask = {32{hit_mhpmevent12}};
assign rvfi_csr_mhpmevent12_rdata = hit_mhpmevent12 ? core_csr_rdata : 32'b0;
assign rvfi_csr_mhpmevent12_wdata = hit_mhpmevent12 ? core_csr_wdata : 32'b0;
wire hit_mhpmevent13 = core_csr_valid && core_csr_addr == 12'h32D;
assign rvfi_csr_mhpmevent13_rmask = {32{hit_mhpmevent13}};
assign rvfi_csr_mhpmevent13_wmask = {32{hit_mhpmevent13}};
assign rvfi_csr_mhpmevent13_rdata = hit_mhpmevent13 ? core_csr_rdata : 32'b0;
assign rvfi_csr_mhpmevent13_wdata = hit_mhpmevent13 ? core_csr_wdata : 32'b0;
wire hit_mhpmevent14 = core_csr_valid && core_csr_addr == 12'h32E;
assign rvfi_csr_mhpmevent14_rmask = {32{hit_mhpmevent14}};
assign rvfi_csr_mhpmevent14_wmask = {32{hit_mhpmevent14}};
assign rvfi_csr_mhpmevent14_rdata = hit_mhpmevent14 ? core_csr_rdata : 32'b0;
assign rvfi_csr_mhpmevent14_wdata = hit_mhpmevent14 ? core_csr_wdata : 32'b0;
wire hit_mhpmevent15 = core_csr_valid && core_csr_addr == 12'h32F;
assign rvfi_csr_mhpmevent15_rmask = {32{hit_mhpmevent15}};
assign rvfi_csr_mhpmevent15_wmask = {32{hit_mhpmevent15}};
assign rvfi_csr_mhpmevent15_rdata = hit_mhpmevent15 ? core_csr_rdata : 32'b0;
assign rvfi_csr_mhpmevent15_wdata = hit_mhpmevent15 ? core_csr_wdata : 32'b0;
wire hit_mhpmevent16 = core_csr_valid && core_csr_addr == 12'h330;
assign rvfi_csr_mhpmevent16_rmask = {32{hit_mhpmevent16}};
assign rvfi_csr_mhpmevent16_wmask = {32{hit_mhpmevent16}};
assign rvfi_csr_mhpmevent16_rdata = hit_mhpmevent16 ? core_csr_rdata : 32'b0;
assign rvfi_csr_mhpmevent16_wdata = hit_mhpmevent16 ? core_csr_wdata : 32'b0;
wire hit_mhpmevent17 = core_csr_valid && core_csr_addr == 12'h331;
assign rvfi_csr_mhpmevent17_rmask = {32{hit_mhpmevent17}};
assign rvfi_csr_mhpmevent17_wmask = {32{hit_mhpmevent17}};
assign rvfi_csr_mhpmevent17_rdata = hit_mhpmevent17 ? core_csr_rdata : 32'b0;
assign rvfi_csr_mhpmevent17_wdata = hit_mhpmevent17 ? core_csr_wdata : 32'b0;
wire hit_mhpmevent18 = core_csr_valid && core_csr_addr == 12'h332;
assign rvfi_csr_mhpmevent18_rmask = {32{hit_mhpmevent18}};
assign rvfi_csr_mhpmevent18_wmask = {32{hit_mhpmevent18}};
assign rvfi_csr_mhpmevent18_rdata = hit_mhpmevent18 ? core_csr_rdata : 32'b0;
assign rvfi_csr_mhpmevent18_wdata = hit_mhpmevent18 ? core_csr_wdata : 32'b0;
wire hit_mhpmevent19 = core_csr_valid && core_csr_addr == 12'h333;
assign rvfi_csr_mhpmevent19_rmask = {32{hit_mhpmevent19}};
assign rvfi_csr_mhpmevent19_wmask = {32{hit_mhpmevent19}};
assign rvfi_csr_mhpmevent19_rdata = hit_mhpmevent19 ? core_csr_rdata : 32'b0;
assign rvfi_csr_mhpmevent19_wdata = hit_mhpmevent19 ? core_csr_wdata : 32'b0;
wire hit_mhpmevent20 = core_csr_valid && core_csr_addr == 12'h334;
assign rvfi_csr_mhpmevent20_rmask = {32{hit_mhpmevent20}};
assign rvfi_csr_mhpmevent20_wmask = {32{hit_mhpmevent20}};
assign rvfi_csr_mhpmevent20_rdata = hit_mhpmevent20 ? core_csr_rdata : 32'b0;
assign rvfi_csr_mhpmevent20_wdata = hit_mhpmevent20 ? core_csr_wdata : 32'b0;
wire hit_mhpmevent21 = core_csr_valid && core_csr_addr == 12'h335;
assign rvfi_csr_mhpmevent21_rmask = {32{hit_mhpmevent21}};
assign rvfi_csr_mhpmevent21_wmask = {32{hit_mhpmevent21}};
assign rvfi_csr_mhpmevent21_rdata = hit_mhpmevent21 ? core_csr_rdata : 32'b0;
assign rvfi_csr_mhpmevent21_wdata = hit_mhpmevent21 ? core_csr_wdata : 32'b0;
wire hit_mhpmevent22 = core_csr_valid && core_csr_addr == 12'h336;
assign rvfi_csr_mhpmevent22_rmask = {32{hit_mhpmevent22}};
assign rvfi_csr_mhpmevent22_wmask = {32{hit_mhpmevent22}};
assign rvfi_csr_mhpmevent22_rdata = hit_mhpmevent22 ? core_csr_rdata : 32'b0;
assign rvfi_csr_mhpmevent22_wdata = hit_mhpmevent22 ? core_csr_wdata : 32'b0;
wire hit_mhpmevent23 = core_csr_valid && core_csr_addr == 12'h337;
assign rvfi_csr_mhpmevent23_rmask = {32{hit_mhpmevent23}};
assign rvfi_csr_mhpmevent23_wmask = {32{hit_mhpmevent23}};
assign rvfi_csr_mhpmevent23_rdata = hit_mhpmevent23 ? core_csr_rdata : 32'b0;
assign rvfi_csr_mhpmevent23_wdata = hit_mhpmevent23 ? core_csr_wdata : 32'b0;
wire hit_mhpmevent24 = core_csr_valid && core_csr_addr == 12'h338;
assign rvfi_csr_mhpmevent24_rmask = {32{hit_mhpmevent24}};
assign rvfi_csr_mhpmevent24_wmask = {32{hit_mhpmevent24}};
assign rvfi_csr_mhpmevent24_rdata = hit_mhpmevent24 ? core_csr_rdata : 32'b0;
assign rvfi_csr_mhpmevent24_wdata = hit_mhpmevent24 ? core_csr_wdata : 32'b0;
wire hit_mhpmevent25 = core_csr_valid && core_csr_addr == 12'h339;
assign rvfi_csr_mhpmevent25_rmask = {32{hit_mhpmevent25}};
assign rvfi_csr_mhpmevent25_wmask = {32{hit_mhpmevent25}};
assign rvfi_csr_mhpmevent25_rdata = hit_mhpmevent25 ? core_csr_rdata : 32'b0;
assign rvfi_csr_mhpmevent25_wdata = hit_mhpmevent25 ? core_csr_wdata : 32'b0;
wire hit_mhpmevent26 = core_csr_valid && core_csr_addr == 12'h33A;
assign rvfi_csr_mhpmevent26_rmask = {32{hit_mhpmevent26}};
assign rvfi_csr_mhpmevent26_wmask = {32{hit_mhpmevent26}};
assign rvfi_csr_mhpmevent26_rdata = hit_mhpmevent26 ? core_csr_rdata : 32'b0;
assign rvfi_csr_mhpmevent26_wdata = hit_mhpmevent26 ? core_csr_wdata : 32'b0;
wire hit_mhpmevent27 = core_csr_valid && core_csr_addr == 12'h33B;
assign rvfi_csr_mhpmevent27_rmask = {32{hit_mhpmevent27}};
assign rvfi_csr_mhpmevent27_wmask = {32{hit_mhpmevent27}};
assign rvfi_csr_mhpmevent27_rdata = hit_mhpmevent27 ? core_csr_rdata : 32'b0;
assign rvfi_csr_mhpmevent27_wdata = hit_mhpmevent27 ? core_csr_wdata : 32'b0;
wire hit_mhpmevent28 = core_csr_valid && core_csr_addr == 12'h33C;
assign rvfi_csr_mhpmevent28_rmask = {32{hit_mhpmevent28}};
assign rvfi_csr_mhpmevent28_wmask = {32{hit_mhpmevent28}};
assign rvfi_csr_mhpmevent28_rdata = hit_mhpmevent28 ? core_csr_rdata : 32'b0;
assign rvfi_csr_mhpmevent28_wdata = hit_mhpmevent28 ? core_csr_wdata : 32'b0;
wire hit_mhpmevent29 = core_csr_valid && core_csr_addr == 12'h33D;
assign rvfi_csr_mhpmevent29_rmask = {32{hit_mhpmevent29}};
assign rvfi_csr_mhpmevent29_wmask = {32{hit_mhpmevent29}};
assign rvfi_csr_mhpmevent29_rdata = hit_mhpmevent29 ? core_csr_rdata : 32'b0;
assign rvfi_csr_mhpmevent29_wdata = hit_mhpmevent29 ? core_csr_wdata : 32'b0;
wire hit_mhpmevent30 = core_csr_valid && core_csr_addr == 12'h33E;
assign rvfi_csr_mhpmevent30_rmask = {32{hit_mhpmevent30}};
assign rvfi_csr_mhpmevent30_wmask = {32{hit_mhpmevent30}};
assign rvfi_csr_mhpmevent30_rdata = hit_mhpmevent30 ? core_csr_rdata : 32'b0;
assign rvfi_csr_mhpmevent30_wdata = hit_mhpmevent30 ? core_csr_wdata : 32'b0;
wire hit_mhpmevent31 = core_csr_valid && core_csr_addr == 12'h33F;
assign rvfi_csr_mhpmevent31_rmask = {32{hit_mhpmevent31}};
assign rvfi_csr_mhpmevent31_wmask = {32{hit_mhpmevent31}};
assign rvfi_csr_mhpmevent31_rdata = hit_mhpmevent31 ? core_csr_rdata : 32'b0;
assign rvfi_csr_mhpmevent31_wdata = hit_mhpmevent31 ? core_csr_wdata : 32'b0;
wire hit_mcycle_lo = core_csr_valid && (core_csr_addr == 12'hB00 || core_csr_addr == 12'hC00);
wire hit_mcycle_hi = core_csr_valid && (core_csr_addr == 12'hB80 || core_csr_addr == 12'hC80);
wire [63:0] old_mcycle = core_csr_mcycle;
assign rvfi_csr_mcycle_rmask = {64{hit_mcycle_lo || hit_mcycle_hi}};
assign rvfi_csr_mcycle_wmask = {64{hit_mcycle_lo || hit_mcycle_hi}};
assign rvfi_csr_mcycle_rdata = hit_mcycle_lo || hit_mcycle_hi ? old_mcycle : 64'b0;
assign rvfi_csr_mcycle_wdata = hit_mcycle_lo ? {old_mcycle[63:32], core_csr_wdata} : hit_mcycle_hi ? {core_csr_wdata, old_mcycle[31:0]} : 64'b0;
wire hit_minstret_lo = core_csr_valid && (core_csr_addr == 12'hB02 || core_csr_addr == 12'hC02);
wire hit_minstret_hi = core_csr_valid && (core_csr_addr == 12'hB82 || core_csr_addr == 12'hC82);
wire [63:0] old_minstret = core_csr_minstret;
assign rvfi_csr_minstret_rmask = {64{hit_minstret_lo || hit_minstret_hi}};
assign rvfi_csr_minstret_wmask = {64{hit_minstret_lo || hit_minstret_hi}};
assign rvfi_csr_minstret_rdata = hit_minstret_lo || hit_minstret_hi ? old_minstret : 64'b0;
assign rvfi_csr_minstret_wdata = hit_minstret_lo ? {old_minstret[63:32], core_csr_wdata} : hit_minstret_hi ? {core_csr_wdata, old_minstret[31:0]} : 64'b0;
wire hit_mhpmcounter3_lo = core_csr_valid && (core_csr_addr == 12'hB03 || core_csr_addr == 12'hC03);
wire hit_mhpmcounter3_hi = core_csr_valid && (core_csr_addr == 12'hB83 || core_csr_addr == 12'hC83);
wire [63:0] old_mhpmcounter3 = 64'b0;
assign rvfi_csr_mhpmcounter3_rmask = {64{hit_mhpmcounter3_lo || hit_mhpmcounter3_hi}};
assign rvfi_csr_mhpmcounter3_wmask = {64{hit_mhpmcounter3_lo || hit_mhpmcounter3_hi}};
assign rvfi_csr_mhpmcounter3_rdata = hit_mhpmcounter3_lo || hit_mhpmcounter3_hi ? old_mhpmcounter3 : 64'b0;
assign rvfi_csr_mhpmcounter3_wdata = hit_mhpmcounter3_lo ? {old_mhpmcounter3[63:32], core_csr_wdata} : hit_mhpmcounter3_hi ? {core_csr_wdata, old_mhpmcounter3[31:0]} : 64'b0;
wire hit_mhpmcounter4_lo = core_csr_valid && (core_csr_addr == 12'hB04 || core_csr_addr == 12'hC04);
wire hit_mhpmcounter4_hi = core_csr_valid && (core_csr_addr == 12'hB84 || core_csr_addr == 12'hC84);
wire [63:0] old_mhpmcounter4 = 64'b0;
assign rvfi_csr_mhpmcounter4_rmask = {64{hit_mhpmcounter4_lo || hit_mhpmcounter4_hi}};
assign rvfi_csr_mhpmcounter4_wmask = {64{hit_mhpmcounter4_lo || hit_mhpmcounter4_hi}};
assign rvfi_csr_mhpmcounter4_rdata = hit_mhpmcounter4_lo || hit_mhpmcounter4_hi ? old_mhpmcounter4 : 64'b0;
assign rvfi_csr_mhpmcounter4_wdata = hit_mhpmcounter4_lo ? {old_mhpmcounter4[63:32], core_csr_wdata} : hit_mhpmcounter4_hi ? {core_csr_wdata, old_mhpmcounter4[31:0]} : 64'b0;
wire hit_mhpmcounter5_lo = core_csr_valid && (core_csr_addr == 12'hB05 || core_csr_addr == 12'hC05);
wire hit_mhpmcounter5_hi = core_csr_valid && (core_csr_addr == 12'hB85 || core_csr_addr == 12'hC85);
wire [63:0] old_mhpmcounter5 = 64'b0;
assign rvfi_csr_mhpmcounter5_rmask = {64{hit_mhpmcounter5_lo || hit_mhpmcounter5_hi}};
assign rvfi_csr_mhpmcounter5_wmask = {64{hit_mhpmcounter5_lo || hit_mhpmcounter5_hi}};
assign rvfi_csr_mhpmcounter5_rdata = hit_mhpmcounter5_lo || hit_mhpmcounter5_hi ? old_mhpmcounter5 : 64'b0;
assign rvfi_csr_mhpmcounter5_wdata = hit_mhpmcounter5_lo ? {old_mhpmcounter5[63:32], core_csr_wdata} : hit_mhpmcounter5_hi ? {core_csr_wdata, old_mhpmcounter5[31:0]} : 64'b0;
wire hit_mhpmcounter6_lo = core_csr_valid && (core_csr_addr == 12'hB06 || core_csr_addr == 12'hC06);
wire hit_mhpmcounter6_hi = core_csr_valid && (core_csr_addr == 12'hB86 || core_csr_addr == 12'hC86);
wire [63:0] old_mhpmcounter6 = 64'b0;
assign rvfi_csr_mhpmcounter6_rmask = {64{hit_mhpmcounter6_lo || hit_mhpmcounter6_hi}};
assign rvfi_csr_mhpmcounter6_wmask = {64{hit_mhpmcounter6_lo || hit_mhpmcounter6_hi}};
assign rvfi_csr_mhpmcounter6_rdata = hit_mhpmcounter6_lo || hit_mhpmcounter6_hi ? old_mhpmcounter6 : 64'b0;
assign rvfi_csr_mhpmcounter6_wdata = hit_mhpmcounter6_lo ? {old_mhpmcounter6[63:32], core_csr_wdata} : hit_mhpmcounter6_hi ? {core_csr_wdata, old_mhpmcounter6[31:0]} : 64'b0;
wire hit_mhpmcounter7_lo = core_csr_valid && (core_csr_addr == 12'hB07 || core_csr_addr == 12'hC07);
wire hit_mhpmcounter7_hi = core_csr_valid && (core_csr_addr == 12'hB87 || core_csr_addr == 12'hC87);
wire [63:0] old_mhpmcounter7 = 64'b0;
assign rvfi_csr_mhpmcounter7_rmask = {64{hit_mhpmcounter7_lo || hit_mhpmcounter7_hi}};
assign rvfi_csr_mhpmcounter7_wmask = {64{hit_mhpmcounter7_lo || hit_mhpmcounter7_hi}};
assign rvfi_csr_mhpmcounter7_rdata = hit_mhpmcounter7_lo || hit_mhpmcounter7_hi ? old_mhpmcounter7 : 64'b0;
assign rvfi_csr_mhpmcounter7_wdata = hit_mhpmcounter7_lo ? {old_mhpmcounter7[63:32], core_csr_wdata} : hit_mhpmcounter7_hi ? {core_csr_wdata, old_mhpmcounter7[31:0]} : 64'b0;
wire hit_mhpmcounter8_lo = core_csr_valid && (core_csr_addr == 12'hB08 || core_csr_addr == 12'hC08);
wire hit_mhpmcounter8_hi = core_csr_valid && (core_csr_addr == 12'hB88 || core_csr_addr == 12'hC88);
wire [63:0] old_mhpmcounter8 = 64'b0;
assign rvfi_csr_mhpmcounter8_rmask = {64{hit_mhpmcounter8_lo || hit_mhpmcounter8_hi}};
assign rvfi_csr_mhpmcounter8_wmask = {64{hit_mhpmcounter8_lo || hit_mhpmcounter8_hi}};
assign rvfi_csr_mhpmcounter8_rdata = hit_mhpmcounter8_lo || hit_mhpmcounter8_hi ? old_mhpmcounter8 : 64'b0;
assign rvfi_csr_mhpmcounter8_wdata = hit_mhpmcounter8_lo ? {old_mhpmcounter8[63:32], core_csr_wdata} : hit_mhpmcounter8_hi ? {core_csr_wdata, old_mhpmcounter8[31:0]} : 64'b0;
wire hit_mhpmcounter9_lo = core_csr_valid && (core_csr_addr == 12'hB09 || core_csr_addr == 12'hC09);
wire hit_mhpmcounter9_hi = core_csr_valid && (core_csr_addr == 12'hB89 || core_csr_addr == 12'hC89);
wire [63:0] old_mhpmcounter9 = 64'b0;
assign rvfi_csr_mhpmcounter9_rmask = {64{hit_mhpmcounter9_lo || hit_mhpmcounter9_hi}};
assign rvfi_csr_mhpmcounter9_wmask = {64{hit_mhpmcounter9_lo || hit_mhpmcounter9_hi}};
assign rvfi_csr_mhpmcounter9_rdata = hit_mhpmcounter9_lo || hit_mhpmcounter9_hi ? old_mhpmcounter9 : 64'b0;
assign rvfi_csr_mhpmcounter9_wdata = hit_mhpmcounter9_lo ? {old_mhpmcounter9[63:32], core_csr_wdata} : hit_mhpmcounter9_hi ? {core_csr_wdata, old_mhpmcounter9[31:0]} : 64'b0;
wire hit_mhpmcounter10_lo = core_csr_valid && (core_csr_addr == 12'hB0A || core_csr_addr == 12'hC0A);
wire hit_mhpmcounter10_hi = core_csr_valid && (core_csr_addr == 12'hB8A || core_csr_addr == 12'hC8A);
wire [63:0] old_mhpmcounter10 = 64'b0;
assign rvfi_csr_mhpmcounter10_rmask = {64{hit_mhpmcounter10_lo || hit_mhpmcounter10_hi}};
assign rvfi_csr_mhpmcounter10_wmask = {64{hit_mhpmcounter10_lo || hit_mhpmcounter10_hi}};
assign rvfi_csr_mhpmcounter10_rdata = hit_mhpmcounter10_lo || hit_mhpmcounter10_hi ? old_mhpmcounter10 : 64'b0;
assign rvfi_csr_mhpmcounter10_wdata = hit_mhpmcounter10_lo ? {old_mhpmcounter10[63:32], core_csr_wdata} : hit_mhpmcounter10_hi ? {core_csr_wdata, old_mhpmcounter10[31:0]} : 64'b0;
wire hit_mhpmcounter11_lo = core_csr_valid && (core_csr_addr == 12'hB0B || core_csr_addr == 12'hC0B);
wire hit_mhpmcounter11_hi = core_csr_valid && (core_csr_addr == 12'hB8B || core_csr_addr == 12'hC8B);
wire [63:0] old_mhpmcounter11 = 64'b0;
assign rvfi_csr_mhpmcounter11_rmask = {64{hit_mhpmcounter11_lo || hit_mhpmcounter11_hi}};
assign rvfi_csr_mhpmcounter11_wmask = {64{hit_mhpmcounter11_lo || hit_mhpmcounter11_hi}};
assign rvfi_csr_mhpmcounter11_rdata = hit_mhpmcounter11_lo || hit_mhpmcounter11_hi ? old_mhpmcounter11 : 64'b0;
assign rvfi_csr_mhpmcounter11_wdata = hit_mhpmcounter11_lo ? {old_mhpmcounter11[63:32], core_csr_wdata} : hit_mhpmcounter11_hi ? {core_csr_wdata, old_mhpmcounter11[31:0]} : 64'b0;
wire hit_mhpmcounter12_lo = core_csr_valid && (core_csr_addr == 12'hB0C || core_csr_addr == 12'hC0C);
wire hit_mhpmcounter12_hi = core_csr_valid && (core_csr_addr == 12'hB8C || core_csr_addr == 12'hC8C);
wire [63:0] old_mhpmcounter12 = 64'b0;
assign rvfi_csr_mhpmcounter12_rmask = {64{hit_mhpmcounter12_lo || hit_mhpmcounter12_hi}};
assign rvfi_csr_mhpmcounter12_wmask = {64{hit_mhpmcounter12_lo || hit_mhpmcounter12_hi}};
assign rvfi_csr_mhpmcounter12_rdata = hit_mhpmcounter12_lo || hit_mhpmcounter12_hi ? old_mhpmcounter12 : 64'b0;
assign rvfi_csr_mhpmcounter12_wdata = hit_mhpmcounter12_lo ? {old_mhpmcounter12[63:32], core_csr_wdata} : hit_mhpmcounter12_hi ? {core_csr_wdata, old_mhpmcounter12[31:0]} : 64'b0;
wire hit_mhpmcounter13_lo = core_csr_valid && (core_csr_addr == 12'hB0D || core_csr_addr == 12'hC0D);
wire hit_mhpmcounter13_hi = core_csr_valid && (core_csr_addr == 12'hB8D || core_csr_addr == 12'hC8D);
wire [63:0] old_mhpmcounter13 = 64'b0;
assign rvfi_csr_mhpmcounter13_rmask = {64{hit_mhpmcounter13_lo || hit_mhpmcounter13_hi}};
assign rvfi_csr_mhpmcounter13_wmask = {64{hit_mhpmcounter13_lo || hit_mhpmcounter13_hi}};
assign rvfi_csr_mhpmcounter13_rdata = hit_mhpmcounter13_lo || hit_mhpmcounter13_hi ? old_mhpmcounter13 : 64'b0;
assign rvfi_csr_mhpmcounter13_wdata = hit_mhpmcounter13_lo ? {old_mhpmcounter13[63:32], core_csr_wdata} : hit_mhpmcounter13_hi ? {core_csr_wdata, old_mhpmcounter13[31:0]} : 64'b0;
wire hit_mhpmcounter14_lo = core_csr_valid && (core_csr_addr == 12'hB0E || core_csr_addr == 12'hC0E);
wire hit_mhpmcounter14_hi = core_csr_valid && (core_csr_addr == 12'hB8E || core_csr_addr == 12'hC8E);
wire [63:0] old_mhpmcounter14 = 64'b0;
assign rvfi_csr_mhpmcounter14_rmask = {64{hit_mhpmcounter14_lo || hit_mhpmcounter14_hi}};
assign rvfi_csr_mhpmcounter14_wmask = {64{hit_mhpmcounter14_lo || hit_mhpmcounter14_hi}};
assign rvfi_csr_mhpmcounter14_rdata = hit_mhpmcounter14_lo || hit_mhpmcounter14_hi ? old_mhpmcounter14 : 64'b0;
assign rvfi_csr_mhpmcounter14_wdata = hit_mhpmcounter14_lo ? {old_mhpmcounter14[63:32], core_csr_wdata} : hit_mhpmcounter14_hi ? {core_csr_wdata, old_mhpmcounter14[31:0]} : 64'b0;
wire hit_mhpmcounter15_lo = core_csr_valid && (core_csr_addr == 12'hB0F || core_csr_addr == 12'hC0F);
wire hit_mhpmcounter15_hi = core_csr_valid && (core_csr_addr == 12'hB8F || core_csr_addr == 12'hC8F);
wire [63:0] old_mhpmcounter15 = 64'b0;
assign rvfi_csr_mhpmcounter15_rmask = {64{hit_mhpmcounter15_lo || hit_mhpmcounter15_hi}};
assign rvfi_csr_mhpmcounter15_wmask = {64{hit_mhpmcounter15_lo || hit_mhpmcounter15_hi}};
assign rvfi_csr_mhpmcounter15_rdata = hit_mhpmcounter15_lo || hit_mhpmcounter15_hi ? old_mhpmcounter15 : 64'b0;
assign rvfi_csr_mhpmcounter15_wdata = hit_mhpmcounter15_lo ? {old_mhpmcounter15[63:32], core_csr_wdata} : hit_mhpmcounter15_hi ? {core_csr_wdata, old_mhpmcounter15[31:0]} : 64'b0;
wire hit_mhpmcounter16_lo = core_csr_valid && (core_csr_addr == 12'hB10 || core_csr_addr == 12'hC10);
wire hit_mhpmcounter16_hi = core_csr_valid && (core_csr_addr == 12'hB90 || core_csr_addr == 12'hC90);
wire [63:0] old_mhpmcounter16 = 64'b0;
assign rvfi_csr_mhpmcounter16_rmask = {64{hit_mhpmcounter16_lo || hit_mhpmcounter16_hi}};
assign rvfi_csr_mhpmcounter16_wmask = {64{hit_mhpmcounter16_lo || hit_mhpmcounter16_hi}};
assign rvfi_csr_mhpmcounter16_rdata = hit_mhpmcounter16_lo || hit_mhpmcounter16_hi ? old_mhpmcounter16 : 64'b0;
assign rvfi_csr_mhpmcounter16_wdata = hit_mhpmcounter16_lo ? {old_mhpmcounter16[63:32], core_csr_wdata} : hit_mhpmcounter16_hi ? {core_csr_wdata, old_mhpmcounter16[31:0]} : 64'b0;
wire hit_mhpmcounter17_lo = core_csr_valid && (core_csr_addr == 12'hB11 || core_csr_addr == 12'hC11);
wire hit_mhpmcounter17_hi = core_csr_valid && (core_csr_addr == 12'hB91 || core_csr_addr == 12'hC91);
wire [63:0] old_mhpmcounter17 = 64'b0;
assign rvfi_csr_mhpmcounter17_rmask = {64{hit_mhpmcounter17_lo || hit_mhpmcounter17_hi}};
assign rvfi_csr_mhpmcounter17_wmask = {64{hit_mhpmcounter17_lo || hit_mhpmcounter17_hi}};
assign rvfi_csr_mhpmcounter17_rdata = hit_mhpmcounter17_lo || hit_mhpmcounter17_hi ? old_mhpmcounter17 : 64'b0;
assign rvfi_csr_mhpmcounter17_wdata = hit_mhpmcounter17_lo ? {old_mhpmcounter17[63:32], core_csr_wdata} : hit_mhpmcounter17_hi ? {core_csr_wdata, old_mhpmcounter17[31:0]} : 64'b0;
wire hit_mhpmcounter18_lo = core_csr_valid && (core_csr_addr == 12'hB12 || core_csr_addr == 12'hC12);
wire hit_mhpmcounter18_hi = core_csr_valid && (core_csr_addr == 12'hB92 || core_csr_addr == 12'hC92);
wire [63:0] old_mhpmcounter18 = 64'b0;
assign rvfi_csr_mhpmcounter18_rmask = {64{hit_mhpmcounter18_lo || hit_mhpmcounter18_hi}};
assign rvfi_csr_mhpmcounter18_wmask = {64{hit_mhpmcounter18_lo || hit_mhpmcounter18_hi}};
assign rvfi_csr_mhpmcounter18_rdata = hit_mhpmcounter18_lo || hit_mhpmcounter18_hi ? old_mhpmcounter18 : 64'b0;
assign rvfi_csr_mhpmcounter18_wdata = hit_mhpmcounter18_lo ? {old_mhpmcounter18[63:32], core_csr_wdata} : hit_mhpmcounter18_hi ? {core_csr_wdata, old_mhpmcounter18[31:0]} : 64'b0;
wire hit_mhpmcounter19_lo = core_csr_valid && (core_csr_addr == 12'hB13 || core_csr_addr == 12'hC13);
wire hit_mhpmcounter19_hi = core_csr_valid && (core_csr_addr == 12'hB93 || core_csr_addr == 12'hC93);
wire [63:0] old_mhpmcounter19 = 64'b0;
assign rvfi_csr_mhpmcounter19_rmask = {64{hit_mhpmcounter19_lo || hit_mhpmcounter19_hi}};
assign rvfi_csr_mhpmcounter19_wmask = {64{hit_mhpmcounter19_lo || hit_mhpmcounter19_hi}};
assign rvfi_csr_mhpmcounter19_rdata = hit_mhpmcounter19_lo || hit_mhpmcounter19_hi ? old_mhpmcounter19 : 64'b0;
assign rvfi_csr_mhpmcounter19_wdata = hit_mhpmcounter19_lo ? {old_mhpmcounter19[63:32], core_csr_wdata} : hit_mhpmcounter19_hi ? {core_csr_wdata, old_mhpmcounter19[31:0]} : 64'b0;
wire hit_mhpmcounter20_lo = core_csr_valid && (core_csr_addr == 12'hB14 || core_csr_addr == 12'hC14);
wire hit_mhpmcounter20_hi = core_csr_valid && (core_csr_addr == 12'hB94 || core_csr_addr == 12'hC94);
wire [63:0] old_mhpmcounter20 = 64'b0;
assign rvfi_csr_mhpmcounter20_rmask = {64{hit_mhpmcounter20_lo || hit_mhpmcounter20_hi}};
assign rvfi_csr_mhpmcounter20_wmask = {64{hit_mhpmcounter20_lo || hit_mhpmcounter20_hi}};
assign rvfi_csr_mhpmcounter20_rdata = hit_mhpmcounter20_lo || hit_mhpmcounter20_hi ? old_mhpmcounter20 : 64'b0;
assign rvfi_csr_mhpmcounter20_wdata = hit_mhpmcounter20_lo ? {old_mhpmcounter20[63:32], core_csr_wdata} : hit_mhpmcounter20_hi ? {core_csr_wdata, old_mhpmcounter20[31:0]} : 64'b0;
wire hit_mhpmcounter21_lo = core_csr_valid && (core_csr_addr == 12'hB15 || core_csr_addr == 12'hC15);
wire hit_mhpmcounter21_hi = core_csr_valid && (core_csr_addr == 12'hB95 || core_csr_addr == 12'hC95);
wire [63:0] old_mhpmcounter21 = 64'b0;
assign rvfi_csr_mhpmcounter21_rmask = {64{hit_mhpmcounter21_lo || hit_mhpmcounter21_hi}};
assign rvfi_csr_mhpmcounter21_wmask = {64{hit_mhpmcounter21_lo || hit_mhpmcounter21_hi}};
assign rvfi_csr_mhpmcounter21_rdata = hit_mhpmcounter21_lo || hit_mhpmcounter21_hi ? old_mhpmcounter21 : 64'b0;
assign rvfi_csr_mhpmcounter21_wdata = hit_mhpmcounter21_lo ? {old_mhpmcounter21[63:32], core_csr_wdata} : hit_mhpmcounter21_hi ? {core_csr_wdata, old_mhpmcounter21[31:0]} : 64'b0;
wire hit_mhpmcounter22_lo = core_csr_valid && (core_csr_addr == 12'hB16 || core_csr_addr == 12'hC16);
wire hit_mhpmcounter22_hi = core_csr_valid && (core_csr_addr == 12'hB96 || core_csr_addr == 12'hC96);
wire [63:0] old_mhpmcounter22 = 64'b0;
assign rvfi_csr_mhpmcounter22_rmask = {64{hit_mhpmcounter22_lo || hit_mhpmcounter22_hi}};
assign rvfi_csr_mhpmcounter22_wmask = {64{hit_mhpmcounter22_lo || hit_mhpmcounter22_hi}};
assign rvfi_csr_mhpmcounter22_rdata = hit_mhpmcounter22_lo || hit_mhpmcounter22_hi ? old_mhpmcounter22 : 64'b0;
assign rvfi_csr_mhpmcounter22_wdata = hit_mhpmcounter22_lo ? {old_mhpmcounter22[63:32], core_csr_wdata} : hit_mhpmcounter22_hi ? {core_csr_wdata, old_mhpmcounter22[31:0]} : 64'b0;
wire hit_mhpmcounter23_lo = core_csr_valid && (core_csr_addr == 12'hB17 || core_csr_addr == 12'hC17);
wire hit_mhpmcounter23_hi = core_csr_valid && (core_csr_addr == 12'hB97 || core_csr_addr == 12'hC97);
wire [63:0] old_mhpmcounter23 = 64'b0;
assign rvfi_csr_mhpmcounter23_rmask = {64{hit_mhpmcounter23_lo || hit_mhpmcounter23_hi}};
assign rvfi_csr_mhpmcounter23_wmask = {64{hit_mhpmcounter23_lo || hit_mhpmcounter23_hi}};
assign rvfi_csr_mhpmcounter23_rdata = hit_mhpmcounter23_lo || hit_mhpmcounter23_hi ? old_mhpmcounter23 : 64'b0;
assign rvfi_csr_mhpmcounter23_wdata = hit_mhpmcounter23_lo ? {old_mhpmcounter23[63:32], core_csr_wdata} : hit_mhpmcounter23_hi ? {core_csr_wdata, old_mhpmcounter23[31:0]} : 64'b0;
wire hit_mhpmcounter24_lo = core_csr_valid && (core_csr_addr == 12'hB18 || core_csr_addr == 12'hC18);
wire hit_mhpmcounter24_hi = core_csr_valid && (core_csr_addr == 12'hB98 || core_csr_addr == 12'hC98);
wire [63:0] old_mhpmcounter24 = 64'b0;
assign rvfi_csr_mhpmcounter24_rmask = {64{hit_mhpmcounter24_lo || hit_mhpmcounter24_hi}};
assign rvfi_csr_mhpmcounter24_wmask = {64{hit_mhpmcounter24_lo || hit_mhpmcounter24_hi}};
assign rvfi_csr_mhpmcounter24_rdata = hit_mhpmcounter24_lo || hit_mhpmcounter24_hi ? old_mhpmcounter24 : 64'b0;
assign rvfi_csr_mhpmcounter24_wdata = hit_mhpmcounter24_lo ? {old_mhpmcounter24[63:32], core_csr_wdata} : hit_mhpmcounter24_hi ? {core_csr_wdata, old_mhpmcounter24[31:0]} : 64'b0;
wire hit_mhpmcounter25_lo = core_csr_valid && (core_csr_addr == 12'hB19 || core_csr_addr == 12'hC19);
wire hit_mhpmcounter25_hi = core_csr_valid && (core_csr_addr == 12'hB99 || core_csr_addr == 12'hC99);
wire [63:0] old_mhpmcounter25 = 64'b0;
assign rvfi_csr_mhpmcounter25_rmask = {64{hit_mhpmcounter25_lo || hit_mhpmcounter25_hi}};
assign rvfi_csr_mhpmcounter25_wmask = {64{hit_mhpmcounter25_lo || hit_mhpmcounter25_hi}};
assign rvfi_csr_mhpmcounter25_rdata = hit_mhpmcounter25_lo || hit_mhpmcounter25_hi ? old_mhpmcounter25 : 64'b0;
assign rvfi_csr_mhpmcounter25_wdata = hit_mhpmcounter25_lo ? {old_mhpmcounter25[63:32], core_csr_wdata} : hit_mhpmcounter25_hi ? {core_csr_wdata, old_mhpmcounter25[31:0]} : 64'b0;
wire hit_mhpmcounter26_lo = core_csr_valid && (core_csr_addr == 12'hB1A || core_csr_addr == 12'hC1A);
wire hit_mhpmcounter26_hi = core_csr_valid && (core_csr_addr == 12'hB9A || core_csr_addr == 12'hC9A);
wire [63:0] old_mhpmcounter26 = 64'b0;
assign rvfi_csr_mhpmcounter26_rmask = {64{hit_mhpmcounter26_lo || hit_mhpmcounter26_hi}};
assign rvfi_csr_mhpmcounter26_wmask = {64{hit_mhpmcounter26_lo || hit_mhpmcounter26_hi}};
assign rvfi_csr_mhpmcounter26_rdata = hit_mhpmcounter26_lo || hit_mhpmcounter26_hi ? old_mhpmcounter26 : 64'b0;
assign rvfi_csr_mhpmcounter26_wdata = hit_mhpmcounter26_lo ? {old_mhpmcounter26[63:32], core_csr_wdata} : hit_mhpmcounter26_hi ? {core_csr_wdata, old_mhpmcounter26[31:0]} : 64'b0;
wire hit_mhpmcounter27_lo = core_csr_valid && (core_csr_addr == 12'hB1B || core_csr_addr == 12'hC1B);
wire hit_mhpmcounter27_hi = core_csr_valid && (core_csr_addr == 12'hB9B || core_csr_addr == 12'hC9B);
wire [63:0] old_mhpmcounter27 = 64'b0;
assign rvfi_csr_mhpmcounter27_rmask = {64{hit_mhpmcounter27_lo || hit_mhpmcounter27_hi}};
assign rvfi_csr_mhpmcounter27_wmask = {64{hit_mhpmcounter27_lo || hit_mhpmcounter27_hi}};
assign rvfi_csr_mhpmcounter27_rdata = hit_mhpmcounter27_lo || hit_mhpmcounter27_hi ? old_mhpmcounter27 : 64'b0;
assign rvfi_csr_mhpmcounter27_wdata = hit_mhpmcounter27_lo ? {old_mhpmcounter27[63:32], core_csr_wdata} : hit_mhpmcounter27_hi ? {core_csr_wdata, old_mhpmcounter27[31:0]} : 64'b0;
wire hit_mhpmcounter28_lo = core_csr_valid && (core_csr_addr == 12'hB1C || core_csr_addr == 12'hC1C);
wire hit_mhpmcounter28_hi = core_csr_valid && (core_csr_addr == 12'hB9C || core_csr_addr == 12'hC9C);
wire [63:0] old_mhpmcounter28 = 64'b0;
assign rvfi_csr_mhpmcounter28_rmask = {64{hit_mhpmcounter28_lo || hit_mhpmcounter28_hi}};
assign rvfi_csr_mhpmcounter28_wmask = {64{hit_mhpmcounter28_lo || hit_mhpmcounter28_hi}};
assign rvfi_csr_mhpmcounter28_rdata = hit_mhpmcounter28_lo || hit_mhpmcounter28_hi ? old_mhpmcounter28 : 64'b0;
assign rvfi_csr_mhpmcounter28_wdata = hit_mhpmcounter28_lo ? {old_mhpmcounter28[63:32], core_csr_wdata} : hit_mhpmcounter28_hi ? {core_csr_wdata, old_mhpmcounter28[31:0]} : 64'b0;
wire hit_mhpmcounter29_lo = core_csr_valid && (core_csr_addr == 12'hB1D || core_csr_addr == 12'hC1D);
wire hit_mhpmcounter29_hi = core_csr_valid && (core_csr_addr == 12'hB9D || core_csr_addr == 12'hC9D);
wire [63:0] old_mhpmcounter29 = 64'b0;
assign rvfi_csr_mhpmcounter29_rmask = {64{hit_mhpmcounter29_lo || hit_mhpmcounter29_hi}};
assign rvfi_csr_mhpmcounter29_wmask = {64{hit_mhpmcounter29_lo || hit_mhpmcounter29_hi}};
assign rvfi_csr_mhpmcounter29_rdata = hit_mhpmcounter29_lo || hit_mhpmcounter29_hi ? old_mhpmcounter29 : 64'b0;
assign rvfi_csr_mhpmcounter29_wdata = hit_mhpmcounter29_lo ? {old_mhpmcounter29[63:32], core_csr_wdata} : hit_mhpmcounter29_hi ? {core_csr_wdata, old_mhpmcounter29[31:0]} : 64'b0;
wire hit_mhpmcounter30_lo = core_csr_valid && (core_csr_addr == 12'hB1E || core_csr_addr == 12'hC1E);
wire hit_mhpmcounter30_hi = core_csr_valid && (core_csr_addr == 12'hB9E || core_csr_addr == 12'hC9E);
wire [63:0] old_mhpmcounter30 = 64'b0;
assign rvfi_csr_mhpmcounter30_rmask = {64{hit_mhpmcounter30_lo || hit_mhpmcounter30_hi}};
assign rvfi_csr_mhpmcounter30_wmask = {64{hit_mhpmcounter30_lo || hit_mhpmcounter30_hi}};
assign rvfi_csr_mhpmcounter30_rdata = hit_mhpmcounter30_lo || hit_mhpmcounter30_hi ? old_mhpmcounter30 : 64'b0;
assign rvfi_csr_mhpmcounter30_wdata = hit_mhpmcounter30_lo ? {old_mhpmcounter30[63:32], core_csr_wdata} : hit_mhpmcounter30_hi ? {core_csr_wdata, old_mhpmcounter30[31:0]} : 64'b0;
wire hit_mhpmcounter31_lo = core_csr_valid && (core_csr_addr == 12'hB1F || core_csr_addr == 12'hC1F);
wire hit_mhpmcounter31_hi = core_csr_valid && (core_csr_addr == 12'hB9F || core_csr_addr == 12'hC9F);
wire [63:0] old_mhpmcounter31 = 64'b0;
assign rvfi_csr_mhpmcounter31_rmask = {64{hit_mhpmcounter31_lo || hit_mhpmcounter31_hi}};
assign rvfi_csr_mhpmcounter31_wmask = {64{hit_mhpmcounter31_lo || hit_mhpmcounter31_hi}};
assign rvfi_csr_mhpmcounter31_rdata = hit_mhpmcounter31_lo || hit_mhpmcounter31_hi ? old_mhpmcounter31 : 64'b0;
assign rvfi_csr_mhpmcounter31_wdata = hit_mhpmcounter31_lo ? {old_mhpmcounter31[63:32], core_csr_wdata} : hit_mhpmcounter31_hi ? {core_csr_wdata, old_mhpmcounter31[31:0]} : 64'b0;

endmodule
