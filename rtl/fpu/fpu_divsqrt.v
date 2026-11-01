// FDIV and FSQRT: one quotient or root bit per cycle
`include "hornet_defs.vh"

module fpu_divsqrt(input             clk_i,
                   input             rst_ni,
                   input             start_i,
                   input             kill_i,
                   input             sqrt_i,
                   input      [2:0]  rm_i,
                   input      [31:0] a_i, b_i,
                   output            done_o,
                   output reg [31:0] result_o,
                   output reg [4:0]  flags_o);

localparam IDLE = 2'd0, RUN = 2'd1, DONE = 2'd2;

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

function [34:0] unpack; //{exp[10:0], mant[23:0]}, subnormals normalised
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

wire [34:0] ua = unpack(a_i), ub = unpack(b_i);
wire signed [10:0] ea = ua[34:24], eb = ub[34:24];

wire a_nan = a_i[30:23] == 8'hff && a_i[22:0] != 23'b0;
wire b_nan = b_i[30:23] == 8'hff && b_i[22:0] != 23'b0;
wire a_snan = a_nan && !a_i[22], b_snan = b_nan && !b_i[22];
wire a_inf = a_i[30:0] == 31'h7f80_0000, b_inf = b_i[30:0] == 31'h7f80_0000;
wire a_zero = a_i[30:0] == 31'b0, b_zero = b_i[30:0] == 31'b0;
wire sq = a_i[31] ^ b_i[31];

//special results
reg        spec;
reg [31:0] spec_res;
reg [4:0]  spec_flags;
always @*
begin
    spec = 1'b1;
    spec_res = 32'h7fc0_0000;
    spec_flags = 5'b0;
    if(sqrt_i)
    begin
        if(a_nan)
            spec_flags = {a_snan, 4'b0};
        else if(a_zero)
            spec_res = a_i;
        else if(a_i[31])
            spec_flags = 5'b10000;
        else if(a_inf)
            spec_res = a_i;
        else
            spec = 1'b0;
    end
    else
    begin
        if(a_nan || b_nan)
            spec_flags = {a_snan | b_snan, 4'b0};
        else if((a_inf && b_inf) || (a_zero && b_zero))
            spec_flags = 5'b10000;
        else if(a_inf || b_zero)
        begin
            spec_res = {sq, 31'h7f80_0000};
            spec_flags = {1'b0, !a_inf, 3'b0}; //divide by zero
        end
        else if(a_zero || b_inf)
            spec_res = {sq, 31'b0};
        else
            spec = 1'b0;
    end
end

reg  [1:0]  state;
reg  [4:0]  count;
reg         sqrt_q, sign_q, spec_q;
reg  [31:0] spec_res_q;
reg  [4:0]  spec_flags_q;
reg  [2:0]  rm_q;
reg  signed [11:0] exp_q;
reg  [26:0] q;      //quotient or root
reg  [28:0] rem;
reg  [23:0] divisor;
reg  [51:0] rad;    //radicand bits still to bring down

//division: restoring step
wire [28:0] dsub = rem - {5'b0, divisor};
//square root: next two radicand bits, trial subtrahend 4 * root + 1
wire [28:0] srem = {rem[26:0], rad[51:50]};
wire [29:0] ssub = {1'b0, srem} - {2'b0, q[25:0], 2'b01};

//radicand of the square root: mantissa * 2^27 (even exponent) or * 2^28 (odd)
wire signed [11:0] ea_unb = {ea[10], ea} - 12'sd127;
wire        odd = ea_unb[0];

//normalised result for rounding
wire        int_bit = q[26];
wire [25:0] mant    = sqrt_q ? q[25:0] : (int_bit ? q[26:1] : q[25:0]);
wire        sticky  = sqrt_q ? (rem != 29'b0) : ((int_bit & q[0]) | (rem != 29'b0));
wire signed [11:0] rexp = sqrt_q ? exp_q : (int_bit ? exp_q : exp_q - 12'sd1);

wire [31:0] rnd_res;
wire        rnd_of, rnd_uf, rnd_nx;
fpu_round ROUND(.sign_i(sign_q),
                .exp_i(rexp),
                .mant_i(mant),
                .sticky_i(sticky),
                .rm_i(rm_q),
                .result_o(rnd_res),
                .overflow_o(rnd_of),
                .underflow_o(rnd_uf),
                .inexact_o(rnd_nx));

assign done_o = state == DONE;

always @*
begin
    if(spec_q)
    begin
        result_o = spec_res_q;
        flags_o = spec_flags_q;
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
        state <= IDLE;
        count <= 5'd0;
        {sqrt_q, sign_q, spec_q} <= 3'b0;
        spec_res_q <= 32'b0;
        spec_flags_q <= 5'b0;
        rm_q <= 3'b0;
        exp_q <= 12'sd0;
        q <= 27'b0;
        rem <= 29'b0;
        divisor <= 24'b0;
        rad <= 52'b0;
    end
    else if(kill_i)
        state <= IDLE;
    else
        case(state)
            IDLE:
                if(start_i)
                begin
                    sqrt_q <= sqrt_i;
                    spec_q <= spec;
                    spec_res_q <= spec_res;
                    spec_flags_q <= spec_flags;
                    rm_q <= rm_i;
                    q <= 27'b0;
                    if(sqrt_i)
                    begin
                        sign_q <= 1'b0;
                        exp_q <= ea_unb >>> 1;
                        rem <= 29'b0;
                        rad <= odd ? {ua[23:0], 28'b0} : {1'b0, ua[23:0], 27'b0};
                        count <= 5'd26;
                    end
                    else
                    begin
                        sign_q <= sq;
                        exp_q <= {ea[10], ea} - {eb[10], eb};
                        rem <= {5'b0, ua[23:0]};
                        divisor <= ub[23:0];
                        count <= 5'd27;
                    end
                    state <= spec ? DONE : RUN;
                end
            RUN:
            begin
                if(sqrt_q)
                begin
                    rad <= {rad[49:0], 2'b0};
                    if(!ssub[29])
                    begin
                        rem <= ssub[28:0];
                        q <= {q[25:0], 1'b1};
                    end
                    else
                    begin
                        rem <= srem;
                        q <= {q[25:0], 1'b0};
                    end
                end
                else
                begin
                    if(!dsub[28])
                    begin
                        rem <= {dsub[27:0], 1'b0};
                        q <= {q[25:0], 1'b1};
                    end
                    else
                    begin
                        rem <= {rem[27:0], 1'b0};
                        q <= {q[25:0], 1'b0};
                    end
                end
                count <= count - 5'd1;
                if(count == 5'd1)
                    state <= DONE;
            end
            default: ;
        endcase
end

endmodule
