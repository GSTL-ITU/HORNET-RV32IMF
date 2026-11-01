// AXI4-Lite interconnect: one master, N slaves, address decode, DECERR for holes
// The master (obi_axil_bridge) has one transaction at a time and keeps its
// address stable until the response, so the decode needs no state.
module axil_xbar #(parameter N    = 4,
                   parameter BASE = {32'h4000_0000, 32'h2002_0000, 32'h2001_0000, 32'h2000_0000},
                   parameter MASK = {32'hC000_0000, 32'hFFFF_0000, 32'hFFFF_0000, 32'hFFFF_0000})
(input              clk_i,
 input              rst_ni,

 input      [31:0]  s_awaddr,
 input      [2:0]   s_awprot,
 input              s_awvalid,
 output             s_awready,
 input      [31:0]  s_wdata,
 input      [3:0]   s_wstrb,
 input              s_wvalid,
 output             s_wready,
 output     [1:0]   s_bresp,
 output             s_bvalid,
 input              s_bready,
 input      [31:0]  s_araddr,
 input      [2:0]   s_arprot,
 input              s_arvalid,
 output             s_arready,
 output     [31:0]  s_rdata,
 output     [1:0]   s_rresp,
 output             s_rvalid,
 input              s_rready,

 output [N*32-1:0]  m_awaddr,
 output [N*3-1:0]   m_awprot,
 output [N-1:0]     m_awvalid,
 input  [N-1:0]     m_awready,
 output [N*32-1:0]  m_wdata,
 output [N*4-1:0]   m_wstrb,
 output [N-1:0]     m_wvalid,
 input  [N-1:0]     m_wready,
 input  [N*2-1:0]   m_bresp,
 input  [N-1:0]     m_bvalid,
 output [N-1:0]     m_bready,
 output [N*32-1:0]  m_araddr,
 output [N*3-1:0]   m_arprot,
 output [N-1:0]     m_arvalid,
 input  [N-1:0]     m_arready,
 input  [N*32-1:0]  m_rdata,
 input  [N*2-1:0]   m_rresp,
 input  [N-1:0]     m_rvalid,
 output [N-1:0]     m_rready);

reg [N-1:0] wsel, rsel;
integer i;
always @*
begin
    wsel = {N{1'b0}};
    rsel = {N{1'b0}};
    for(i = 0; i < N; i = i + 1)
    begin
        if((s_awaddr & MASK[i*32 +: 32]) == BASE[i*32 +: 32] && wsel == {N{1'b0}})
            wsel[i] = 1'b1;
        if((s_araddr & MASK[i*32 +: 32]) == BASE[i*32 +: 32] && rsel == {N{1'b0}})
            rsel[i] = 1'b1;
    end
end

wire wnone = wsel == {N{1'b0}};
wire rnone = rsel == {N{1'b0}};

//decode error responder
reg err_b, err_r;
always @(posedge clk_i or negedge rst_ni)
begin
    if(!rst_ni)
    begin
        err_b <= 1'b0;
        err_r <= 1'b0;
    end
    else
    begin
        if(err_b && s_bready)
            err_b <= 1'b0;
        else if(wnone && s_awvalid && s_wvalid)
            err_b <= 1'b1;
        if(err_r && s_rready)
            err_r <= 1'b0;
        else if(rnone && s_arvalid)
            err_r <= 1'b1;
    end
end

assign m_awaddr  = {N{s_awaddr}};
assign m_awprot  = {N{s_awprot}};
assign m_awvalid = wsel & {N{s_awvalid}};
assign m_wdata   = {N{s_wdata}};
assign m_wstrb   = {N{s_wstrb}};
assign m_wvalid  = wsel & {N{s_wvalid}};
assign m_bready  = wsel & {N{s_bready}};
assign m_araddr  = {N{s_araddr}};
assign m_arprot  = {N{s_arprot}};
assign m_arvalid = rsel & {N{s_arvalid}};
assign m_rready  = rsel & {N{s_rready}};

reg [1:0]  bresp, rresp;
reg [31:0] rdata;
always @*
begin
    bresp = 2'b11;
    rresp = 2'b11;
    rdata = 32'b0;
    for(i = 0; i < N; i = i + 1)
    begin
        if(wsel[i])
            bresp = m_bresp[i*2 +: 2];
        if(rsel[i])
        begin
            rresp = m_rresp[i*2 +: 2];
            rdata = m_rdata[i*32 +: 32];
        end
    end
end

assign s_awready = wnone ? (s_wvalid && !err_b) : |(wsel & m_awready);
assign s_wready  = wnone ? (s_awvalid && !err_b) : |(wsel & m_wready);
assign s_bvalid  = wnone ? err_b : |(wsel & m_bvalid);
assign s_bresp   = bresp;
assign s_arready = rnone ? !err_r : |(rsel & m_arready);
assign s_rvalid  = rnone ? err_r : |(rsel & m_rvalid);
assign s_rresp   = rresp;
assign s_rdata   = rdata;

endmodule
