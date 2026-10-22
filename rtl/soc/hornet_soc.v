// HORNET SoC: core, instruction and data memories, AXI4-Lite peripherals and an external AXI4-Lite port
//   0x0000_0000 IMEM   0x1000_0000 DMEM   0x2000_0000 timer   0x2001_0000 UART   0x2002_0000 GPIO
//   0x2003_0000 system control
//   0x4000_0000 - 0x7FFF_FFFF external AXI4-Lite (m_axi_*)
module hornet_soc #(parameter IMEM_SIZE = 65536,
                    parameter DMEM_SIZE = 65536,
                    parameter IMEM_INIT = "",
                    parameter DMEM_INIT = "",
                    parameter CLK_FREQ  = 50000000,
                    parameter BAUD      = 115200)
(input         clk_i,
 input         rst_ni, //synchronous release

 input         uart_rx_i,
 output        uart_tx_o,

 input  [31:0] gpio_i,
 output [31:0] gpio_o,
 output [31:0] gpio_oe_o,

 input         meip_i,     //machine external interrupt
 input  [13:0] irq_i,      //fast interrupts 2..15

 output [31:0] m_axi_awaddr,
 output [2:0]  m_axi_awprot,
 output        m_axi_awvalid,
 input         m_axi_awready,
 output [31:0] m_axi_wdata,
 output [3:0]  m_axi_wstrb,
 output        m_axi_wvalid,
 input         m_axi_wready,
 input  [1:0]  m_axi_bresp,
 input         m_axi_bvalid,
 output        m_axi_bready,
 output [31:0] m_axi_araddr,
 output [2:0]  m_axi_arprot,
 output        m_axi_arvalid,
 input         m_axi_arready,
 input  [31:0] m_axi_rdata,
 input  [1:0]  m_axi_rresp,
 input         m_axi_rvalid,
 output        m_axi_rready);

//core ports
wire        instr_req, instr_gnt, instr_rvalid, instr_err;
wire [31:0] instr_addr, instr_rdata;
wire        data_req, data_gnt, data_we, data_rvalid, data_err;
wire [3:0]  data_be;
wire [31:0] data_addr, data_wdata, data_rdata;

wire        msip, mtip, uart_irq, gpio_irq;
wire [63:0] mtime;

hornet_core #(.RESET_VECTOR(32'h0000_0000), .MTVEC_RESET(32'h0000_0000)) CORE
    (.clk_i(clk_i),
     .rst_ni(rst_ni),
     .instr_req_o(instr_req),
     .instr_gnt_i(instr_gnt),
     .instr_addr_o(instr_addr),
     .instr_rvalid_i(instr_rvalid),
     .instr_rdata_i(instr_rdata),
     .instr_err_i(instr_err),
     .data_req_o(data_req),
     .data_gnt_i(data_gnt),
     .data_we_o(data_we),
     .data_be_o(data_be),
     .data_addr_o(data_addr),
     .data_wdata_o(data_wdata),
     .data_rvalid_i(data_rvalid),
     .data_rdata_i(data_rdata),
     .data_err_i(data_err),
     .msip_i(msip),
     .mtip_i(mtip),
     .meip_i(meip_i),
     .fast_irq_i({irq_i, gpio_irq, uart_irq}),
     .mtime_i(mtime),
     .rvfi_valid(), .rvfi_order(), .rvfi_insn(), .rvfi_trap(), .rvfi_halt(), .rvfi_intr(),
     .rvfi_mode(), .rvfi_ixl(), .rvfi_rs1_addr(), .rvfi_rs2_addr(), .rvfi_rs1_rdata(),
     .rvfi_rs2_rdata(), .rvfi_rd_addr(), .rvfi_rd_wdata(), .rvfi_pc_rdata(), .rvfi_pc_wdata(),
     .rvfi_mem_addr(), .rvfi_mem_rmask(), .rvfi_mem_wmask(), .rvfi_mem_rdata(), .rvfi_mem_wdata(),
     .rvfi_frd_we(), .rvfi_frd_addr(), .rvfi_frd_wdata(), .rvfi_fflags(),
     .rvfi_csr_valid(), .rvfi_csr_addr(), .rvfi_csr_we(), .rvfi_csr_rdata(), .rvfi_csr_wdata(),
     .rvfi_csr_mcycle(), .rvfi_csr_minstret());

//data port decode
wire [31:0] bus_addr, bus_wdata;
wire        bus_we;
wire [3:0]  bus_be;
wire        imem_b_req, imem_b_rvalid, dmem_req, dmem_rvalid;
wire [31:0] imem_b_rdata, dmem_rdata;
wire        axi_req, axi_gnt, axi_rvalid, axi_err;
wire [31:0] axi_rdata;

data_router #(.IMEM_SIZE(IMEM_SIZE), .DMEM_SIZE(DMEM_SIZE)) DATA_ROUTER
    (.clk_i(clk_i),
     .rst_ni(rst_ni),
     .req_i(data_req),
     .gnt_o(data_gnt),
     .we_i(data_we),
     .be_i(data_be),
     .addr_i(data_addr),
     .wdata_i(data_wdata),
     .rvalid_o(data_rvalid),
     .rdata_o(data_rdata),
     .err_o(data_err),
     .addr_o(bus_addr),
     .we_o(bus_we),
     .be_o(bus_be),
     .wdata_o(bus_wdata),
     .imem_req_o(imem_b_req),
     .imem_rvalid_i(imem_b_rvalid),
     .imem_rdata_i(imem_b_rdata),
     .dmem_req_o(dmem_req),
     .dmem_rvalid_i(dmem_rvalid),
     .dmem_rdata_i(dmem_rdata),
     .axi_req_o(axi_req),
     .axi_gnt_i(axi_gnt),
     .axi_rvalid_i(axi_rvalid),
     .axi_rdata_i(axi_rdata),
     .axi_err_i(axi_err));

imem #(.SIZE(IMEM_SIZE), .INIT(IMEM_INIT)) IMEM
    (.clk_i(clk_i),
     .rst_ni(rst_ni),
     .a_req_i(instr_req),
     .a_gnt_o(instr_gnt),
     .a_addr_i(instr_addr),
     .a_rvalid_o(instr_rvalid),
     .a_rdata_o(instr_rdata),
     .a_err_o(instr_err),
     .b_req_i(imem_b_req),
     .b_gnt_o(),
     .b_we_i(bus_we),
     .b_be_i(bus_be),
     .b_addr_i(bus_addr),
     .b_wdata_i(bus_wdata),
     .b_rvalid_o(imem_b_rvalid),
     .b_rdata_o(imem_b_rdata));

dmem #(.SIZE(DMEM_SIZE), .INIT(DMEM_INIT)) DMEM
    (.clk_i(clk_i),
     .rst_ni(rst_ni),
     .req_i(dmem_req),
     .gnt_o(),
     .we_i(bus_we),
     .be_i(bus_be),
     .addr_i(bus_addr),
     .wdata_i(bus_wdata),
     .rvalid_o(dmem_rvalid),
     .rdata_o(dmem_rdata));

//AXI4-Lite
wire [31:0] awaddr, wdata, araddr, rdata;
wire [2:0]  awprot, arprot;
wire [3:0]  wstrb;
wire [1:0]  bresp, rresp;
wire        awvalid, awready, wvalid, wready, bvalid, bready, arvalid, arready, rvalid, rready;

obi_axil_bridge AXI_BRIDGE
    (.clk_i(clk_i),
     .rst_ni(rst_ni),
     .req_i(axi_req),
     .gnt_o(axi_gnt),
     .we_i(bus_we),
     .be_i(bus_be),
     .addr_i(bus_addr),
     .wdata_i(bus_wdata),
     .rvalid_o(axi_rvalid),
     .rdata_o(axi_rdata),
     .err_o(axi_err),
     .m_axi_awaddr(awaddr),
     .m_axi_awprot(awprot),
     .m_axi_awvalid(awvalid),
     .m_axi_awready(awready),
     .m_axi_wdata(wdata),
     .m_axi_wstrb(wstrb),
     .m_axi_wvalid(wvalid),
     .m_axi_wready(wready),
     .m_axi_bresp(bresp),
     .m_axi_bvalid(bvalid),
     .m_axi_bready(bready),
     .m_axi_araddr(araddr),
     .m_axi_arprot(arprot),
     .m_axi_arvalid(arvalid),
     .m_axi_arready(arready),
     .m_axi_rdata(rdata),
     .m_axi_rresp(rresp),
     .m_axi_rvalid(rvalid),
     .m_axi_rready(rready));

//slaves: 0 timer, 1 UART, 2 GPIO, 3 external, 4 system control
wire [159:0] x_awaddr, x_wdata, x_araddr, x_rdata;
wire [14:0]  x_awprot, x_arprot;
wire [19:0]  x_wstrb;
wire [9:0]   x_bresp, x_rresp;
wire [4:0]   x_awvalid, x_awready, x_wvalid, x_wready, x_bvalid, x_bready;
wire [4:0]   x_arvalid, x_arready, x_rvalid, x_rready;

axil_xbar #(.N(5),
            .BASE({32'h2003_0000, 32'h4000_0000, 32'h2002_0000, 32'h2001_0000, 32'h2000_0000}),
            .MASK({32'hFFFF_0000, 32'hC000_0000, 32'hFFFF_0000, 32'hFFFF_0000, 32'hFFFF_0000})) AXI_XBAR
    (.clk_i(clk_i),
     .rst_ni(rst_ni),
     .s_awaddr(awaddr),
     .s_awprot(awprot),
     .s_awvalid(awvalid),
     .s_awready(awready),
     .s_wdata(wdata),
     .s_wstrb(wstrb),
     .s_wvalid(wvalid),
     .s_wready(wready),
     .s_bresp(bresp),
     .s_bvalid(bvalid),
     .s_bready(bready),
     .s_araddr(araddr),
     .s_arprot(arprot),
     .s_arvalid(arvalid),
     .s_arready(arready),
     .s_rdata(rdata),
     .s_rresp(rresp),
     .s_rvalid(rvalid),
     .s_rready(rready),
     .m_awaddr(x_awaddr),
     .m_awprot(x_awprot),
     .m_awvalid(x_awvalid),
     .m_awready(x_awready),
     .m_wdata(x_wdata),
     .m_wstrb(x_wstrb),
     .m_wvalid(x_wvalid),
     .m_wready(x_wready),
     .m_bresp(x_bresp),
     .m_bvalid(x_bvalid),
     .m_bready(x_bready),
     .m_araddr(x_araddr),
     .m_arprot(x_arprot),
     .m_arvalid(x_arvalid),
     .m_arready(x_arready),
     .m_rdata(x_rdata),
     .m_rresp(x_rresp),
     .m_rvalid(x_rvalid),
     .m_rready(x_rready));

axil_timer TIMER
    (.clk_i(clk_i),
     .rst_ni(rst_ni),
     .s_awaddr(x_awaddr[31:0]),
     .s_awvalid(x_awvalid[0]),
     .s_awready(x_awready[0]),
     .s_wdata(x_wdata[31:0]),
     .s_wstrb(x_wstrb[3:0]),
     .s_wvalid(x_wvalid[0]),
     .s_wready(x_wready[0]),
     .s_bresp(x_bresp[1:0]),
     .s_bvalid(x_bvalid[0]),
     .s_bready(x_bready[0]),
     .s_araddr(x_araddr[31:0]),
     .s_arvalid(x_arvalid[0]),
     .s_arready(x_arready[0]),
     .s_rdata(x_rdata[31:0]),
     .s_rresp(x_rresp[1:0]),
     .s_rvalid(x_rvalid[0]),
     .s_rready(x_rready[0]),
     .msip_o(msip),
     .mtip_o(mtip),
     .mtime_o(mtime));

axil_uart #(.CLK_FREQ(CLK_FREQ), .BAUD(BAUD)) UART
    (.clk_i(clk_i),
     .rst_ni(rst_ni),
     .s_awaddr(x_awaddr[63:32]),
     .s_awvalid(x_awvalid[1]),
     .s_awready(x_awready[1]),
     .s_wdata(x_wdata[63:32]),
     .s_wstrb(x_wstrb[7:4]),
     .s_wvalid(x_wvalid[1]),
     .s_wready(x_wready[1]),
     .s_bresp(x_bresp[3:2]),
     .s_bvalid(x_bvalid[1]),
     .s_bready(x_bready[1]),
     .s_araddr(x_araddr[63:32]),
     .s_arvalid(x_arvalid[1]),
     .s_arready(x_arready[1]),
     .s_rdata(x_rdata[63:32]),
     .s_rresp(x_rresp[3:2]),
     .s_rvalid(x_rvalid[1]),
     .s_rready(x_rready[1]),
     .rx_i(uart_rx_i),
     .tx_o(uart_tx_o),
     .irq_o(uart_irq));

axil_gpio GPIO
    (.clk_i(clk_i),
     .rst_ni(rst_ni),
     .s_awaddr(x_awaddr[95:64]),
     .s_awvalid(x_awvalid[2]),
     .s_awready(x_awready[2]),
     .s_wdata(x_wdata[95:64]),
     .s_wstrb(x_wstrb[11:8]),
     .s_wvalid(x_wvalid[2]),
     .s_wready(x_wready[2]),
     .s_bresp(x_bresp[5:4]),
     .s_bvalid(x_bvalid[2]),
     .s_bready(x_bready[2]),
     .s_araddr(x_araddr[95:64]),
     .s_arvalid(x_arvalid[2]),
     .s_arready(x_arready[2]),
     .s_rdata(x_rdata[95:64]),
     .s_rresp(x_rresp[5:4]),
     .s_rvalid(x_rvalid[2]),
     .s_rready(x_rready[2]),
     .gpio_i(gpio_i),
     .gpio_o(gpio_o),
     .gpio_oe_o(gpio_oe_o),
     .irq_o(gpio_irq));

assign m_axi_awaddr  = x_awaddr[127:96];
assign m_axi_awprot  = x_awprot[11:9];
assign m_axi_awvalid = x_awvalid[3];
assign x_awready[3]  = m_axi_awready;
assign m_axi_wdata   = x_wdata[127:96];
assign m_axi_wstrb   = x_wstrb[15:12];
assign m_axi_wvalid  = x_wvalid[3];
assign x_wready[3]   = m_axi_wready;
assign x_bresp[7:6]  = m_axi_bresp;
assign x_bvalid[3]   = m_axi_bvalid;
assign m_axi_bready  = x_bready[3];
assign m_axi_araddr  = x_araddr[127:96];
assign m_axi_arprot  = x_arprot[11:9];
assign m_axi_arvalid = x_arvalid[3];
assign x_arready[3]  = m_axi_arready;
assign x_rdata[127:96] = m_axi_rdata;
assign x_rresp[7:6]  = m_axi_rresp;
assign x_rvalid[3]   = m_axi_rvalid;
assign m_axi_rready  = x_rready[3];

axil_sysctl #(.CLK_FREQ(CLK_FREQ)) SYSCTL
    (.clk_i(clk_i),
     .rst_ni(rst_ni),
     .s_awaddr(x_awaddr[159:128]),
     .s_awvalid(x_awvalid[4]),
     .s_awready(x_awready[4]),
     .s_wdata(x_wdata[159:128]),
     .s_wstrb(x_wstrb[19:16]),
     .s_wvalid(x_wvalid[4]),
     .s_wready(x_wready[4]),
     .s_bresp(x_bresp[9:8]),
     .s_bvalid(x_bvalid[4]),
     .s_bready(x_bready[4]),
     .s_araddr(x_araddr[159:128]),
     .s_arvalid(x_arvalid[4]),
     .s_arready(x_arready[4]),
     .s_rdata(x_rdata[159:128]),
     .s_rresp(x_rresp[9:8]),
     .s_rvalid(x_rvalid[4]),
     .s_rready(x_rready[4]),
     .exit_o(),
     .exit_code_o());

endmodule
