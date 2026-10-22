
module sqrt_rounder(input wire[2:0] LGRS,
                    input wire[2:0] rounding_mode,
                    input wire      sign_O,
                    output reg      round_out);
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
           casez(LGRS)
           3'b0??: round_out = 1'b0;
           3'b1??: round_out = 1'b1;
           default: round_out = 1'b0;

           endcase
           end
    3'b001:round_out = 1'b0;
    3'b010:begin
            if(sign_O == 1'b0)
                round_out = 1'b0; 
            else
                if(|LGRS[2:0]) round_out = 2'b01; //Round only if G or R or S bit is set
                else round_out = 2'b00;
            end
            
    3'b011:begin
           if(sign_O == 1'b0)
                if(|LGRS[2:0]) round_out = 2'b01; //Round only if G or R or S bit is set
                else round_out = 2'b00;
           else
                round_out = 1'b0;
            end
    3'b100:begin
           casez(LGRS)
               3'b0??: round_out = 1'b0;
               default: round_out = 1'b1;
           endcase
           
           end 
    default: round_out = 1'b0;       
    endcase
end

endmodule                 