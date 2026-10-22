// FCVT.W[U].S and FCVT.S.W[U]: prepare in the start cycle, round in the next
`include "hornet_defs.vh"

module fpu_cvt(input             clk_i,
               input             rst_ni,
               input             start_i,
               input             kill_i,
               input      [4:0]  op_i,
               input      [2:0]  rm_i,
               input      [31:0] a_i,
               output            done_o,
               output reg [31:0] result_o,
               output reg [4:0]  flags_o);

function [5:0] lzc32;
    input [31:0] x;
    integer i;
    begin
        lzc32 = 6'd32;
        for(i = 0; i < 32; i = i + 1)
            if(x[i])
                lzc32 = 6'd31 - i[5:0];
    end
endfunction

function round_up;
    input [2:0] rm;
    input s, lsb, r, st;
    begin
        case(rm)
            3'b000: round_up = r & (st | lsb);
            3'b001: round_up = 1'b0;
            3'b010: round_up = s & (r | st);
            3'b011: round_up = !s & (r | st);
            3'b100: round_up = r;
            default: round_up = 1'b0;
        endcase
    end
endfunction

wire to_int    = op_i == `FPU_CVTWS || op_i == `FPU_CVTWUS;
wire is_signed = op_i == `FPU_CVTWS || op_i == `FPU_CVTSW;

//float to integer: magnitude with round and sticky bits
wire [7:0]  e   = a_i[30:23];
wire [23:0] m   = {e != 8'd0, a_i[22:0]};
wire        nan = e == 8'hff && a_i[22:0] != 23'b0;
wire        inf = e == 8'hff && a_i[22:0] == 23'b0;
wire        big = e > 8'd158; //|a| >= 2^32
wire [7:0]  rsh = e < 8'd150 ? 8'd150 - e : 8'd0;
wire [55:0] xr  = {m, 32'b0} >> (rsh > 8'd32 ? 8'd32 : rsh); //at 32 all of m is still in the sticky bits
wire [31:0] mag = e >= 8'd150 ? {8'b0, m} << (e - 8'd150) : {8'b0, xr[55:32]};

//integer to float: absolute value, normalised
wire        i_neg  = is_signed && a_i[31];
wire [31:0] i_abs  = i_neg ? -a_i : a_i;
wire [5:0]  i_lz   = lzc32(i_abs);
wire [31:0] i_norm = i_abs << i_lz;

reg         busy_q, to_int_q, signed_q, sign_q, nan_q, inf_q, big_q, zero_q;
reg  [2:0]  rm_q;
reg  [31:0] mag_q;
reg         r_q, st_q;
reg  [11:0] exp_q;
reg  [25:0] mant_q;

assign done_o = busy_q;

//float to integer
wire        inc   = round_up(rm_q, sign_q, mag_q[0], r_q, st_q);
wire [32:0] mag_r = {1'b0, mag_q} + {32'b0, inc};
reg         inv;
reg  [31:0] ires;
always @*
begin
    if(signed_q)
        inv = nan_q || inf_q || big_q || (sign_q ? mag_r > 33'h0_8000_0000 : mag_r > 33'h0_7fff_ffff);
    else
        inv = nan_q || inf_q || big_q || (sign_q ? mag_r != 33'b0 : mag_r > 33'h0_ffff_ffff);
    if(inv)
        ires = signed_q ? (nan_q || !sign_q ? 32'h7fff_ffff : 32'h8000_0000)
                        : (nan_q || !sign_q ? 32'hffff_ffff : 32'h0);
    else
        ires = sign_q ? -mag_r[31:0] : mag_r[31:0];
end

//integer to float
wire [31:0] fres;
wire        f_of, f_uf, f_nx;
fpu_round ROUND(.sign_i(sign_q),
                .exp_i(exp_q),
                .mant_i(mant_q),
                .sticky_i(st_q),
                .rm_i(rm_q),
                .result_o(fres),
                .overflow_o(f_of),
                .underflow_o(f_uf),
                .inexact_o(f_nx));

always @*
begin
    if(to_int_q)
    begin
        result_o = ires;
        flags_o = inv ? 5'b10000 : {4'b0, r_q | st_q};
    end
    else if(zero_q)
    begin
        result_o = 32'b0;
        flags_o = 5'b0;
    end
    else
    begin
        result_o = fres;
        flags_o = {2'b0, f_of, f_uf, f_nx};
    end
end

always @(posedge clk_i or negedge rst_ni)
begin
    if(!rst_ni)
    begin
        {busy_q, to_int_q, signed_q, sign_q, nan_q, inf_q, big_q, zero_q} <= 8'b0;
        rm_q <= 3'b0;
        mag_q <= 32'b0;
        {r_q, st_q} <= 2'b0;
        exp_q <= 12'b0;
        mant_q <= 26'b0;
    end
    else if(kill_i)
        busy_q <= 1'b0;
    else if(start_i && !busy_q)
    begin
        busy_q <= 1'b1;
        to_int_q <= to_int;
        signed_q <= is_signed;
        rm_q <= rm_i;
        if(to_int)
        begin
            sign_q <= a_i[31];
            nan_q <= nan;
            inf_q <= inf;
            big_q <= big;
            mag_q <= mag;
            r_q <= e < 8'd150 && xr[31];
            st_q <= e < 8'd150 && |xr[30:0];
        end
        else
        begin
            sign_q <= i_neg;
            zero_q <= a_i == 32'b0;
            exp_q <= 12'd31 - {6'b0, i_lz};
            mant_q <= i_norm[31:6];
            st_q <= |i_norm[5:0];
        end
    end
end

endmodule
