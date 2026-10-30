// Integer (x1-x31) and float (f0-f31) register files, one shared write port
// RV_F = 0: no float register file, float reads return zero
module regfile #(parameter RV_F = 1)
              (input         clk_i,

               input  [4:0]  rs1_i, rs2_i, rs3_i,
               input         rs1_fp_i, rs2_fp_i,
               output [31:0] rs1_data_o, rs2_data_o, rs3_data_o, //rs3 is always a float register

               input         we_i,
               input         rd_fp_i,
               input  [4:0]  rd_i,
               input  [31:0] rd_data_i);

reg [31:0] x_bank [31:1];

integer i;
initial
    for(i = 1; i < 32; i = i + 1)
        x_bank[i] = 32'b0;

always @(posedge clk_i)
    if(we_i && !rd_fp_i && rd_i != 5'd0)
        x_bank[rd_i] <= rd_data_i;

wire wr_x = we_i && !rd_fp_i && rd_i != 5'd0;
wire wr_f = we_i && rd_fp_i;

//float reads, with the same-cycle bypass
wire [31:0] f_rs1, f_rs2, f_rs3;
generate
if(RV_F != 0)
begin : F_BANK
    reg [31:0] f_bank [31:0];

    integer j;
    initial
        for(j = 0; j < 32; j = j + 1)
            f_bank[j] = 32'b0;

    always @(posedge clk_i)
        if(wr_f)
            f_bank[rd_i] <= rd_data_i;

    assign f_rs1 = wr_f && rd_i == rs1_i ? rd_data_i : f_bank[rs1_i];
    assign f_rs2 = wr_f && rd_i == rs2_i ? rd_data_i : f_bank[rs2_i];
    assign f_rs3 = wr_f && rd_i == rs3_i ? rd_data_i : f_bank[rs3_i];
end
else
begin : NO_F_BANK
    assign f_rs1 = 32'b0;
    assign f_rs2 = 32'b0;
    assign f_rs3 = 32'b0;
end
endgenerate

//a write is visible to a read in the same cycle
assign rs1_data_o = rs1_fp_i ? f_rs1
                  : rs1_i == 5'd0 ? 32'b0
                  : (wr_x && rd_i == rs1_i ? rd_data_i : x_bank[rs1_i]);

assign rs2_data_o = rs2_fp_i ? f_rs2
                  : rs2_i == 5'd0 ? 32'b0
                  : (wr_x && rd_i == rs2_i ? rd_data_i : x_bank[rs2_i]);

assign rs3_data_o = f_rs3;

endmodule
