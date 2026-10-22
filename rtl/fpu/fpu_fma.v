// Fused multiply-add a * b + c; FADD, FSUB, FMUL and the fused forms map onto it
// Cycles: unpack/normalise (start), multiply/align, add, normalise, round (done)
`include "hornet_defs.vh"

module fpu_fma(input             clk_i,
               input             rst_ni,
               input             start_i,
               input             kill_i,
               input      [4:0]  op_i,
               input      [2:0]  rm_i,
               input      [31:0] a_i, b_i, c_i,
               output            done_o,
               output reg [31:0] result_o,
               output reg [4:0]  flags_o);

//operands as a * b + c
wire neg_a = op_i == `FPU_NMSUB || op_i == `FPU_NMADD;
wire neg_c = op_i == `FPU_SUB || op_i == `FPU_MSUB || op_i == `FPU_NMADD;
wire is_add = op_i == `FPU_ADD || op_i == `FPU_SUB;
wire is_mul = op_i == `FPU_MUL;

wire [31:0] fa = {a_i[31] ^ neg_a, a_i[30:0]};
wire [31:0] fb = is_add ? 32'h3f80_0000 : b_i;
//a product without addend: c is a zero with the product's sign
wire [31:0] fc = is_mul ? {a_i[31] ^ b_i[31], 31'b0} : is_add ? {b_i[31] ^ neg_c, b_i[30:0]} : {c_i[31] ^ neg_c, c_i[30:0]};

function [4:0] lzc24;
    input [23:0] x;
    integer i;
    begin
        lzc24 = 5'd24;
        for(i = 0; i < 24; i = i + 1)
            if(x[i])
                lzc24 = 5'd23 - i[4:0];
    end
endfunction

function [6:0] lzc78;
    input [77:0] x;
    integer i;
    begin
        lzc78 = 7'd78;
        for(i = 0; i < 78; i = i + 1)
            if(x[i])
                lzc78 = 7'd77 - i[6:0];
    end
endfunction

//unpack: subnormals are normalised, exponents are biased and may go below 1
function [34:0] unpack; //{exp[10:0], mant[23:0]}
    input [31:0] x;
    reg   [4:0]  lz;
    reg   [23:0] m;
    begin
        m  = {x[30:23] != 8'd0, x[22:0]};
        lz = lzc24(m);
        if(x[30:23] == 8'd0)
            unpack = {11'd1 - {6'b0, lz}, m << lz};
        else
            unpack = {3'b0, x[30:23], m};
    end
endfunction

wire [34:0] ua = unpack(fa), ub = unpack(fb), uc = unpack(fc);

wire a_nan = fa[30:23] == 8'hff && fa[22:0] != 23'b0;
wire b_nan = fb[30:23] == 8'hff && fb[22:0] != 23'b0;
wire c_nan = fc[30:23] == 8'hff && fc[22:0] != 23'b0;
wire a_snan = a_nan && !fa[22], b_snan = b_nan && !fb[22], c_snan = c_nan && !fc[22];
wire a_inf = fa[30:0] == 31'h7f80_0000, b_inf = fb[30:0] == 31'h7f80_0000, c_inf = fc[30:0] == 31'h7f80_0000;
wire a_zero = fa[30:0] == 31'b0, b_zero = fb[30:0] == 31'b0, c_zero = fc[30:0] == 31'b0;

wire sp = fa[31] ^ fb[31];
wire sc = fc[31];
wire p_inf  = a_inf || b_inf;
wire p_zero = a_zero || b_zero;
wire inv = a_snan || b_snan || c_snan || (a_inf && b_zero) || (a_zero && b_inf) ||
           (p_inf && c_inf && sp != sc && !a_nan && !b_nan);

//special results, decided in the first cycle
reg        spec;
reg [31:0] spec_res;
always @*
begin
    spec = 1'b1;
    spec_res = 32'h7fc0_0000;
    if(a_nan || b_nan || c_nan || inv)
        spec_res = 32'h7fc0_0000;
    else if(p_inf)
        spec_res = {sp, 31'h7f80_0000};
    else if(c_inf)
        spec_res = fc;
    else if(p_zero && c_zero)
        spec_res = {sp == sc ? sp : rm_i == 3'b010, 31'b0};
    else if(p_zero)
        spec_res = fc;
    else
        spec = 1'b0;
end

reg  [2:0]  step;
reg  [2:0]  rm_q;
reg         spec_q, inv_q;
reg  [31:0] spec_res_q;
//stage 1
reg  [23:0] ma_q, mb_q, mc_q;
reg  signed [10:0] ea_q, eb_q, ec_q;
reg         sp_q, sc_q;
//stage 2
reg  [47:0] prod_q;
reg  [77:0] aw_q;
reg         case_b_q;
reg  signed [11:0] base_q;
//stage 3
reg  [77:0] sum_q;
reg         sign_q;
reg         zero_q;
//stage 4
reg  [25:0] mant_q;
reg         sticky_q;
reg  signed [11:0] exp_q;

//stage 2: alignment of the addend against the product (window bit 0 is a sticky bit)
wire signed [11:0] d = ec_q - ea_q - eb_q + 12'sd150;
wire        case_b = d > 12'sd50 && mc_q != 24'b0; //a zero addend never dominates
wire [11:0] sh_raw = 12'sd50 - d;
wire [6:0]  sh = case_b ? 7'd0 : (sh_raw > 12'd78 ? 7'd78 : sh_raw[6:0]);
wire [155:0] a_wide = {1'b0, mc_q, 53'b0, 78'b0} >> sh;
wire [77:0] a_win = {a_wide[155:79], a_wide[78] | (|a_wide[77:0])};
wire signed [11:0] pexp = ea_q + eb_q - 12'sd300;

//stage 3: add or subtract
wire        eff_sub = sp_q ^ sc_q;
wire [77:0] p_win = case_b_q ? {77'b0, 1'b1} : {27'b0, prod_q, 3'b0};
wire [78:0] diff = {1'b0, p_win} - {1'b0, aw_q};
wire [78:0] sum  = eff_sub ? (diff[78] ? -diff : diff) : {1'b0, p_win} + {1'b0, aw_q};

//stage 4: normalise
wire [6:0]  lz = lzc78(sum_q);
wire [77:0] norm = sum_q << lz;

wire [31:0] rnd_res;
wire        rnd_of, rnd_uf, rnd_nx;
fpu_round ROUND(.sign_i(sign_q),
                .exp_i(exp_q),
                .mant_i(mant_q),
                .sticky_i(sticky_q),
                .rm_i(rm_q),
                .result_o(rnd_res),
                .overflow_o(rnd_of),
                .underflow_o(rnd_uf),
                .inexact_o(rnd_nx));

assign done_o = step == 3'd4;

always @*
begin
    if(spec_q)
    begin
        result_o = spec_res_q;
        flags_o = {inv_q, 4'b0};
    end
    else if(zero_q) //exact cancellation
    begin
        result_o = {rm_q == 3'b010, 31'b0};
        flags_o = 5'b0;
    end
    else
    begin
        result_o = rnd_res;
        flags_o = {2'b0, rnd_of, rnd_uf, rnd_nx};
    end
end

always @(posedge clk_i or negedge rst_ni)
begin
    if(!rst_ni)
    begin
        step <= 3'd0;
        rm_q <= 3'b0;
        {spec_q, inv_q} <= 2'b0;
        spec_res_q <= 32'b0;
        {ma_q, mb_q, mc_q} <= 72'b0;
        {ea_q, eb_q, ec_q} <= 33'b0;
        {sp_q, sc_q} <= 2'b0;
        prod_q <= 48'b0;
        aw_q <= 78'b0;
        case_b_q <= 1'b0;
        base_q <= 12'sd0;
        sum_q <= 78'b0;
        {sign_q, zero_q} <= 2'b0;
        mant_q <= 26'b0;
        sticky_q <= 1'b0;
        exp_q <= 12'sd0;
    end
    else if(kill_i)
        step <= 3'd0;
    else
        case(step)
            3'd0:
                if(start_i)
                begin
                    rm_q <= rm_i;
                    spec_q <= spec;
                    inv_q <= inv;
                    spec_res_q <= spec_res;
                    ma_q <= ua[23:0];
                    mb_q <= ub[23:0];
                    mc_q <= uc[23:0];
                    ea_q <= ua[34:24];
                    eb_q <= ub[34:24];
                    ec_q <= uc[34:24];
                    sp_q <= sp;
                    sc_q <= sc;
                    step <= 3'd1;
                end
            3'd1:
            begin
                prod_q <= ma_q * mb_q;
                aw_q <= a_win;
                case_b_q <= case_b;
                base_q <= case_b ? ec_q - 12'sd150 - 12'sd53 : pexp - 12'sd3;
                step <= 3'd2;
            end
            3'd2:
            begin
                sum_q <= sum[77:0];
                sign_q <= eff_sub && diff[78] ? sc_q : sp_q;
                zero_q <= sum[77:0] == 78'b0;
                step <= 3'd3;
            end
            3'd3:
            begin
                mant_q <= norm[77:52];
                sticky_q <= |norm[51:0];
                exp_q <= base_q + 12'sd77 - {5'b0, lz};
                step <= 3'd4;
            end
            default: ; //done until the instruction leaves EX
        endcase
end

endmodule
