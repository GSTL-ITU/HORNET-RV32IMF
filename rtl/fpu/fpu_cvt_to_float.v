module fpu_cvt_to_float
(
    input        is_unsigned,
    input [2:0]  rounding_mode,
    input [31:0] A,
    output [31:0] cvrt_to_float_out
    

    
);


wire [31:0] abs_A;
assign abs_A = is_unsigned ? A : 
               A[31]     ? ~A+ 1 :
               A;
wire [62:0] int_before_shift;
wire [62:0] int_after_shift;
wire [4:0]  zero_count;
assign int_before_shift = {abs_A, 31'b0};
lzc32 lzc32(abs_A, zero_count);
wire [4:0] shamt;
assign shamt = 31 - zero_count;
assign int_after_shift = int_before_shift >> shamt;

wire [3:0] lgrs;
assign lgrs = {int_after_shift[8:6], |int_after_shift[5:0]}; 
wire round_out_temp, round_out;

wire final_sign;
wire[7:0] final_exp;
wire[22:0] final_sig;

wire [24:0] after_round;

cvrt_rounder cvrt_rounder_to_float(lgrs, rounding_mode, final_sign, round_out);

assign after_round = int_after_shift[31:8] + round_out;

assign final_sign = is_unsigned     ? 1'b0               : A[31];
assign final_exp  = after_round[24] ? shamt + 128        : shamt + 127;
assign final_sig  = after_round[24] ? after_round[23:1]  : after_round[22:0];
assign cvrt_to_float_out = |A[31:0] ? {final_sign, final_exp, final_sig} : 32'b0; //If all input bits are 0, the input is 0, thus the output should also be 0. (??)






endmodule

module lzc32
(
    input [31:0] x,
    output [4:0] z
);


wire      a0, a1, a2, a3;
wire[2:0] z0, z1, z2, z3;
wire[4:0] zINT;
reg [2:0]  temp;

lzc8 UUT1 (.x(x[31:24]), .a(a0), .z(z0));
lzc8 UUT2 (.x(x[23:16]), .a(a1), .z(z1));
lzc8 UUT3 (.x(x[15: 8]), .a(a2), .z(z2));
lzc8 UUT4 (.x(x[7 : 0]), .a(a3), .z(z3));


assign zINT[4] = a0  &  a1 ;
assign zINT[3] = a0  & (~a1 | a2);
assign zINT[2:0] = temp ;
assign z = a0 & a1 & a2 & a3 ? 5'd31 : zINT;

always @(*)
begin
    if(!a0)
        temp = z0;
    else if (!a1)
        temp = z1;
    else if (!a2)
        temp = z2;
    else if (!a3)
        temp = z3;
    else
        temp = 3'b000;  
end


endmodule