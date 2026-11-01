// GPIO: 32 outputs with direction, 32 synchronised inputs, edge interrupts
//   0x00 OUT   0x04 IN   0x08 DIR (1 = output)   0x0C IE   0x10 IP (write 1 to clear)   0x14 EDGE (1 = falling)
module axil_gpio
(input             clk_i,
 input             rst_ni,

 input      [31:0] s_awaddr,
 input             s_awvalid,
 output            s_awready,
 input      [31:0] s_wdata,
 input      [3:0]  s_wstrb,
 input             s_wvalid,
 output            s_wready,
 output reg [1:0]  s_bresp,
 output reg        s_bvalid,
 input             s_bready,
 input      [31:0] s_araddr,
 input             s_arvalid,
 output            s_arready,
 output reg [31:0] s_rdata,
 output reg [1:0]  s_rresp,
 output reg        s_rvalid,
 input             s_rready,

 input      [31:0] gpio_i,
 output reg [31:0] gpio_o,
 output reg [31:0] gpio_oe_o,
 output            irq_o);

reg [31:0] in_meta, in_q, in_prev, ie, ip, edge_sel;

wire wr = s_awvalid && s_wvalid && !s_bvalid;
assign s_awready = wr;
assign s_wready  = wr;
assign s_arready = !s_rvalid;
assign irq_o = |(ip & ie);

function [31:0] merge;
    input [31:0] old, data;
    input [3:0]  strb;
    integer b;
    begin
        for(b = 0; b < 4; b = b + 1)
            merge[8*b +: 8] = strb[b] ? data[8*b +: 8] : old[8*b +: 8];
    end
endfunction

wire [31:0] rise = in_q & ~in_prev;
wire [31:0] fall = ~in_q & in_prev;
wire [31:0] hit  = (rise & ~edge_sel) | (fall & edge_sel);

always @(posedge clk_i or negedge rst_ni)
begin
    if(!rst_ni)
    begin
        {in_meta, in_q, in_prev} <= 96'b0;
        gpio_o <= 32'b0;
        gpio_oe_o <= 32'b0;
        {ie, ip, edge_sel} <= 96'b0;
        s_bvalid <= 1'b0;
        s_bresp <= 2'b00;
        s_rvalid <= 1'b0;
        s_rresp <= 2'b00;
        s_rdata <= 32'b0;
    end
    else
    begin
        in_meta <= gpio_i;
        in_q <= in_meta;
        in_prev <= in_q;
        ip <= ip | hit;

        if(s_bvalid && s_bready)
            s_bvalid <= 1'b0;
        if(wr)
        begin
            s_bvalid <= 1'b1;
            s_bresp <= 2'b00;
            case(s_awaddr[7:0])
                8'h00: gpio_o <= merge(gpio_o, s_wdata, s_wstrb);
                8'h08: gpio_oe_o <= merge(gpio_oe_o, s_wdata, s_wstrb);
                8'h0C: ie <= merge(ie, s_wdata, s_wstrb);
                8'h10: ip <= (ip | hit) & ~merge(32'b0, s_wdata, s_wstrb);
                8'h14: edge_sel <= merge(edge_sel, s_wdata, s_wstrb);
                default: s_bresp <= 2'b10;
            endcase
        end

        if(s_rvalid && s_rready)
            s_rvalid <= 1'b0;
        if(s_arvalid && !s_rvalid)
        begin
            s_rvalid <= 1'b1;
            s_rresp <= 2'b00;
            case(s_araddr[7:0])
                8'h00: s_rdata <= gpio_o;
                8'h04: s_rdata <= in_q;
                8'h08: s_rdata <= gpio_oe_o;
                8'h0C: s_rdata <= ie;
                8'h10: s_rdata <= ip;
                8'h14: s_rdata <= edge_sel;
                default:
                begin
                    s_rdata <= 32'b0;
                    s_rresp <= 2'b10;
                end
            endcase
        end
    end
end

endmodule
