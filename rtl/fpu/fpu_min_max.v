module fpu_min_max
(
    input        min_or_max,
    input        sign_A,
    input        sign_B,
    input  [7:0] exp_A,
    input  [7:0] exp_B,
    input [23:0] sig_A,
    input [23:0] sig_B,
    input        isInfA, isInfB,
    input        isNaNA, isNaNB,
    input        isSignaling,
    output [31:0]min_max_out,
    output       invalid
);


wire is_sign_equal; 
wire is_exp_equal;
wire is_sig_equal;

wire A_big;
wire is_both_NaN;
wire [31:0] A = {sign_A, exp_A, sig_A[22:0]};
wire [31:0] B = {sign_B, exp_B, sig_B[22:0]};

assign is_both_NaN = isNaNA & isNaNB; // if  both inputs are NaN, then set the output canonical NaN 
assign is_sign_equal = !(sign_A ^ sign_B);
assign is_exp_equal  = !(exp_A ^ exp_B);
assign is_sig_equal  = !(sig_A ^ sig_B);

assign A_big = !is_sign_equal ? !sign_A       : // if sign of A is 0, meaning positive
               sign_A         ?  (!is_exp_equal  ? exp_B > exp_A : !is_sig_equal  ? sig_B > sig_A : 1'b1) : // if numbers are equal
               (!is_exp_equal  ? exp_A > exp_B : !is_sig_equal  ? sig_A > sig_B : 1'b1);

assign min_max_out = is_both_NaN  ? 32'h7fc00000   :
                     isNaNA       ? B              :
                     isNaNB       ? A              :
                     (min_or_max) ? (A_big ? A : B):
                     (A_big ? B : A);

assign invalid = isSignaling; //Signaling NaN inputs set the invalid operation exception flag, even when the result is not NaN.

endmodule