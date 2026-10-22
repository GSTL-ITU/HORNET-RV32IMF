// Integer (x1-x31) and float (f0-f31) register files, one shared write port
module regfile(input         clk_i,

               input  [4:0]  rs1_i, rs2_i, rs3_i,
               input         rs1_fp_i, rs2_fp_i,
               output [31:0] rs1_data_o, rs2_data_o, rs3_data_o, //rs3 is always a float register

               input         we_i,
               input         rd_fp_i,
               input  [4:0]  rd_i,
               input  [31:0] rd_data_i);

reg [31:0] x_bank [31:1];
reg [31:0] f_bank [31:0];

integer i;
initial
begin
    for(i = 1; i < 32; i = i + 1)
        x_bank[i] = 32'b0;
    for(i = 0; i < 32; i = i + 1)
        f_bank[i] = 32'b0;
end

always @(posedge clk_i)
begin
    if(we_i && rd_fp_i)
        f_bank[rd_i] <= rd_data_i;
    else if(we_i && rd_i != 5'd0)
        x_bank[rd_i] <= rd_data_i;
end

wire wr_x = we_i && !rd_fp_i && rd_i != 5'd0;
wire wr_f = we_i && rd_fp_i;

//a write is visible to a read in the same cycle
assign rs1_data_o = rs1_fp_i ? (wr_f && rd_i == rs1_i ? rd_data_i : f_bank[rs1_i])
                  : rs1_i == 5'd0 ? 32'b0
                  : (wr_x && rd_i == rs1_i ? rd_data_i : x_bank[rs1_i]);

assign rs2_data_o = rs2_fp_i ? (wr_f && rd_i == rs2_i ? rd_data_i : f_bank[rs2_i])
                  : rs2_i == 5'd0 ? 32'b0
                  : (wr_x && rd_i == rs2_i ? rd_data_i : x_bank[rs2_i]);

assign rs3_data_o = wr_f && rd_i == rs3_i ? rd_data_i : f_bank[rs3_i];

endmodule
