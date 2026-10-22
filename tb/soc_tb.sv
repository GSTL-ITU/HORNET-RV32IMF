// SoC testbench: runs a program from its IMEM/DMEM images
//
// plusargs: +imem=<hex> +dmem=<hex> +uart_in=<file> +uart_log=<file> +waves=<file.fst>
//           +timeout=<cycles> +axi_stall=<pct>
// The UART output is decoded and printed. GPIO outputs loop back to the inputs,
// gpio_o[29:16] drive the fast interrupt pins and gpio_o[31] the external interrupt.
// An AXI4-Lite RAM (4 KB) sits at the external port base 0x4000_0000; other
// external addresses answer SLVERR. The program ends by writing the system
// control EXIT register: 0 is PASS.
`timescale 1ns/1ps

module soc_tb;

parameter IMEM_SIZE = 65536;
parameter DMEM_SIZE = 65536;
localparam CLK_FREQ = 50000000;
localparam BAUD     = 3125000; //16 cycles per bit

reg clk = 1'b0;
reg rst_n = 1'b0;
always #10 clk = ~clk;

wire        uart_tx;
reg         uart_rx = 1'b1;
wire [31:0] gpio_o, gpio_oe;

wire [31:0] awaddr, wdata, araddr;
wire [2:0]  awprot, arprot;
wire [3:0]  wstrb;
wire        awvalid, wvalid, bready, arvalid, rready;
reg         awready = 1'b0, wready = 1'b0, bvalid = 1'b0, arready = 1'b0, rvalid = 1'b0;
reg  [1:0]  bresp = 2'b00, rresp = 2'b00;
reg  [31:0] rdata = 32'b0;

hornet_soc #(.IMEM_SIZE(IMEM_SIZE), .DMEM_SIZE(DMEM_SIZE), .CLK_FREQ(CLK_FREQ), .BAUD(BAUD)) dut
    (.clk_i(clk), .rst_ni(rst_n),
     .uart_rx_i(uart_rx), .uart_tx_o(uart_tx),
     .gpio_i(gpio_o), .gpio_o(gpio_o), .gpio_oe_o(gpio_oe),
     .meip_i(gpio_o[31]), .irq_i(gpio_o[29:16]),
     .m_axi_awaddr(awaddr), .m_axi_awprot(awprot), .m_axi_awvalid(awvalid), .m_axi_awready(awready),
     .m_axi_wdata(wdata), .m_axi_wstrb(wstrb), .m_axi_wvalid(wvalid), .m_axi_wready(wready),
     .m_axi_bresp(bresp), .m_axi_bvalid(bvalid), .m_axi_bready(bready),
     .m_axi_araddr(araddr), .m_axi_arprot(arprot), .m_axi_arvalid(arvalid), .m_axi_arready(arready),
     .m_axi_rdata(rdata), .m_axi_rresp(rresp), .m_axi_rvalid(rvalid), .m_axi_rready(rready));

integer axi_stall = 20;
longint timeout = 50000000;
longint cycles = 0;
integer log_fd = 0;

//external AXI4-Lite RAM with random ready delays
reg [31:0] ext_ram [0:1023];
reg        aw_done = 1'b0, w_done = 1'b0;
reg [31:0] aw_q, w_q;
reg [3:0]  ws_q;

function automatic bit stall();
    return ($urandom % 100) < axi_stall;
endfunction

always @(posedge clk)
begin
    awready <= 1'b0;
    wready <= 1'b0;
    arready <= 1'b0;
    if(bvalid && bready)
        bvalid <= 1'b0;
    if(rvalid && rready)
        rvalid <= 1'b0;

    if(awvalid && !awready && !aw_done && !stall())
    begin
        awready <= 1'b1;
        aw_done <= 1'b1;
        aw_q <= awaddr;
    end
    if(wvalid && !wready && !w_done && !stall())
    begin
        wready <= 1'b1;
        w_done <= 1'b1;
        w_q <= wdata;
        ws_q <= wstrb;
    end
    if(aw_done && w_done && !bvalid && !stall())
    begin
        aw_done <= 1'b0;
        w_done <= 1'b0;
        bvalid <= 1'b1;
        if(aw_q[31:12] == 20'h40000)
        begin
            bresp <= 2'b00;
            for(int b = 0; b < 4; b++)
                if(ws_q[b])
                    ext_ram[aw_q[11:2]][8*b +: 8] <= w_q[8*b +: 8];
        end
        else
            bresp <= 2'b10;
    end
    if(arvalid && !arready && !rvalid && !stall())
    begin
        arready <= 1'b1;
        rvalid <= 1'b1;
        rresp <= araddr[31:12] == 20'h40000 ? 2'b00 : 2'b10;
        rdata <= araddr[31:12] == 20'h40000 ? ext_ram[araddr[11:2]] : 32'hdeadbeef;
    end
end

//UART output: sample in the middle of each bit with the divisor the program set
string line = "";
initial
begin
    forever
    begin
        int div;
        reg [7:0] c;
        @(negedge uart_tx);
        div = dut.UART.div;
        repeat(div / 2) @(posedge clk);
        for(int i = 0; i < 8; i++)
        begin
            repeat(div) @(posedge clk);
            c[i] = uart_tx;
        end
        repeat(div) @(posedge clk);
        if(c == 8'h0a)
        begin
            $display("UART: %s", line);
            if(log_fd != 0)
                $fdisplay(log_fd, "%s", line);
            line = "";
        end
        else if(c != 8'h0d)
            line = {line, string'(c)};
    end
end

//UART input from a file
task automatic send_byte(input [7:0] b);
    int div;
    div = dut.UART.div;
    uart_rx = 1'b0;
    repeat(div) @(posedge clk);
    for(int i = 0; i < 8; i++)
    begin
        uart_rx = b[i];
        repeat(div) @(posedge clk);
    end
    uart_rx = 1'b1;
    repeat(div * 2) @(posedge clk);
endtask

initial
begin
    string f;
    int fd, c;
    if($value$plusargs("uart_in=%s", f))
    begin
        fd = $fopen(f, "rb");
        repeat(2000) @(posedge clk);
        while((c = $fgetc(fd)) != -1)
            send_byte(c[7:0]);
    end
end

always @(posedge clk)
begin
    if(rst_n)
        cycles <= cycles + 1;
    if(dut.SYSCTL.exit_o)
    begin
        if(line != "")
            $display("UART: %s", line);
        if(dut.SYSCTL.exit_code_o == 32'd0)
            $display("PASS cycles=%0d instret=%0d", cycles, dut.CORE.CSR_UNIT.minstret_q);
        else
            $display("FAIL code=0x%0x cycles=%0d", dut.SYSCTL.exit_code_o, cycles);
        if(log_fd != 0)
            $fclose(log_fd);
        $finish;
    end
    if(cycles > timeout)
    begin
        if(line != "")
            $display("UART: %s", line);
        $display("TIMEOUT cycles=%0d pc=%08x", cycles, dut.CORE.instr_addr_o);
        $finish;
    end
end

initial
begin
    string s;
    void'($value$plusargs("timeout=%d", timeout));
    void'($value$plusargs("axi_stall=%d", axi_stall));
    for(int i = 0; i < 1024; i++)
        ext_ram[i] = 32'b0;
    if($value$plusargs("imem=%s", s))
        $readmemh(s, dut.IMEM.mem);
    else
    begin
        $display("no +imem=<file>");
        $finish;
    end
    if($value$plusargs("dmem=%s", s))
        $readmemh(s, dut.DMEM.mem);
    if($value$plusargs("uart_log=%s", s))
        log_fd = $fopen(s, "w");
    if($value$plusargs("waves=%s", s))
    begin
        $dumpfile(s);
        $dumpvars(0, soc_tb);
    end
    repeat(5) @(posedge clk);
    rst_n <= 1'b1;
end

endmodule
