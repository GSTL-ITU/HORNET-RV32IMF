// HORNET on the Nexys 4 DDR (Artix-7 100T): 100 MHz oscillator to the core clock through an MMCM
//   LED[15:0] = gpio_o[15:0], gpio_i = {JA, 3'b0, BTND, BTNR, BTNL, BTNU, BTNC, SW}
//   JA[7:0] = gpio[31:24] (direction from the GPIO DIR register)
//   The external AXI4-Lite port answers DECERR here; hornet_soc is the block to use in a block design.
`timescale 1ns/1ps

module hornet_nexys4ddr #(parameter IMEM_SIZE = 65536,
                          parameter DMEM_SIZE = 65536,
                          parameter IMEM_INIT = "imem.hex",
                          parameter DMEM_INIT = "dmem.hex",
                          parameter CLK_DIV   = 20,        //1000 MHz VCO / CLK_DIV
                          parameter BAUD      = 115200,
                          parameter BOOT_ADDR = 32'h0000_0000)
(input         CLK100MHZ,
 input         CPU_RESETN,
 input         UART_TXD_IN,   //from the USB-UART bridge
 output        UART_RXD_OUT,  //to the USB-UART bridge
 input  [15:0] SW,
 input         BTNC, BTNU, BTNL, BTNR, BTND,
 output [15:0] LED,
 inout  [7:0]  JA);

localparam CLK_FREQ = 1000000000 / CLK_DIV;

wire clk_fb, clk_mmcm, clk, locked;

MMCME2_BASE #(.CLKIN1_PERIOD(10.0),
              .CLKFBOUT_MULT_F(10.0),
              .DIVCLK_DIVIDE(1),
              .CLKOUT0_DIVIDE_F(CLK_DIV)) MMCM
    (.CLKIN1(CLK100MHZ),
     .CLKFBIN(clk_fb),
     .CLKFBOUT(clk_fb),
     .CLKOUT0(clk_mmcm),
     .LOCKED(locked),
     .PWRDWN(1'b0),
     .RST(1'b0),
     .CLKOUT0B(), .CLKOUT1(), .CLKOUT1B(), .CLKOUT2(), .CLKOUT2B(), .CLKOUT3(), .CLKOUT3B(),
     .CLKOUT4(), .CLKOUT5(), .CLKOUT6(), .CLKFBOUTB());

BUFG CLK_BUF(.I(clk_mmcm), .O(clk));

//reset: asynchronous assert, synchronous release
reg [2:0] rst_sync;
always @(posedge clk or negedge locked)
    if(!locked)
        rst_sync <= 3'b0;
    else
        rst_sync <= {rst_sync[1:0], CPU_RESETN};
wire rst_n = rst_sync[2];

wire [31:0] gpio_o, gpio_oe;
wire [7:0]  ja_in = JA;

genvar i;
generate
    for(i = 0; i < 8; i = i + 1)
    begin : PMOD
        assign JA[i] = gpio_oe[24+i] ? gpio_o[24+i] : 1'bz;
    end
endgenerate

assign LED = gpio_o[15:0];

wire        awvalid, awready, wvalid, wready, bvalid, bready, arvalid, arready, rvalid, rready;
wire [1:0]  bresp, rresp;
wire [31:0] rdata;

hornet_soc #(.IMEM_SIZE(IMEM_SIZE), .DMEM_SIZE(DMEM_SIZE), .IMEM_INIT(IMEM_INIT), .DMEM_INIT(DMEM_INIT),
             .CLK_FREQ(CLK_FREQ), .BAUD(BAUD), .BOOT_ADDR(BOOT_ADDR)) SOC
    (.clk_i(clk),
     .rst_ni(rst_n),
     .uart_rx_i(UART_TXD_IN),
     .uart_tx_o(UART_RXD_OUT),
     .gpio_i({ja_in, 3'b0, BTND, BTNR, BTNL, BTNU, BTNC, SW}),
     .gpio_o(gpio_o),
     .gpio_oe_o(gpio_oe),
     .meip_i(1'b0),
     .irq_i(14'b0),
     .m_axi_awaddr(),
     .m_axi_awprot(),
     .m_axi_awvalid(awvalid),
     .m_axi_awready(awready),
     .m_axi_wdata(),
     .m_axi_wstrb(),
     .m_axi_wvalid(wvalid),
     .m_axi_wready(wready),
     .m_axi_bresp(bresp),
     .m_axi_bvalid(bvalid),
     .m_axi_bready(bready),
     .m_axi_araddr(),
     .m_axi_arprot(),
     .m_axi_arvalid(arvalid),
     .m_axi_arready(arready),
     .m_axi_rdata(rdata),
     .m_axi_rresp(rresp),
     .m_axi_rvalid(rvalid),
     .m_axi_rready(rready));

axil_error_slave EXT_NONE
    (.clk_i(clk), .rst_ni(rst_n),
     .s_awvalid(awvalid), .s_awready(awready), .s_wvalid(wvalid), .s_wready(wready),
     .s_bresp(bresp), .s_bvalid(bvalid), .s_bready(bready),
     .s_arvalid(arvalid), .s_arready(arready), .s_rdata(rdata), .s_rresp(rresp),
     .s_rvalid(rvalid), .s_rready(rready));

endmodule
