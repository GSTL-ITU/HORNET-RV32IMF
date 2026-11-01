// Data memory: single-port block RAM with byte enables
// Always grants and answers one cycle later.
module dmem #(parameter SIZE = 65536, //bytes
              parameter INIT = "")
(input             clk_i,
 input             rst_ni,
 input             req_i,
 output            gnt_o,
 input             we_i,
 input      [3:0]  be_i,
 input      [31:0] addr_i,
 input      [31:0] wdata_i,
 output reg        rvalid_o,
 output reg [31:0] rdata_o);

localparam WORDS = SIZE / 4;
localparam AW = $clog2(WORDS);

reg [31:0] mem [0:WORDS-1];

initial
    if(INIT != "")
        $readmemh(INIT, mem);

assign gnt_o = 1'b1;

wire [AW-1:0] word = addr_i[AW+1:2];

always @(posedge clk_i)
    if(req_i)
    begin
        if(we_i && be_i[0]) mem[word][7:0]   <= wdata_i[7:0];
        if(we_i && be_i[1]) mem[word][15:8]  <= wdata_i[15:8];
        if(we_i && be_i[2]) mem[word][23:16] <= wdata_i[23:16];
        if(we_i && be_i[3]) mem[word][31:24] <= wdata_i[31:24];
        rdata_o <= mem[word];
    end

always @(posedge clk_i or negedge rst_ni)
    if(!rst_ni)
        rvalid_o <= 1'b0;
    else
        rvalid_o <= req_i;

endmodule
