// Synchronous FIFO, DEPTH a power of two
module sync_fifo #(parameter WIDTH = 8,
                   parameter DEPTH = 16)
(input              clk_i,
 input              rst_ni,
 input              push_i,
 input  [WIDTH-1:0] data_i,
 input              pop_i,
 output [WIDTH-1:0] data_o,
 output             empty_o,
 output             full_o);

localparam AW = $clog2(DEPTH);

reg [WIDTH-1:0] mem [0:DEPTH-1];
reg [AW:0]      wp, rp;

assign empty_o = wp == rp;
assign full_o  = wp == {~rp[AW], rp[AW-1:0]};
assign data_o  = mem[rp[AW-1:0]];

always @(posedge clk_i)
    if(push_i && !full_o)
        mem[wp[AW-1:0]] <= data_i;

always @(posedge clk_i or negedge rst_ni)
begin
    if(!rst_ni)
    begin
        wp <= {(AW+1){1'b0}};
        rp <= {(AW+1){1'b0}};
    end
    else
    begin
        if(push_i && !full_o)
            wp <= wp + 1'b1;
        if(pop_i && !empty_o)
            rp <= rp + 1'b1;
    end
end

endmodule
