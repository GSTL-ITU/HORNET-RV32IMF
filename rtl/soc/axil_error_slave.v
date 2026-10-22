// AXI4-Lite slave that answers every access with DECERR (for an unused external port)
module axil_error_slave
(input         clk_i,
 input         rst_ni,
 input         s_awvalid,
 output        s_awready,
 input         s_wvalid,
 output        s_wready,
 output [1:0]  s_bresp,
 output reg    s_bvalid,
 input         s_bready,
 input         s_arvalid,
 output        s_arready,
 output [31:0] s_rdata,
 output [1:0]  s_rresp,
 output reg    s_rvalid,
 input         s_rready);

assign s_awready = s_awvalid && s_wvalid && !s_bvalid;
assign s_wready  = s_awready;
assign s_arready = !s_rvalid;
assign s_bresp   = 2'b11;
assign s_rresp   = 2'b11;
assign s_rdata   = 32'b0;

always @(posedge clk_i or negedge rst_ni)
begin
    if(!rst_ni)
    begin
        s_bvalid <= 1'b0;
        s_rvalid <= 1'b0;
    end
    else
    begin
        if(s_awready)
            s_bvalid <= 1'b1;
        else if(s_bready)
            s_bvalid <= 1'b0;
        if(s_arvalid && s_arready)
            s_rvalid <= 1'b1;
        else if(s_rready)
            s_rvalid <= 1'b0;
    end
end

endmodule
