module fpu_compare
(
    input [1:0]  comp_func,
    input        sign_A,
    input        sign_B,
    input  [7:0] exp_A,
    input  [7:0] exp_B,
    input [23:0] sig_A,
    input [23:0] sig_B,
    input        isNaNA, isNaNB,
    input        isZeroA, isZeroB,
    input        isSignaling,
    output       comp_out,
    output       invalid
);
// comp_func == 2'b00  -> less equal
// comp_func == 2'b01  -> less 
// comp_func == 2'b10  -> equal


wire is_sign_equal; 
wire is_exp_equal;
wire is_sig_equal;

wire is_equal;
wire is_less;



assign is_sign_equal = !(sign_A ^ sign_B);
assign is_exp_equal  = !(exp_A ^ exp_B);
assign is_sig_equal  = !(sig_A ^ sig_B);

assign is_equal = (isZeroA & isZeroB) | (is_sign_equal & is_exp_equal & is_sig_equal); //If both inputs are zero, they're always equal, no matter what
assign is_less  = (isZeroA & isZeroB) ? 1'b0        : //(Not sure about this part)
                  !is_sign_equal ? sign_A & !sign_B :
                  !is_exp_equal  ? (sign_A ? exp_A > exp_B : exp_A  < exp_B)   : //If A (and B) are negative, the larger exponent is the smaller number
                  !is_sig_equal  ? (sign_A ? sig_A > sig_B : sig_A < sig_B)   : //The same applies to the significand
                  1'b0;

assign comp_out = isNaNA | isNaNB    ? 1'b0      :
                  comp_func == 2'b10 ? is_equal  :
                  comp_func == 2'b01 ? is_less   :
                  comp_func == 2'b00 ? is_less |  is_equal:
                  1'b0;
                  
assign invalid =  (isNaNA | isNaNB) ? (!comp_func[1] ?  1'b1 : isSignaling) :
                  1'b0;                  
// FLT.S and FLE.S perform what the IEEE 754-2008 standard refers to as signaling comparisons:
// that is, they set the invalid operation exception flag if either input is NaN. FEQ.S performs a quiet
// comparison: it only sets the invalid operation exception flag if either input is a signaling NaN. For
// all three instructions, the result is 0 if either operand is NaN.
endmodule




