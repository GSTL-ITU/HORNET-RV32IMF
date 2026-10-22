module fpu_cvt_to_int
(
    input         is_unsigned,
    input         is_exp_neg,
    input [2:0]   rounding_mode,
    input         isNaNA,
    input         isInfA,
    input         isZeroA,
    input         sign_A,
    input [7:0]   exp_A,
    input [23:0]  sig_A,

    output [31:0] cvt_to_int_out,
    output        overflow

);

wire signed [7:0] actual_exp;
assign actual_exp = exp_A - 127;

wire signed [54:0]  adjusted_sig;
assign adjusted_sig = {sig_A, 31'b0};
wire is_overflow;
wire[54:0] int_before_round;
wire[31:0] int_after_round;
wire[31:0] final_out;
assign is_overflow = is_unsigned ? actual_exp > 31 : actual_exp >= 31;
assign overflow = is_overflow;

wire [3:0] lgrs;
wire round_out, round_out_temp;
assign int_before_round = (adjusted_sig >> (31-actual_exp)) ;
assign lgrs = {int_before_round[23:21], |int_before_round[20:0]};
cvrt_rounder cvrt_rounder_to_int(lgrs, rounding_mode, sign_A, round_out);

assign int_after_round = int_before_round[54:23] + round_out;
assign final_out = is_unsigned ? (sign_A ? 32'h0 : int_after_round) : (sign_A ? ~int_after_round + 1 : int_after_round);

reg [31:0] exp_neg_out;
always @(*) begin //Edge cases involving various outcomes due to is_exp_neg around 0, with various rounding modes (TENTATIVE)
    if(final_out == 32'h0)begin
        if(rounding_mode == 3'b001) exp_neg_out = 32'h0; //RTZ
        else if(rounding_mode == 3'b010) begin //RDN
            if(sign_A && !is_unsigned) exp_neg_out = 32'hFFFFFFFF; //For negative values, round down to -1, but only if conversion is signed
            else exp_neg_out = 32'h0; //Else 0
        end
        else if(rounding_mode == 3'b011) begin//RUP
            if(sign_A) exp_neg_out = 32'h0; //For negative values, round up to 0
            else exp_neg_out = 32'h00000001; //For positive values, round up to 1
        end
        else exp_neg_out = 32'h0; //Match final_out
    end
    else exp_neg_out = final_out;
end

assign cvt_to_int_out =  isNaNA ? (is_unsigned ? 32'hFFFF_FFFF : 32'h7FFF_FFFF)   :
                         isInfA ? (is_unsigned ? (sign_A ? 32'h0 : 32'hFFFF_FFFF) : (sign_A ? 32'h8000_0000  : 32'h7FFF_FFFF)) :
                         isZeroA ? 32'h0 :
                         is_exp_neg ? (exp_neg_out) : // This is changed since if the number is between -1.0 and 1.0 it goes to 0 but this is not the case for everytime.
                         is_overflow ? (is_unsigned ? (sign_A ? 32'h0 : 32'hFFFF_FFFF) : (sign_A ? 32'h8000_0000 : 32'h7FFF_FFFF)): final_out;
// This change might cause other problems but it reduced total error count
/*
assign cvt_to_int_out =  isNaNA ? (is_unsigned ? 32'hFFFF_FFFF : 32'h7FFF_FFFF)   :
                         isInfA ? (is_unsigned ? (sign_A ? 32'h0 : 32'hFFFF_FFFF) : (sign_A ? 32'h8000_0000  : 32'h7FFF_FFFF)) :
                         is_exp_neg ? (32'h0) : 
                         is_overflow ? (is_unsigned ? (sign_A ? 32'h0 : 32'hFFFF_FFFF) : (sign_A ? 32'h8000_0000 : 32'h7FFF_FFFF)): final_out;
*/
endmodule



module cvrt_rounder
(
    input wire[3:0] LGRS,
    input wire[2:0] rounding_mode,
    input wire      sign_O,
    output reg      round_out
);
// 000 RNE Round to Nearest, ties to Even
// 001 RTZ Round towards Zero
// 010 RDN Round Down (towards -?)
// 011 RUP Round Up (towards +?)
// 100 RMM Round to Nearest, ties to Max Magnitude
// 101 Invalid. Reserved for future use.
// 110 Invalid. Reserved for future use.
// 111 DYN In instruction's rm field, selects dynamic rounding mode;
// In Rounding Mode register, Invalid
// rounding bit assignment
always @(*)
begin
    case(rounding_mode)
    3'b000:begin
           casez(LGRS[2:0])
           3'b0??: round_out = 1'b0;
           3'b100: begin
                if(LGRS[3])
                    round_out = 1'b1;
                else
                    round_out = 1'b0;
           end
           default: round_out = 1'b1;

           endcase
           end
    3'b001:round_out = 1'b0;
    3'b010:begin
            if(sign_O == 1'b0)
                round_out = 1'b0; 
            else begin
                if(|LGRS[2:0]) round_out = 1'b1;
                else round_out = 1'b0;
            end
        end
            
    3'b011:begin
           if(sign_O == 1'b0) begin
                if(|LGRS[2:0]) round_out = 1'b1;
                else round_out = 1'b0;
           end
           else
                round_out = 1'b0;
        end
    3'b100:begin
           casez(LGRS[2:0])
               3'b0??: round_out = 1'b0;
               default: round_out = 1'b1;
           endcase
           
           end 
    default: round_out = 1'b0;       
    endcase
end

endmodule                 