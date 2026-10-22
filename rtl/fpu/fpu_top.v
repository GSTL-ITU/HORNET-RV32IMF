// FPU: single-cycle operations here, FMA, divide/square root and conversions in their own units
`include "hornet_defs.vh"

module fpu_top
(
    input             clk_i,
    input             rst_ni,
    input             start_i,  //first EX cycle of a multi-cycle operation
    input             kill_i,   //the instruction leaves EX
    input      [4:0]  op_i,
    input      [2:0]  rm_i,     //resolved rounding mode
    input      [31:0] a_i,
    input      [31:0] b_i,
    input      [31:0] c_i,
    output            multi_o,
    output            done_o,
    output reg [31:0] result_o,
    output reg [4:0]  flags_o   //NV DZ OF UF NX
);

wire is_fma = op_i <= `FPU_NMADD;
wire is_ds  = op_i == `FPU_DIV || op_i == `FPU_SQRT;
wire is_cvt = op_i >= `FPU_CVTWS;
assign multi_o = is_fma || is_ds || is_cvt;

// decoder signals
wire       sign_A, sign_B;
wire [7:0] exp_A, exp_B, exp_A_for_sgninj, exp_B_for_sgninj;
wire[23:0] sig_A, sig_B;
wire       isSubnormalA, isSubnormalB;
wire       isZeroA, isZeroB;
wire       isInfA, isInfB, isSignalingA;
wire       isNaNA, isNaNB, isSignalingB;

fpu_decoder  decA(.in(a_i), .sign_o(sign_A), .exp_o(exp_A), .sig_o(sig_A), .isSubnormal(isSubnormalA), .isZero(isZeroA), .isInf(isInfA), .isNaN(isNaNA), .isSignaling(isSignalingA), .exp_o_for_sgninj(exp_A_for_sgninj));
fpu_decoder  decB(.in(b_i), .sign_o(sign_B), .exp_o(exp_B), .sig_o(sig_B), .isSubnormal(isSubnormalB), .isZero(isZeroB), .isInf(isInfB), .isNaN(isNaNB), .isSignaling(isSignalingB), .exp_o_for_sgninj(exp_B_for_sgninj));

wire isSignaling = isSignalingA | isSignalingB;

//FPU-SIGN INJECTION signals
wire sign_O_inj;
fpu_sign_inj fpu_sign_inj(op_i == `FPU_SGNJ ? 2'b00 : op_i == `FPU_SGNJN ? 2'b01 : 2'b10, sign_A, sign_B, sign_O_inj);

//FPU-MIN_MAX signals
wire [31:0] min_max_out;
wire invalid_min_max;
fpu_min_max fpu_min_max(op_i == `FPU_MAX, sign_A, sign_B, exp_A_for_sgninj, exp_B_for_sgninj, sig_A, sig_B, isInfA, isInfB, isNaNA, isNaNB, isSignaling, min_max_out, invalid_min_max);

// FPU-COMPARE signals
wire comp_out;
wire invalid_comp;
fpu_compare fpu_compare(op_i == `FPU_EQ ? 2'b10 : op_i == `FPU_LT ? 2'b01 : 2'b00, sign_A, sign_B, exp_A, exp_B, sig_A, sig_B, isNaNA, isNaNB, isZeroA, isZeroB, isSignaling, comp_out, invalid_comp);

//FPU-CLASSIFIER signals
wire[9:0] classifier_out;
fpu_classifier fpu_classifier(sign_A, isSubnormalA, isZeroA, isInfA, isNaNA, isSignalingA, classifier_out);

//multi-cycle units
wire        fma_done, ds_done, cvt_done;
wire [31:0] fma_out, ds_out, cvt_out;
wire [4:0]  fma_flags, ds_flags, cvt_flags;

fpu_fma FMA(.clk_i(clk_i), .rst_ni(rst_ni), .start_i(start_i && is_fma), .kill_i(kill_i),
            .op_i(op_i), .rm_i(rm_i), .a_i(a_i), .b_i(b_i), .c_i(c_i),
            .done_o(fma_done), .result_o(fma_out), .flags_o(fma_flags));

fpu_divsqrt DIVSQRT(.clk_i(clk_i), .rst_ni(rst_ni), .start_i(start_i && is_ds), .kill_i(kill_i),
                    .sqrt_i(op_i == `FPU_SQRT), .rm_i(rm_i), .a_i(a_i), .b_i(b_i),
                    .done_o(ds_done), .result_o(ds_out), .flags_o(ds_flags));

fpu_cvt CVT(.clk_i(clk_i), .rst_ni(rst_ni), .start_i(start_i && is_cvt), .kill_i(kill_i),
            .op_i(op_i), .rm_i(rm_i), .a_i(a_i),
            .done_o(cvt_done), .result_o(cvt_out), .flags_o(cvt_flags));

assign done_o = is_fma ? fma_done : is_ds ? ds_done : is_cvt ? cvt_done : 1'b1;

always @*
begin
    flags_o = 5'b0;
    case(op_i)
        `FPU_SGNJ, `FPU_SGNJN, `FPU_SGNJX: result_o = {sign_O_inj, a_i[30:0]};
        `FPU_MIN, `FPU_MAX:
        begin
            result_o = min_max_out;
            flags_o = {invalid_min_max, 4'b0};
        end
        `FPU_EQ, `FPU_LT, `FPU_LE:
        begin
            result_o = {31'b0, comp_out};
            flags_o = {invalid_comp, 4'b0};
        end
        `FPU_CLASS: result_o = {22'b0, classifier_out};
        `FPU_MVXW, `FPU_MVWX: result_o = a_i;
        default:
        begin
            result_o = is_fma ? fma_out : is_ds ? ds_out : cvt_out;
            flags_o  = is_fma ? fma_flags : is_ds ? ds_flags : cvt_flags;
        end
    endcase
end

endmodule
