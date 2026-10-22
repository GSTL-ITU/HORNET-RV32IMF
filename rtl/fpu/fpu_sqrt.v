module fpu_sqrt
    (   
        input         clk,  
        input         reset,  
        input         start,
        input         is_subnormal,
        input         in_exp0,
        input [7:0]   exp_half,
        input [23:0]  in_sig,
        input [2:0]   rounding_mode,
        output        sqrt_done,
        output [26:0] sqrt_proNorm_sig,
        output [7:0]  sqrt_proNorm_exp,
        output        uf
    );


wire [43:0] sqrt_sig;
wire is_exp_odd = is_subnormal ? 1'b0: !in_exp0;
sqrt_24 sqrt_24(clk, reset, start, is_exp_odd, in_sig, sqrt_done, sqrt_sig);


wire [5:0] lzc_for_subnorm;
lzc44 lzc44(.x(sqrt_sig), .z(lzc_for_subnorm));

wire [43:0] sqrt_norm_sig;
assign sqrt_norm_sig = sqrt_sig << lzc_for_subnorm;
assign sqrt_proNorm_sig = is_subnormal ? ( (rounding_mode == 3'b011) ? {sqrt_norm_sig[43:20],sqrt_sig[19:18],|sqrt_sig[17:0]} : {sqrt_norm_sig[43:18],|sqrt_norm_sig[17:0]}) : 
                                         {sqrt_sig[43:18],|sqrt_sig[17:0]}; //So that the sticky bit is properly set.
assign sqrt_proNorm_exp = is_subnormal ? exp_half - lzc_for_subnorm : exp_half;

assign uf = is_subnormal ?  !sqrt_norm_sig[43] : 1'b0; // if hidden bit is 0 then, underflow. Normal inputs can't set underflow flag.
endmodule

module lzc44(
    input  wire [43:0] x,
    output wire [5:0]  z
);

wire      a0, a1, a2, a3, a4, a5;
wire[2:0] z0, z1, z2, z3, z4;
wire[1:0] z5;
reg [5:0] z_result;

// 5 × lzc8
lzc8 U0 (.x(x[43:36]), .a(a0), .z(z0));
lzc8 U1 (.x(x[35:28]), .a(a1), .z(z1));
lzc8 U2 (.x(x[27:20]), .a(a2), .z(z2));
lzc8 U3 (.x(x[19:12]), .a(a3), .z(z3));
lzc8 U4 (.x(x[11: 4]), .a(a4), .z(z4));

// Final 4 bits with lzc4
lzc4 U5 (.x(x[3:0]), .a(a5), .z(z5));

// Priority encoder
always @(*) begin
    if (!a0)
        z_result = 6'd0  + z0;
    else if (!a1)
        z_result = 6'd8  + z1;
    else if (!a2)
        z_result = 6'd16 + z2;
    else if (!a3)
        z_result = 6'd24 + z3;
    else if (!a4)
        z_result = 6'd32 + z4;
    else if (!a5)
        z_result = 6'd40 + z5;
    else
        z_result = 6'd44;  // all bits zero
end

assign z = z_result;

endmodule

