// Instruction memory: true dual-port block RAM
// Port A: instruction fetch (read only). Port B: data port (loads, stores, loader).
// Both ports always grant and answer one cycle later; out-of-range fetches answer with an error.
module imem #(parameter SIZE = 65536,  //bytes
              parameter INIT = "")
(input             clk_i,
 input             rst_ni,

 input             a_req_i,
 output            a_gnt_o,
 input      [31:0] a_addr_i,
 output reg        a_rvalid_o,
 output reg [31:0] a_rdata_o,
 output reg        a_err_o,

 input             b_req_i,
 output            b_gnt_o,
 input             b_we_i,
 input      [3:0]  b_be_i,
 input      [31:0] b_addr_i,
 input      [31:0] b_wdata_i,
 output reg        b_rvalid_o,
 output reg [31:0] b_rdata_o);

localparam WORDS = SIZE / 4;
localparam AW = $clog2(WORDS);

reg [31:0] mem [0:WORDS-1];

initial
    if(INIT != "")
        $readmemh(INIT, mem);

assign a_gnt_o = 1'b1;
assign b_gnt_o = 1'b1;

wire [AW-1:0] a_word = a_addr_i[AW+1:2];
wire [AW-1:0] b_word = b_addr_i[AW+1:2];
wire          a_in   = a_addr_i < SIZE;

always @(posedge clk_i)
    if(a_req_i)
        a_rdata_o <= mem[a_word];

always @(posedge clk_i)
    if(b_req_i)
    begin
        if(b_we_i && b_be_i[0]) mem[b_word][7:0]   <= b_wdata_i[7:0];
        if(b_we_i && b_be_i[1]) mem[b_word][15:8]  <= b_wdata_i[15:8];
        if(b_we_i && b_be_i[2]) mem[b_word][23:16] <= b_wdata_i[23:16];
        if(b_we_i && b_be_i[3]) mem[b_word][31:24] <= b_wdata_i[31:24];
        b_rdata_o <= mem[b_word];
    end

always @(posedge clk_i or negedge rst_ni)
begin
    if(!rst_ni)
    begin
        a_rvalid_o <= 1'b0;
        a_err_o <= 1'b0;
        b_rvalid_o <= 1'b0;
    end
    else
    begin
        a_rvalid_o <= a_req_i;
        a_err_o <= a_req_i && !a_in;
        b_rvalid_o <= b_req_i;
    end
end

endmodule
