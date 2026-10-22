module fpu_add_sub_rounder
(
    input wire[2:0] LRS,
    input wire[2:0] rounding_mode,
    input wire      second_operand_zero, sign_less, //Using sign_less generalizes addition and subtraction of positive/negative values
    input wire      sign_O,
    output reg[1:0] round_out
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

//By setting second bit of round_out to 1, we can subtract 1 from the result instead
always @(*)
begin
    case(rounding_mode)
    3'b000:begin
           casez(LRS[1:0])
           2'b0?: round_out = 2'b0; 
           2'b10: round_out = {1'b0,LRS[1] & (LRS[2] | LRS[0])};       
           2'b11: round_out = 2'b1;
           endcase
           end
    3'b001:begin
            if(second_operand_zero) begin
                if(sign_less == 1'b0 && sign_O == 1'b1) round_out = 2'b11; //In addition, adding a very small amount to a negative number will round it up if mode is RTZ
                else if(sign_less == 1'b1 && sign_O == 1'b0) round_out = 2'b11; //In subtraction, subtracting a very small amount from a positive number will round it down if mode is RTZ
                else round_out = 2'b00;
            end
            else round_out = 2'b00;
        end

    3'b010:begin
            if(sign_O == 1'b0) //For positive numbers
                if(sign_less == 1'b1 && second_operand_zero) round_out = 2'b11;//If we subtract a very small amount from a positive number, RDN will pull it down (so magnitude decreases)
                else round_out = 2'b0; 
            else begin
                if(sign_less == 1'b1 && second_operand_zero) round_out = 2'b01; //If we subtract a very small amount from a negative number, RDN will pull it down (so magnitude increases)
                else if(|LRS[1:0]) round_out = 2'b01; //Round only if R or S bit is set
                else round_out = 2'b00;
            end
        end
            
    3'b011:begin
           if(sign_O == 1'b0) begin//For positive numbers
                if(sign_less == 1'b0 && second_operand_zero) round_out = 2'b01; //If we add a very small amount to a positive number, RUP will pull it up (so magnitude increases)
                else if(|LRS[1:0]) round_out = 2'b01; //Round only if R or S bit is set
                else round_out = 2'b00; 
           end
           else begin
                if(sign_less == 1'b0 && second_operand_zero) round_out = 2'b11; //If we add a very small amount to a negative number, RUP will pull it up (so magnitude decreases)
                else round_out = 2'b00;
           end
        end
    3'b100:begin
           case(LRS[1:0]) //Seems wrong idk
               2'b00: round_out = 2'b00;
               2'b01: round_out = 2'b00;
               2'b10, 2'b11: round_out = 2'b01; //Round away from 0, increase magnitude
           endcase
           end 
    default: round_out = 2'b0;
    endcase
end

endmodule                 