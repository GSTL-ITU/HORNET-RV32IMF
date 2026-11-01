// Request/grant/valid port to AXI4-Lite master, one transaction at a time
// SLVERR and DECERR answer the core with an error (access fault).
module obi_axil_bridge
(input             clk_i,
 input             rst_ni,

 input             req_i,
 output            gnt_o,
 input             we_i,
 input      [3:0]  be_i,
 input      [31:0] addr_i,
 input      [31:0] wdata_i,
 output reg        rvalid_o,
 output reg [31:0] rdata_o,
 output reg        err_o,

 output     [31:0] m_axi_awaddr,
 output     [2:0]  m_axi_awprot,
 output reg        m_axi_awvalid,
 input             m_axi_awready,
 output     [31:0] m_axi_wdata,
 output     [3:0]  m_axi_wstrb,
 output reg        m_axi_wvalid,
 input             m_axi_wready,
 input      [1:0]  m_axi_bresp,
 input             m_axi_bvalid,
 output            m_axi_bready,
 output     [31:0] m_axi_araddr,
 output     [2:0]  m_axi_arprot,
 output reg        m_axi_arvalid,
 input             m_axi_arready,
 input      [31:0] m_axi_rdata,
 input      [1:0]  m_axi_rresp,
 input             m_axi_rvalid,
 output            m_axi_rready);

reg        busy_q;
reg [31:0] addr_q, wdata_q;
reg [3:0]  be_q;

assign gnt_o = !busy_q;

assign m_axi_awaddr = addr_q;
assign m_axi_araddr = addr_q;
assign m_axi_awprot = 3'b000;
assign m_axi_arprot = 3'b000;
assign m_axi_wdata  = wdata_q;
assign m_axi_wstrb  = be_q;
assign m_axi_bready = 1'b1;
assign m_axi_rready = 1'b1;

always @(posedge clk_i or negedge rst_ni)
begin
    if(!rst_ni)
    begin
        busy_q <= 1'b0;
        {addr_q, wdata_q} <= 64'b0;
        be_q <= 4'b0;
        {m_axi_awvalid, m_axi_wvalid, m_axi_arvalid} <= 3'b0;
        rvalid_o <= 1'b0;
        rdata_o <= 32'b0;
        err_o <= 1'b0;
    end
    else
    begin
        rvalid_o <= 1'b0;
        if(!busy_q)
        begin
            if(req_i)
            begin
                busy_q <= 1'b1;
                addr_q <= addr_i;
                wdata_q <= wdata_i;
                be_q <= be_i;
                m_axi_awvalid <= we_i;
                m_axi_wvalid <= we_i;
                m_axi_arvalid <= !we_i;
            end
        end
        else
        begin
            if(m_axi_awready)
                m_axi_awvalid <= 1'b0;
            if(m_axi_wready)
                m_axi_wvalid <= 1'b0;
            if(m_axi_arready)
                m_axi_arvalid <= 1'b0;
            if(m_axi_bvalid)
            begin
                busy_q <= 1'b0;
                rvalid_o <= 1'b1;
                rdata_o <= 32'b0;
                err_o <= m_axi_bresp[1];
            end
            if(m_axi_rvalid)
            begin
                busy_q <= 1'b0;
                rvalid_o <= 1'b1;
                rdata_o <= m_axi_rdata;
                err_o <= m_axi_rresp[1];
            end
        end
    end
end

endmodule
