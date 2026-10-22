`define maxExp 8'd255
module mds_final_normalizer
(
    input [24:0] sig_after_round,
    input        of_from_pro_norm,
    input [7:0]  proNorm_exp,
    input [1:0]  mds_op,
   output [7:0]  final_exp,
   output [22:0] final_sig,
   output        of_final_norm
);

wire of_fin_norm;
assign of_fin_norm      = (sig_after_round[24] && proNorm_exp + 1 == `maxExp) || of_from_pro_norm;


assign final_exp = of_fin_norm ? 8'd255 : ( sig_after_round[24] ? proNorm_exp + 1 : proNorm_exp);
assign final_sig = of_fin_norm ? 23'd0 :  ( (mds_op == 8'b01 && proNorm_exp == 8'd0 && sig_after_round[23]) ? sig_after_round[23:1] : ( sig_after_round[24] ? sig_after_round[23:1]   : sig_after_round[22:0] ));
assign of_final_norm = of_fin_norm;



endmodule