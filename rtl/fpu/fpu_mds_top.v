`define max_sig 24'b1111_1111_1111_1111_1111_1111

module fpu_mds_top(
    input clk,
    input start,
    input reset,
    input [2:0] rounding_mode,
    input subnormal_sqrt_in,
    input isZeroA, isZeroB,
    input isInfA, isInfB,
    input isNaNA, isNaNB,
    input isSignaling,
    input sign_A, sign_B,
    input [7:0] exp_A, exp_B,
    input [23:0] sig_A,
    input [23:0] sig_B,
    input [1:0]  mds_op,
    output wire [31:0] OUT,
    output muldiv_sqrt_done,
    output overflow,
    output underflow,
    output invalid,
    output inexact,
    output div_by_zero
    );
    // round out signals
    wire mul_round_out;
    wire div_round_out;
    wire sqrt_round_out;
    // Sign assigment for FMUL/FDIV
    wire sign_O;
    assign sign_O = mds_op  == 2'b10 ? sign_A : sign_A ^ sign_B;

    // Pre-Normalization Exponent Handler
    wire[8:0] preNorm_exp;
    wire      is_exp_underFlow;

    preNorm_exp_handler preNorm_exp_handler(exp_A, exp_B, mds_op, subnormal_sqrt_in, is_exp_underFlow, preNorm_exp);


    // Multiplication Signals
    wire [25:0] mul_proNorm_sig;
    wire [7:0]  mul_proNorm_exp;
    wire  of_mul, uf_mul;

    fpu_mul fpu_mul(.clk(clk), .reset(reset), .preNorm_exp(preNorm_exp), .is_exp_underFlow(is_exp_underFlow), .sig_A(sig_A), .sig_B(sig_B), .mul_proNorm_sig(mul_proNorm_sig), .mul_proNorm_exp(mul_proNorm_exp), .OF_from_proNorm(of_mul), .UF_from_proNorm(uf_mul));
    mul_rounder mul_rounder(.LRS(mul_proNorm_sig[2:0]), .rounding_mode(rounding_mode), .sign_O(sign_O), .round_out(mul_round_out));


    // Division Signals
    wire       div_start, div_rdy;
    wire[26:0] div_proNorm_sig;
    wire[7:0]  div_proNorm_exp;
    wire of_div, uf_div;

    fpu_div fpu_div(.clk(clk), .reset(reset), .div_start(div_start), .preNorm_exp(preNorm_exp), .is_exp_underFlow(is_exp_underFlow), .sig_A(sig_A), .sig_B(sig_B), .div_proNorm_sig(div_proNorm_sig), .div_proNorm_exp(div_proNorm_exp), .div_rdy(div_rdy), .OF_from_proNorm(of_div), .UF_from_proNorm(uf_div));
    div_rounder div_rounder(.LGRS(div_proNorm_sig[3:0]), .rounding_mode(rounding_mode), .sign_O(sign_O), .round_out(div_round_out));

    

    // Square-Root Signals
    wire        sqrt_start, sqrt_rdy;
    wire[26:0]  sqrt_proNorm_sig;
    wire[7:0]   sqrt_proNorm_exp;
    wire        uf_sqrt;

    fpu_sqrt fpu_sqrt(.clk(clk), .reset(reset), .start(sqrt_start), .is_subnormal(subnormal_sqrt_in), .in_exp0(exp_A[0]), .exp_half(preNorm_exp[7:0]), .in_sig(sig_A), .rounding_mode(rounding_mode), .sqrt_done(sqrt_rdy), .sqrt_proNorm_sig(sqrt_proNorm_sig), .sqrt_proNorm_exp(sqrt_proNorm_exp), .uf(uf_sqrt));
    sqrt_rounder sqrt_rounder(.LGRS(sqrt_proNorm_sig[2:0]), .rounding_mode(rounding_mode), .sign_O(sign_O), .round_out(sqrt_round_out));


    // Final Normalizer Signals
    wire [24:0] sig_after_round;
    wire        of_from_pro_norm;
    wire [7:0]  proNorm_exp;
    wire [7:0]  final_exp;
    wire [22:0] final_sig;
    wire        of_final_norm;

    assign sig_after_round = mds_op == 2'b00 ? mul_proNorm_sig[25:2] + mul_round_out :
                             mds_op == 2'b01 ? div_proNorm_sig[26:3] + div_round_out :
                             mds_op == 2'b10 ? sqrt_proNorm_sig[26:3] + sqrt_round_out :
                             0;


    assign of_from_pro_norm = mds_op == 2'b00 ? of_mul :
                              mds_op == 2'b01 ? of_div :
                              mds_op == 2'b10 ? 1'b0   :  // no overflow occurs in sqrt
                              1'b0;

    assign proNorm_exp = mds_op == 2'b00 ? mul_proNorm_exp :
                         mds_op == 2'b01 ? div_proNorm_exp :
                         mds_op == 2'b10 ? sqrt_proNorm_exp :
                         0;

    mds_final_normalizer mds_final_normalizer(sig_after_round, of_from_pro_norm, proNorm_exp, mds_op, final_exp, final_sig, of_final_norm);


  




    
    
    // FPU MUL-DIV-SQRT Control Signals


    wire reg_muldiv_sqrt_en, mux_fastres_sel;
    wire [1:0] mux_muldiv_sqrt_out_sel;
    wire [31:0] fastres;
    wire overflow_fast, invalid_fast, divByZero_fast; // exceptions from fast results

    fpu_mds_ctrl  mds_ctrl(clk, start, reset, isZeroA, isZeroB, isInfA, isInfB, isNaNA, isNaNB, isSignaling, mds_op, sign_A, sign_B, sign_O, exp_A, exp_B, sig_A[21:0], sig_B[21:0], div_rdy, sqrt_rdy, div_start, sqrt_start, reg_muldiv_sqrt_en, mux_muldiv_sqrt_out_sel, mux_fastres_sel, fastres, overflow_fast, invalid_fast, divByZero_fast, muldiv_sqrt_done);




    wire [31:0] muldiv_sqrt;

    assign muldiv_sqrt = mux_muldiv_sqrt_out_sel == 2'b00 || mux_muldiv_sqrt_out_sel == 2'b01 ? {sign_O, final_exp, final_sig} :
                        mux_muldiv_sqrt_out_sel == 2'b10 ? {sign_O, sqrt_proNorm_exp, sqrt_proNorm_sig} : 32'b0;

    


    wire uf_temp;
    assign uf_temp  = mds_op == 2'b00 ? uf_mul   :
                      mds_op == 2'b01 ? uf_div   :
                      mds_op == 2'b10 ? uf_sqrt  :
                      1'b0; 
                      
        // assignment of exceptions

    assign overflow    = mux_fastres_sel ? overflow_fast : of_final_norm;
    assign underflow   = mux_fastres_sel ? 1'b0 : uf_temp;
    assign invalid     = invalid_fast;
    assign inexact     = mux_fastres_sel ? overflow_fast : uf_temp ? 1'b1 :
                         mds_op == 2'b00 ? mul_round_out :
                         mds_op == 2'b01 ? div_round_out :
                         mds_op == 2'b10 ? sqrt_round_out :
                         1'b0;
    assign div_by_zero = divByZero_fast;

    reg[31:0] OUT_reg;
    assign OUT = mux_fastres_sel ? fastres : OUT_reg;

    

    always @ (posedge clk or negedge reset) begin
        if(!reset) begin
            OUT_reg <= 32'd0;
        end

        else begin 
                if(reg_muldiv_sqrt_en)
                    if(overflow) begin //Overflow edge cases
                        if(sign_O) begin //For negative numbers
                            if((rounding_mode == 3'b001) || (rounding_mode == 3'b011))
                                OUT_reg <= 32'hff7fffff; //For RTZ or RUP, -Inf rounds down to largest mag. negative number
                            else OUT_reg <= muldiv_sqrt;
                        end
                        else begin //For positive numbers
                            if((rounding_mode == 3'b001) || (rounding_mode == 3'b010))
                                OUT_reg <= 32'h7f7fffff; //For RTZ or RDN, +Inf rounds down to largest mag. positive number
                            else OUT_reg <= muldiv_sqrt;
                        end
                    end
                    else if(underflow) begin //Underflow edge cases
                        if(sign_O && muldiv_sqrt == 32'h80000000) begin //For negative numbers, only if output value is initially -0.0
                            if((rounding_mode == 3'b010))
                                OUT_reg <= 32'h80000001; //For RDN, -0.0 rounds down to smallest mag. negative number
                            else OUT_reg <= muldiv_sqrt;
                        end
                        else if(!sign_O && muldiv_sqrt == 32'b0) begin //For positive numbers, only if output value is initially 0.0
                            if((rounding_mode == 3'b011))
                                OUT_reg <= 32'h0000001; //For RUP, +0.0 rounds up to smallest mag. positive number
                            else OUT_reg <= muldiv_sqrt;
                        end
                        else OUT_reg <= muldiv_sqrt;
                    end
                    else OUT_reg <= muldiv_sqrt;
        end
    end
endmodule













module preNorm_exp_handler
(
    input [7:0] exp_A, exp_B,
    input [1:0] mds_op,
    input       is_sqrtIn_subnormal,
    output reg  is_exp_underFlow,
    output reg [8:0] preNorm_exp
);

reg [8:0] sqrt_temp;

always @(*)
begin
    case(mds_op)
        // FMUL
        2'b00: begin
            sqrt_temp = 0;
            is_exp_underFlow = exp_A + exp_B <= 127;
            preNorm_exp = exp_A + exp_B - 127;
        end

        // FDIV
        2'b01: begin
            sqrt_temp = 0;
            is_exp_underFlow = exp_A + 127 <=  exp_B;
            preNorm_exp = exp_A + 127 - exp_B;            
        end

        // FSQRT
        2'b10: begin
            sqrt_temp = exp_A - 127 >> 1;
            is_exp_underFlow = 0;
            preNorm_exp = is_sqrtIn_subnormal ? 9'b01000000 : sqrt_temp[7:0] + 127; 
        end
        default: begin
            sqrt_temp = 0;
            is_exp_underFlow = 0;
            preNorm_exp = 0;
        end
    endcase
end


endmodule
