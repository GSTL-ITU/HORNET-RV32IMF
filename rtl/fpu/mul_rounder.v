
module mul_rounder(input wire[2:0] LRS,
                 input wire[2:0] rounding_mode,
                 input wire      sign_O,
                output reg       round_out);
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
           casez(LRS[1:0])
           2'b0?: round_out = 1'b0; 
           2'b10: round_out = LRS[1] & (LRS[2] | LRS[0]);       
           2'b11: round_out = 1'b1;
           endcase
           end
    3'b001:round_out = 1'b0;
    3'b010:begin
            if(sign_O == 1'b0)
                round_out = 1'b0; 
            else
                if(|LRS[1:0]) round_out = 2'b01; //Round only if R or S bit is set
                else round_out = 2'b00;
            end
            
    3'b011:begin
           if(sign_O == 1'b0)
                if(|LRS[1:0]) round_out = 2'b01; //Round only if R or S bit is set
                else round_out = 2'b00;
           else
                round_out = 1'b0;
            end
    3'b100:begin
           case(LRS[1:0]) //Seems wrong idk
               2'b00: round_out = 2'b00;
               2'b01: round_out = 2'b00;
               2'b10, 2'b11: round_out = 2'b01; //Round away from 0, increase magnitude
           endcase
           end 
    default: round_out = 1'b0;       
    endcase
end

endmodule                 