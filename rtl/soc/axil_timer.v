// Machine timer and software interrupt, CLINT register layout
//   0x0000 msip   0x4000 mtimecmp   0x4004 mtimecmph   0xBFF8 mtime   0xBFFC mtimeh
module axil_timer
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

 output reg        msip_o,
 output reg        mtip_o,
 output     [63:0] mtime_o);

reg [63:0] mtime, mtimecmp;
assign mtime_o = mtime;

wire wr = s_awvalid && s_wvalid && !s_bvalid;
assign s_awready = wr;
assign s_wready  = wr;
assign s_arready = !s_rvalid;

function [31:0] merge;
    input [31:0] old, data;
    input [3:0]  strb;
    integer b;
    begin
        for(b = 0; b < 4; b = b + 1)
            merge[8*b +: 8] = strb[b] ? data[8*b +: 8] : old[8*b +: 8];
    end
endfunction

wire [15:0] woff = s_awaddr[15:0];
wire [15:0] roff = s_araddr[15:0];

always @(posedge clk_i or negedge rst_ni)
begin
    if(!rst_ni)
    begin
        mtime <= 64'b0;
        mtimecmp <= {64{1'b1}};
        msip_o <= 1'b0;
        mtip_o <= 1'b0;
        s_bvalid <= 1'b0;
        s_bresp <= 2'b00;
        s_rvalid <= 1'b0;
        s_rresp <= 2'b00;
        s_rdata <= 32'b0;
    end
    else
    begin
        mtime <= mtime + 64'd1;
        mtip_o <= mtime >= mtimecmp;

        if(s_bvalid && s_bready)
            s_bvalid <= 1'b0;
        if(wr)
        begin
            s_bvalid <= 1'b1;
            s_bresp <= 2'b00;
            case(woff)
                16'h0000: if(s_wstrb[0]) msip_o <= s_wdata[0];
                16'h4000: mtimecmp[31:0]  <= merge(mtimecmp[31:0], s_wdata, s_wstrb);
                16'h4004: mtimecmp[63:32] <= merge(mtimecmp[63:32], s_wdata, s_wstrb);
                16'hBFF8: mtime[31:0]     <= merge(mtime[31:0], s_wdata, s_wstrb);
                16'hBFFC: mtime[63:32]    <= merge(mtime[63:32], s_wdata, s_wstrb);
                default:  s_bresp <= 2'b10;
            endcase
        end

        if(s_rvalid && s_rready)
            s_rvalid <= 1'b0;
        if(s_arvalid && !s_rvalid)
        begin
            s_rvalid <= 1'b1;
            s_rresp <= 2'b00;
            case(roff)
                16'h0000: s_rdata <= {31'b0, msip_o};
                16'h4000: s_rdata <= mtimecmp[31:0];
                16'h4004: s_rdata <= mtimecmp[63:32];
                16'hBFF8: s_rdata <= mtime[31:0];
                16'hBFFC: s_rdata <= mtime[63:32];
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
