`define maxExp 8'd255
module fpu_mul
(   input        clk,
    input        reset,
    input [8:0]  preNorm_exp,
    input        is_exp_underFlow,
    input [23:0] sig_A,
    input [23:0] sig_B,
   output [25:0] mul_proNorm_sig,
   output [7:0]  mul_proNorm_exp,
   output        OF_from_proNorm,
   output        UF_from_proNorm
);

wire [47:0] mul_out_sig;

wire [2:0] lrsMul;
assign lrsMul  = {mul_out_sig[23:22], |mul_out_sig[21:0]};



multiplier_24 multiplier_24(.clk(clk), .reset(reset), .M_inA(sig_A), .M_inB(sig_B), .P(mul_out_sig));
mulNormalizer mulNormalizer(.inSig(mul_out_sig), .inExp(preNorm_exp), .is_exp_underFlow(is_exp_underFlow), .lrs(lrsMul), .outExp(mul_proNorm_exp), .outSig(mul_proNorm_sig), .of(OF_from_proNorm), .uf(UF_from_proNorm));







endmodule





















module mulNormalizer(input wire[47:0]  inSig,
                  input wire[8:0]   inExp,
                  input wire        is_exp_underFlow,
                  input wire[2:0]   lrs,
                 output wire[25:0]  outSig,
                 output wire[7:0]   outExp,
                 output wire        of,
                 output reg         uf
                  );

wire[4:0] zeroCount;
reg [1:0] RS;
reg [8:0] ExpTemp;
reg[46:0] SigTemp;

wire      overflow;

assign overflow = (inSig[47] == 1'b1 & inExp + 1 == `maxExp) | ((inExp[8] | &inExp[7:0]) & !is_exp_underFlow);
assign of = overflow;
assign outExp = ExpTemp[7:0];
lzc27 lcz(.x(inSig[46:20]), .z(zeroCount));
 
reg [7:0] shift_amount;
reg sticky;

always @(*)
begin
    if(!is_exp_underFlow)
    begin
        if       (inSig[47])
            RS = {lrs[2],|lrs[1:0]};
        else if  (inSig[46])
            RS = {lrs[1:0]};
        else
            RS = {SigTemp[22], |SigTemp[21:0] | sticky};
    end
    else
            RS = {SigTemp[22], |SigTemp[21:0] | sticky};

end    

wire[7:0] inExp_2C = ~inExp + 1;

assign outSig = overflow ? 27'd0 : {SigTemp[46:23], RS};
        
always @(*)// normalization
begin
    if (!is_exp_underFlow)
    begin
        if (inSig[47] == 1'b1) // if mantissa carry is 1 
        begin
            ExpTemp = inExp + 1;
            SigTemp = inSig >> 1;
            sticky = inSig[0]; 
            uf = 1'b0;
        end
        else if (inSig[46] == 1'b1)
        begin
            ExpTemp = inExp;
            SigTemp = inSig;
            sticky = SigTemp[0]; 
            uf = 1'b0;     
        end
        else if (inExp == 1 | inExp <= zeroCount)
        begin
            
            ExpTemp = 8'b0;
            SigTemp = inSig << inExp - 1;
            sticky = SigTemp[0];
            uf = 1'b1;
            
        end
        else
        begin
            ExpTemp = inExp - zeroCount;
            SigTemp = inSig << zeroCount;
            sticky = SigTemp[0]; 
            uf = 1'b1;
        end  
    end
    else
    begin
        
        //SigTemp = inSig >> inExp_2C + 1 ;
        shift_amount = inExp_2C + 1; 
        // Handle cases where shift_amount exceeds input width
            if (shift_amount > 47) begin
                SigTemp = 47'b0;
                sticky = |inSig;  // All bits shifted out
            end
            else begin
                SigTemp = inSig >> shift_amount;
                // Capture OR of bits shifted out (LSBs of original)
                sticky = |(inSig & ((1 << shift_amount) - 1));
            end
        
        if(SigTemp[46])
            ExpTemp = 1;
        else
            ExpTemp = 0;
        uf = 1'b1;
    end
    

end

endmodule