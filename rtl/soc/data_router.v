// Data port address decode: IMEM (port B), DMEM, AXI4-Lite bridge or an error response
// The core keeps at most one request outstanding, so the target of that request routes the response.
module data_router #(parameter IMEM_BASE = 32'h0000_0000,
                     parameter IMEM_SIZE = 65536,
                     parameter DMEM_BASE = 32'h1000_0000,
                     parameter DMEM_SIZE = 65536,
                     parameter AXI_BASE  = 32'h2000_0000,
                     parameter AXI_LAST  = 32'h7FFF_FFFF)
(input             clk_i,
 input             rst_ni,

 //from the core
 input             req_i,
 output            gnt_o,
 input             we_i,
 input      [3:0]  be_i,
 input      [31:0] addr_i,
 input      [31:0] wdata_i,
 output            rvalid_o,
 output     [31:0] rdata_o,
 output            err_o,

 //targets share the request signals
 output     [31:0] addr_o,
 output            we_o,
 output     [3:0]  be_o,
 output     [31:0] wdata_o,

 output            imem_req_o,
 input             imem_rvalid_i,
 input      [31:0] imem_rdata_i,

 output            dmem_req_o,
 input             dmem_rvalid_i,
 input      [31:0] dmem_rdata_i,

 output            axi_req_o,
 input             axi_gnt_i,
 input             axi_rvalid_i,
 input      [31:0] axi_rdata_i,
 input             axi_err_i);

localparam NONE = 2'd0, IMEM = 2'd1, DMEM = 2'd2, AXI = 2'd3;

wire [1:0] sel = addr_i >= IMEM_BASE && addr_i - IMEM_BASE < IMEM_SIZE ? IMEM
               : addr_i >= DMEM_BASE && addr_i - DMEM_BASE < DMEM_SIZE ? DMEM
               : addr_i >= AXI_BASE && addr_i <= AXI_LAST ? AXI
               : NONE;

assign addr_o  = addr_i;
assign we_o    = we_i;
assign be_o    = be_i;
assign wdata_o = wdata_i;

assign imem_req_o = req_i && sel == IMEM;
assign dmem_req_o = req_i && sel == DMEM;
assign axi_req_o  = req_i && sel == AXI;
assign gnt_o      = sel == AXI ? axi_gnt_i : 1'b1;

reg [1:0] pend_q;   //target of the outstanding request
reg       none_q;   //decode error response

always @(posedge clk_i or negedge rst_ni)
begin
    if(!rst_ni)
    begin
        pend_q <= NONE;
        none_q <= 1'b0;
    end
    else
    begin
        if(req_i && gnt_o)
            pend_q <= sel;
        none_q <= req_i && sel == NONE;
    end
end

assign rvalid_o = pend_q == IMEM ? imem_rvalid_i
                : pend_q == DMEM ? dmem_rvalid_i
                : pend_q == AXI  ? axi_rvalid_i
                : none_q;
assign rdata_o  = pend_q == IMEM ? imem_rdata_i
                : pend_q == DMEM ? dmem_rdata_i
                : pend_q == AXI  ? axi_rdata_i
                : 32'b0;
assign err_o    = pend_q == AXI ? axi_err_i : pend_q == NONE;

endmodule
