`timescale 1ns / 1ps
`define maxExp 8'd255

`define RNE 3'b000 // Round to Nearest, ties to Even
`define RTZ 3'b001 // Round towards Zero
`define RDN 3'b010 // Round Down (towards -?)
`define RUP 3'b011 // Round Up (towards +?)
`define RMM 3'b100 // Round to Nearest, ties to Max Magnitude
module fpu_add_sub
(         
    input wire       sign_A,
    input wire       sign_B,
    input wire [7:0] exp_A,
    input wire [7:0] exp_B,
    input wire[23:0] sig_A,
    input wire[23:0] sig_B,
    input wire       isZeroA, isZeroB,
    input wire       isInfA, isInfB,
    input wire       isNaNA, isNaNB,
    input wire       isSignaling,
    input wire       sub_op,
    input wire [2:0] rounding_mode,
    output wire       overflow,
    output wire       underflow,
    output wire       invalid,
    output wire       inexact,
    output wire[31:0] OUT
);

// Exp = 1111_1111 & Significand != 0  -> qNaN or sNaN
// Exp = 1111_1111 & Significand == 0  -> signed infinity 
// 1 <= Exp <= 1111_1110               -> normal number (has a implicit 1)
// Exp = 0000_0000 & Significand != 0  -> subnormal number(has a implicit 0)
// Exp = 0000_0000 & Significand == 0  -> signed zero 


wire        is_exp_equal;
wire        is_exp_A_Big;
wire [27:0] big_sig;
wire [27:0] less_sig;
wire [47:0] less_sig_shifted;
wire [27:0] less_adjusted;
wire [27:0] big_sig_2C;
wire [27:0] less_adjusted_2C;
wire        sign_big;
wire        sign_less;
wire  [3:0] LGRS;
wire  [2:0] LRS;
reg  [27:0] first_operand;
reg  [27:0] second_operand;
wire  [7:0] pro_normal_exp;
wire [26:0] pro_normal_sig;
wire [1:0]  round_out;



wire [24:0] final_sum;
wire  [7:0] final_exp;
wire [22:0] final_sig;


wire        eff_sign_B;


wire        sign_O;
reg  [7:0]  exp_A_adjusted;
reg  [7:0]  exp_B_adjusted;
wire [7:0]  exp_O;
wire [24:0] sig_A_adjusted, sig_B_adjusted;
wire [27:0] out_sig;

wire [27:0] out_sig_abs;
reg  [7:0]  exp_diff;

assign LGRS              = out_sig_abs[3:0];
assign LRS               = pro_normal_sig[2:0];
assign eff_sign_B        = sub_op ? !sign_B : sign_B;

assign sig_A_adjusted     = {1'b0, sig_A};
assign sig_B_adjusted     = {1'b0, sig_B};

assign sign_big           = !is_exp_equal ? (is_exp_A_Big ? sign_A : eff_sign_B) : sign_A;
assign sign_less          = !is_exp_equal ? (!is_exp_A_Big ? sign_A : eff_sign_B) : eff_sign_B;
assign is_exp_equal       = (exp_A_adjusted == exp_B_adjusted);
assign is_exp_A_Big       = (exp_A_adjusted > exp_B_adjusted);

assign big_sig            = !is_exp_equal ? (is_exp_A_Big ? {sig_A_adjusted,3'b000} : {sig_B_adjusted,3'b000}) : {sig_A_adjusted,3'b000};
assign less_sig           = !is_exp_equal ? (is_exp_A_Big ? sig_B_adjusted : sig_A_adjusted) : sig_B_adjusted;
assign less_sig_shifted   = {less_sig,23'b0} >> exp_diff;
assign less_adjusted      = |less_sig_shifted[20:0] ? {less_sig_shifted[47:21],1'b1} : less_sig_shifted[47:20];

assign big_sig_2C         = ~big_sig + 1;
assign less_adjusted_2C   = ~less_adjusted + 1;
wire of;
wire uf;
wire ofAfterRound;
wire ofFromProNorm;
wire ufFromProNorm;
wire ufAfterRound;
assign of = ofAfterRound | ofFromProNorm;
assign uf = ufAfterRound | ufFromProNorm;

always @(*) // exp and significand assignment
begin

    if(exp_A == 8'd0) // check if number is denormalized(subnormal)
        exp_A_adjusted = 8'b0000_0001;
    else
        exp_A_adjusted = exp_A;

    if(exp_B == 8'd0) 
        exp_B_adjusted = 8'b0000_0001;
    else
        exp_B_adjusted = exp_B;
end


always @(*)
begin
    
    if(!sign_big)
        first_operand = big_sig;
    else
        first_operand = big_sig_2C;
    if(!sign_less)
        second_operand = less_adjusted;
    else
        second_operand = less_adjusted_2C;
end

always @(exp_A_adjusted, exp_B_adjusted) // calculate exp_diff
begin

    if(exp_A_adjusted > exp_B_adjusted)
        exp_diff = exp_A_adjusted - exp_B_adjusted;
    else
        exp_diff = exp_B_adjusted - exp_A_adjusted;
end


//assign inexact   = |LRS[1:0] | of | uf; //Repeated below

//assign final_sum         = round_out[1] ? pro_normal_sig[26:2] - round_out[0] : pro_normal_sig[26:2] + round_out[0];
assign final_sum         = pro_normal_sig[26:2];
assign final_exp         = final_sum[24] ? (of ? `maxExp : pro_normal_exp + 1) : pro_normal_exp;
assign final_sig         = final_sum[24] ? (of ? 23'd0  : final_sum[23:1]) : final_sum[22:0];
assign ofAfterRound      = (final_sum[24] && pro_normal_exp+1 == `maxExp);
assign ufAfterRound      = of ? 1'b0 :  !(|final_sum[24:23])  | (!(|final_exp) & !(|final_sig));


wire isout_sigNeg        = (sign_A && eff_sign_B) || (sign_A && out_sig[27] || (eff_sign_B && out_sig[27]));

reg sign_O_equal;

always @(*) begin //Sign of the output when |A|=|B| according to which operation or rounding mode is used.
    if(sub_op) begin //If subtraction, result is 0 if signs are the same.
        if(!(sign_A ^ sign_B)) begin
            if(rounding_mode == 3'b010) sign_O_equal = 1'b1; //Result is -0.0 if rounding mode is RDN, +0.0 otherwise.
            else sign_O_equal = 1'b0;
        end
        else //Otherwise the result will be a non-zero number, with the sign equal to the sign of A (if A is negative, B is positive, result is thus negative; vice versa)
            sign_O_equal = sign_A;
    end
    else begin//If addition, result is 0 if signs are opposite
        if((sign_A ^ sign_B)) begin
            if(rounding_mode == 3'b010) sign_O_equal = 1'b1; //Result is -0.0 if rounding mode is RDN, +0.0 otherwise.
            else sign_O_equal = 1'b0;
        end
        else //Otherwise the result will be a non-zero number, with the sign equal to the sign of A (if A is negative, B is negative, result is thus negative; vice versa)
            sign_O_equal = sign_A;
    end
end

assign exp_O             = (exp_A_adjusted >= exp_B_adjusted) ? exp_A_adjusted : exp_B_adjusted;
assign out_sig           = first_operand + second_operand;
assign out_sig_abs       = isout_sigNeg  ? ~out_sig+1 : out_sig; 
assign sign_O            = (exp_A_adjusted == exp_B_adjusted) ? (sig_A_adjusted == sig_B_adjusted ? sign_O_equal : 
                           (sig_A_adjusted > sig_B_adjusted ? sign_A : eff_sign_B)) :
                           (exp_A_adjusted >  exp_B_adjusted) ? sign_A : eff_sign_B;  

wire second_operand_zero;

//These can also output 1 if one of the inputs is zero, but that's going to be overwritten by fast output so doesn't matter
assign second_operand_zero = (second_operand == 27'b0);

add_sub_normalizer add_sub_normalizer(.inSig(out_sig_abs), .inExp(exp_O), .LGRS(LGRS), .outExp(pro_normal_exp), .of(ofFromProNorm), .uf(ufFromProNorm), .out_sig(pro_normal_sig));
fpu_add_sub_rounder fpu_add_sub_rounder( .LRS(LRS),
                                         .rounding_mode(rounding_mode),
                                         .second_operand_zero(second_operand_zero),
                                         .sign_less(sign_less), 
                                         .sign_O(sign_O), 
                                         .round_out(round_out));


wire invalid_fast;
wire mux_fastres_sel;
wire [31:0] fast_res;
wire overflow_fast;
fpu_add_fast fpu_add_fast(rounding_mode, isZeroA, isZeroB,isInfA, isInfB, isNaNA, isNaNB, isSignaling, sub_op, sign_A, sign_B, exp_A, exp_B,sig_A[22:0], sig_B[22:0], mux_fastres_sel, fast_res, overflow_fast, invalid_fast);

//Since inexact depends on of and uf, we can also add an inexact output for the fast module, which only consists of overflow_fast:
assign inexact   = mux_fastres_sel ? overflow_fast : |LRS[1:0] | of | uf;
assign invalid   = invalid_fast;
assign overflow  = mux_fastres_sel ? overflow_fast : of;
assign underflow = uf;

reg [31:0] OUT_round;
//Doing the rounding on the final number may help some edge cases?
always @(*) begin
    if(overflow) begin //Overflow edge cases
        if(sign_O) begin //For negative numbers
            if((rounding_mode == 3'b001) || (rounding_mode == 3'b011))
                OUT_round = 32'hff7fffff; //For RTZ or RUP, -Inf rounds down to largest mag. negative number
            else OUT_round = round_out[1] ? {sign_O, final_exp, final_sig} - round_out[0] : {sign_O, final_exp, final_sig} + round_out[0];
        end
        else begin //For positive numbers
            if((rounding_mode == 3'b001) || (rounding_mode == 3'b010))
                OUT_round = 32'h7f7fffff; //For RTZ or RDN, +Inf rounds down to largest mag. positive number
            else OUT_round = round_out[1] ? {sign_O, final_exp, final_sig} - round_out[0] : {sign_O, final_exp, final_sig} + round_out[0];
        end
    end
    else OUT_round = round_out[1] ? {sign_O, final_exp, final_sig} - round_out[0] : {sign_O, final_exp, final_sig} + round_out[0];
end


assign OUT       = mux_fastres_sel ? fast_res : OUT_round;


endmodule


module add_sub_normalizer
(
    input wire[27:0]  inSig,
    input wire[7:0]   inExp,
    input wire[3:0]   LGRS,
    output wire[26:0] out_sig,
    output reg[7:0]   outExp,
    output wire       of,
    output reg        uf
);

wire[4:0] zeroCount;
reg [1:0] RS;

wire overflow;

assign overflow = (inSig[27] == 1'b1 & inExp + 1 == `maxExp) ? 1 : 0;
assign of = overflow;
lzc27 lcz(.x(inSig[26:0]), .z(zeroCount));

always @(*)
begin
    if(inSig[27])
        RS = {LGRS[3], |LGRS[2:0]};
    else if (zeroCount == 4'b0000) 
        RS = {LGRS[2], |LGRS[1:0]};
    else if (zeroCount == 4'b0001)
        RS = LGRS[1:0];
    else 
        RS = 2'b0;
end    


reg[24:0] temp;
assign out_sig = overflow ? 27'd0 : {temp,RS};
        
always @(*)// normalization
begin
    if (inSig[27] == 1'b1) // if mantissa carry is 1 
    begin
        outExp = inExp + 1;
        temp = inSig[27:3] >> 1; 
        uf = 1'b0;
    end
    else if (inSig[26] == 1'b1)
    begin
        outExp = inExp;
        temp = inSig[27:3];
        uf = 1'b0;
    end
    else if (inExp == 1 | inExp <= zeroCount)
    begin
        outExp = 8'b0;
        uf = 1'b1;
        if (inExp == 2)
            temp = inSig[26:2];
        else
            temp = inSig[27:3] << inExp - 1;
    end
    else if (zeroCount == 27) //Tentative fix
    begin
        outExp = 8'b0;
        uf = 1'b0;
        temp = inSig[25:1] << zeroCount - 2;
    end
    else 
    begin
        outExp = inExp - zeroCount;
        if (zeroCount  == 4'b1)
            temp = inSig[26:2] << zeroCount - 1;
        else
            temp = inSig[25:1] << zeroCount - 2;
        uf = 1'b0;
    end
    

end

endmodule

module lzc4(input wire[3:0] x,
           output wire      a,
           output wire[1:0] z
           );
assign a = !(|x);
wire[1:0] temp;
assign temp[1] = ~(x[3] | x[2]);
assign temp[0] = ~x[3] & (x[2] | ~x[1]);
assign z = a ? 2'b00 : temp;

endmodule




module lzc8(input wire[7:0] x,
           output wire      a,
           output wire[2:0] z
           );

wire      a0, a1;
wire[1:0] z0, z1;
reg [1:0] temp;
lzc4 UUT1(.x(x[7:4]), .a(a0), .z(z0));
lzc4 UUT2(.x(x[3:0]), .a(a1), .z(z1));

assign a = a0 & a1;
assign z[2] = a0 & ~a1;
assign z[1:0] = temp;
always @(*)
begin
    if(!a0)
        temp = z0;
    else if (!a1)
        temp = z1;
    else
        temp = 2'b0;
end        


endmodule

module lzc27(input wire[26:0] x,
            output wire[4:0]  z
            );

wire      a0, a1, a2;
wire[2:0] z0, z1, z2;
wire[1:0] z3;
wire[4:0] zINT;
reg [2:0]  temp;

lzc8 UUT1 (.x(x[26:19]), .a(a0), .z(z0));
lzc8 UUT2 (.x(x[18:11]), .a(a1), .z(z1));
lzc8 UUT3 (.x(x[10: 3]), .a(a2), .z(z2));
lzc3 UUT4 (.x(x[2 : 0]), .z(z3));


assign zINT[4] = a0  &  a1;
assign zINT[3] = a0  & (~a1 | a2);
assign zINT[2:0] = temp;
assign z = a0 & a1 & a2 ? zINT + z3 : zINT;


always @(*)
begin
    if(!a0)
        temp = z0;
    else if (!a1)
        temp = z1;
    else if (!a2)
        temp = z2;
    else
        temp = 3'b000;  
end

endmodule

module lzc3(input wire[2:0] x,
           output wire[1:0] z);

assign z[1] = !(|x[2:1]);
assign z[0] = ~x[2] & (x[1] | ~x[0]);

endmodule






