// Rounds a normalised value 1.m * 2^exp to binary32 (subnormals, overflow, flags)
module fpu_round(input             sign_i,
                 input      [11:0] exp_i,    //signed, unbiased
                 input      [25:0] mant_i,   //mant_i[25] is the leading one
                 input             sticky_i,
                 input      [2:0]  rm_i,
                 output reg [31:0] result_o,
                 output            overflow_o,
                 output            underflow_o,
                 output            inexact_o);

wire signed [12:0] biased = {exp_i[11], exp_i} + 13'sd127;
wire normal = biased >= 13'sd1;

//subnormal results are shifted right before rounding
wire [12:0] sh_raw = 13'd1 - biased;
wire [5:0]  sh     = sh_raw > 13'd51 ? 6'd51 : sh_raw[5:0]; //at 51 all bits still reach the sticky bit
wire [51:0] denorm = {mant_i, 26'b0} >> sh;

wire [23:0] mant  = normal ? mant_i[25:2] : denorm[51:28];
wire        rbit  = normal ? mant_i[1] : denorm[27];
wire        sbit  = normal ? (mant_i[0] | sticky_i) : (|denorm[26:0] | sticky_i);
wire [7:0]  efield = normal ? (biased > 13'sd255 ? 8'hff : biased[7:0]) : 8'd0;

function round_up;
    input [2:0] rm;
    input s, lsb, r, st;
    begin
        case(rm)
            3'b000: round_up = r & (st | lsb); //RNE
            3'b001: round_up = 1'b0;           //RTZ
            3'b010: round_up = s & (r | st);   //RDN
            3'b011: round_up = !s & (r | st);  //RUP
            3'b100: round_up = r;              //RMM
            default: round_up = 1'b0;
        endcase
    end
endfunction

wire        inc    = round_up(rm_i, sign_i, mant[0], rbit, sbit);
wire [31:0] rounded = {1'b0, efield, mant[22:0]} + {31'b0, inc};

assign inexact_o  = rbit | sbit | overflow_o;
assign overflow_o = normal && (biased >= 13'sd255 || rounded[30:23] == 8'hff);

//tininess after rounding: a value just below the smallest normal that rounds up to it is not tiny
wire full_inc = round_up(rm_i, sign_i, mant_i[2], mant_i[1], mant_i[0] | sticky_i);
wire tiny     = !normal && !(biased == 13'sd0 && mant_i[25:2] == 24'hffffff && full_inc);
assign underflow_o = tiny && (rbit | sbit);

//overflow goes to infinity or the largest finite value, depending on the rounding direction
wire to_inf = rm_i == 3'b000 || rm_i == 3'b100 || (rm_i == 3'b010 && sign_i) || (rm_i == 3'b011 && !sign_i);

always @*
begin
    if(overflow_o)
        result_o = to_inf ? {sign_i, 8'hff, 23'b0} : {sign_i, 8'hfe, 23'h7fffff};
    else
        result_o = {sign_i, rounded[30:0]};
end

endmodule
