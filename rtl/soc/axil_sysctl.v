// System control: program exit code (watched by the testbench), clock frequency, ID, scratch
//   0x00 EXIT   0x04 CLK_FREQ (read only)   0x08 ID "HRNT" (read only)   0x0C SCRATCH
module axil_sysctl #(parameter CLK_FREQ = 50000000)
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

 output reg        exit_o,      //one cycle when EXIT is written
 output reg [31:0] exit_code_o);

reg [31:0] scratch;

wire wr = s_awvalid && s_wvalid && !s_bvalid;
assign s_awready = wr;
assign s_wready  = wr;
assign s_arready = !s_rvalid;

always @(posedge clk_i or negedge rst_ni)
begin
    if(!rst_ni)
    begin
        exit_o <= 1'b0;
        exit_code_o <= 32'b0;
        scratch <= 32'b0;
        s_bvalid <= 1'b0;
        s_bresp <= 2'b00;
        s_rvalid <= 1'b0;
        s_rresp <= 2'b00;
        s_rdata <= 32'b0;
    end
    else
    begin
        exit_o <= 1'b0;
        if(s_bvalid && s_bready)
            s_bvalid <= 1'b0;
        if(wr)
        begin
            s_bvalid <= 1'b1;
            s_bresp <= 2'b00;
            case(s_awaddr[3:0])
                4'h0:
                begin
                    exit_o <= 1'b1;
                    exit_code_o <= s_wdata;
                end
                4'hC: scratch <= s_wdata;
                default: s_bresp <= 2'b10;
            endcase
        end

        if(s_rvalid && s_rready)
            s_rvalid <= 1'b0;
        if(s_arvalid && !s_rvalid)
        begin
            s_rvalid <= 1'b1;
            s_rresp <= 2'b00;
            case(s_araddr[3:0])
                4'h0: s_rdata <= exit_code_o;
                4'h4: s_rdata <= CLK_FREQ;
                4'h8: s_rdata <= 32'h4852_4E54;
                4'hC: s_rdata <= scratch;
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
