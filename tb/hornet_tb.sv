// Core testbench: memory with random wait states, tohost, interrupt control, RVFI trace
//
// plusargs: +hex=<file> +trace=<file> +waves=<file.fst> +tohost=<hex> +mem_stall=<pct> +seed=<n> +timeout=<cycles>
// Data-port devices outside the memory:
//   0xF000_0000  write: interrupt lines {fast[15:0], 13'b0, meip, mtip, msip}
//   0xE000_0000  bus error region (instruction and data ports)
`timescale 1ns/1ps

module hornet_tb;

localparam [31:0] BASE      = 32'h8000_0000;
localparam        MEM_WORDS = 1 << 20; //4 MB
localparam [31:0] IRQ_ADDR  = 32'hF000_0000;

reg clk = 1'b0;
reg rst_n = 1'b0;
always #5 clk = ~clk;

reg [31:0] mem [0:MEM_WORDS-1];

integer stall_pct = 0;
integer seed = 1;
longint timeout = 2000000;
reg [31:0] tohost = 32'h8000_1000;
integer trace_fd = 0;

//core ports
wire        instr_req, data_req, data_we;
wire [31:0] instr_addr, data_addr, data_wdata;
wire [3:0]  data_be;
reg         instr_gnt, data_gnt;
reg         instr_rvalid = 1'b0, data_rvalid = 1'b0;
reg  [31:0] instr_rdata = 32'b0, data_rdata = 32'b0;
reg         instr_err = 1'b0, data_err = 1'b0;
reg  [18:0] irq_lines = 19'b0;
reg  [63:0] mtime = 64'b0;

wire        rvfi_valid, rvfi_trap, rvfi_halt, rvfi_intr;
wire [63:0] rvfi_order, rvfi_mcycle, rvfi_minstret;
wire [31:0] rvfi_insn, rvfi_rs1_rdata, rvfi_rs2_rdata, rvfi_rd_wdata, rvfi_pc_rdata, rvfi_pc_wdata;
wire [31:0] rvfi_mem_addr, rvfi_mem_rdata, rvfi_mem_wdata, rvfi_frd_wdata;
wire [4:0]  rvfi_rs1_addr, rvfi_rs2_addr, rvfi_rd_addr, rvfi_frd_addr, rvfi_fflags;
wire [3:0]  rvfi_mem_rmask, rvfi_mem_wmask;
wire [1:0]  rvfi_mode, rvfi_ixl;
wire        rvfi_frd_we;

hornet_core #(.RESET_VECTOR(BASE), .MTVEC_RESET(BASE)) dut
    (.clk_i(clk), .rst_ni(rst_n),
     .instr_req_o(instr_req), .instr_gnt_i(instr_gnt), .instr_addr_o(instr_addr),
     .instr_rvalid_i(instr_rvalid), .instr_rdata_i(instr_rdata), .instr_err_i(instr_err),
     .data_req_o(data_req), .data_gnt_i(data_gnt), .data_we_o(data_we), .data_be_o(data_be),
     .data_addr_o(data_addr), .data_wdata_o(data_wdata),
     .data_rvalid_i(data_rvalid), .data_rdata_i(data_rdata), .data_err_i(data_err),
     .msip_i(irq_lines[0]), .mtip_i(irq_lines[1]), .meip_i(irq_lines[2]),
     .fast_irq_i(irq_lines[18:3]), .mtime_i(mtime),
     .rvfi_valid(rvfi_valid), .rvfi_order(rvfi_order), .rvfi_insn(rvfi_insn),
     .rvfi_trap(rvfi_trap), .rvfi_halt(rvfi_halt), .rvfi_intr(rvfi_intr),
     .rvfi_mode(rvfi_mode), .rvfi_ixl(rvfi_ixl),
     .rvfi_rs1_addr(rvfi_rs1_addr), .rvfi_rs2_addr(rvfi_rs2_addr),
     .rvfi_rs1_rdata(rvfi_rs1_rdata), .rvfi_rs2_rdata(rvfi_rs2_rdata),
     .rvfi_rd_addr(rvfi_rd_addr), .rvfi_rd_wdata(rvfi_rd_wdata),
     .rvfi_pc_rdata(rvfi_pc_rdata), .rvfi_pc_wdata(rvfi_pc_wdata),
     .rvfi_mem_addr(rvfi_mem_addr), .rvfi_mem_rmask(rvfi_mem_rmask), .rvfi_mem_wmask(rvfi_mem_wmask),
     .rvfi_mem_rdata(rvfi_mem_rdata), .rvfi_mem_wdata(rvfi_mem_wdata),
     .rvfi_frd_we(rvfi_frd_we), .rvfi_frd_addr(rvfi_frd_addr), .rvfi_frd_wdata(rvfi_frd_wdata),
     .rvfi_fflags(rvfi_fflags), .rvfi_mcycle(rvfi_mcycle), .rvfi_minstret(rvfi_minstret));

function automatic bit in_mem(input [31:0] a);
    return a >= BASE && a < BASE + MEM_WORDS * 4;
endfunction

function automatic bit err_region(input [31:0] a);
    return a[31:28] == 4'hE;
endfunction

function automatic int index(input [31:0] a);
    return (a - BASE) >> 2;
endfunction

function automatic bit stall_now();
    return stall_pct > 0 && ($urandom % 100) < stall_pct;
endfunction

function automatic int latency();
    return stall_pct > 0 ? $urandom % 4 : 0;
endfunction

//one outstanding request per port; with no wait states the response comes in the cycle after the grant
reg     i_pend = 1'b0, d_pend = 1'b0;
integer i_delay = 0, d_delay = 0;
reg     i_block = 1'b0, d_block = 1'b0;
reg [31:0] i_data, d_data;
reg     i_e, d_e;

always @*
begin
    instr_gnt = instr_req && !i_block && (!i_pend || instr_rvalid);
    data_gnt  = data_req && !d_block && (!d_pend || data_rvalid);
end

always @(posedge clk)
begin
    integer lat;
    i_block <= stall_now();
    d_block <= stall_now();
    mtime <= mtime + 64'd1;

    //instruction port
    if(instr_req && instr_gnt)
    begin
        lat = latency();
        i_e = !in_mem(instr_addr);
        i_data = i_e ? 32'b0 : mem[index(instr_addr)];
        i_pend <= 1'b1;
        i_delay <= lat;
        instr_rvalid <= lat == 0;
        instr_rdata <= i_data;
        instr_err <= i_e;
    end
    else if(instr_rvalid)
    begin
        instr_rvalid <= 1'b0;
        i_pend <= 1'b0;
    end
    else if(i_pend)
    begin
        if(i_delay <= 1)
            instr_rvalid <= 1'b1;
        i_delay <= i_delay - 1;
    end

    //data port
    if(data_req && data_gnt)
    begin
        lat = latency();
        d_e = 1'b0;
        d_data = 32'b0;
        if(data_addr == IRQ_ADDR)
        begin
            if(data_we)
                irq_lines <= {data_wdata[31:16], data_wdata[2:0]};
            d_data = {irq_lines[18:3], 13'b0, irq_lines[2:0]};
        end
        else if(in_mem(data_addr))
        begin
            d_data = mem[index(data_addr)];
            if(data_we)
            begin
                for(int b = 0; b < 4; b++)
                    if(data_be[b])
                        mem[index(data_addr)][8*b +: 8] <= data_wdata[8*b +: 8];
                if(data_addr == tohost && data_wdata != 32'b0)
                    finish_test(data_wdata);
            end
        end
        else
            d_e = 1'b1;
        d_pend <= 1'b1;
        d_delay <= lat;
        data_rvalid <= lat == 0;
        data_rdata <= d_data;
        data_err <= d_e;
    end
    else if(data_rvalid)
    begin
        data_rvalid <= 1'b0;
        d_pend <= 1'b0;
    end
    else if(d_pend)
    begin
        if(d_delay <= 1)
            data_rvalid <= 1'b1;
        d_delay <= d_delay - 1;
    end
end

longint cycles = 0;
longint retired = 0;
longint last_retire = 0;
reg [31:0] expect_pc;
bit        have_pc = 1'b0;

task automatic finish_test(input [31:0] code);
    if(code == 32'd1)
        $display("PASS cycles=%0d instret=%0d", cycles, retired);
    else
        $display("FAIL test=%0d cycles=%0d instret=%0d", code >> 1, cycles, retired);
    if(trace_fd != 0)
        $fclose(trace_fd);
    $finish;
endtask

always @(posedge clk)
begin
    if(rst_n)
        cycles <= cycles + 1;
    if(rst_n && cycles > timeout)
    begin
        $display("TIMEOUT cycles=%0d instret=%0d pc=%08x", cycles, retired, expect_pc);
        $finish;
    end
    if(rst_n && cycles - last_retire > 10000)
    begin
        $display("HANG cycles=%0d instret=%0d pc=%08x", cycles, retired, expect_pc);
        $finish;
    end
end

//RVFI checks and trace
always @(posedge clk)
begin
    if(rvfi_valid)
    begin
        last_retire <= cycles;
        if(rvfi_order != retired)
            $display("RVFI ERROR order %0d, expected %0d", rvfi_order, retired);
        if(have_pc && !rvfi_intr && rvfi_pc_rdata != expect_pc)
            $display("RVFI ERROR pc %08x, expected %08x", rvfi_pc_rdata, expect_pc);
        if(rvfi_rd_addr == 5'd0 && rvfi_rd_wdata != 32'b0)
            $display("RVFI ERROR x0 write data %08x", rvfi_rd_wdata);
        retired <= retired + 1;
        expect_pc = rvfi_pc_wdata;
        have_pc = 1'b1;
        if(trace_fd != 0)
            write_trace();
    end
end

task automatic write_trace();
    string line, tag;
    int lo, size;
    tag = "";
    if(rvfi_trap)
        tag = "trap ";
    else if(rvfi_intr)
        tag = "intr ";
    line = {tag, $sformatf("0x%08x (0x%08x)", rvfi_pc_rdata, rvfi_insn)};
    if(rvfi_rd_addr != 5'd0)
        line = {line, $sformatf(" x%0d 0x%08x", rvfi_rd_addr, rvfi_rd_wdata)};
    if(rvfi_frd_we)
        line = {line, $sformatf(" f%0d 0x%08x", rvfi_frd_addr, rvfi_frd_wdata)};
    if(!rvfi_trap && (rvfi_mem_rmask != 4'b0 || rvfi_mem_wmask != 4'b0))
    begin
        logic [3:0] m;
        m = rvfi_mem_rmask | rvfi_mem_wmask;
        lo = m[0] ? 0 : m[1] ? 1 : m[2] ? 2 : 3;
        size = m == 4'b1111 ? 4 : (m == 4'b0011 || m == 4'b1100) ? 2 : 1;
        if(rvfi_mem_wmask != 4'b0)
            line = {line, $sformatf(" mem 0x%08x 0x%0x", rvfi_mem_addr + lo,
                    (rvfi_mem_wdata >> (8 * lo)) & (size == 4 ? 32'hffffffff : size == 2 ? 32'hffff : 32'hff))};
        else
            line = {line, $sformatf(" mem 0x%08x", rvfi_mem_addr + lo)};
    end
    $fdisplay(trace_fd, "%s", line);
endtask

initial
begin
    string hex, trace;
    void'($value$plusargs("mem_stall=%d", stall_pct));
    void'($value$plusargs("seed=%d", seed));
    void'($value$plusargs("timeout=%d", timeout));
    void'($value$plusargs("tohost=%h", tohost));
    void'($urandom(seed));
    for(int i = 0; i < MEM_WORDS; i++)
        mem[i] = 32'b0;
    if($value$plusargs("hex=%s", hex))
        $readmemh(hex, mem);
    else
    begin
        $display("no +hex=<file>");
        $finish;
    end
    if($value$plusargs("trace=%s", trace))
        trace_fd = $fopen(trace, "w");
    if($value$plusargs("waves=%s", trace))
    begin
        $dumpfile(trace);
        $dumpvars(0, hornet_tb);
    end
    repeat(3) @(posedge clk);
    rst_n <= 1'b1;
end

endmodule
