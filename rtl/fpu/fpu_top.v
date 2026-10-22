module fpu_top
(
    // inputs
    input        clk,
    input        reset,
    input        start,
    input  [4:0] op,
    input  [2:0] rounding_mode,
    input  [2:0] csr_dynamic_rounding_mode,
    input [31:0] A,
    input [31:0] B,
    input        rs2_lsb,
    // outputs
    output [31:0] fpu_arith_out,
    output        done,
    output        overflow,
    output        underflow,
    output        invalid,
    output        inexact,
    output        div_by_zero
);

wire in_sel, reg_AB_en;
wire [31:0] in_A;
wire [31:0] in_B;

reg [31:0] reg_A;
reg [31:0] reg_B;

assign in_A = in_sel ? A : reg_A;
assign in_B = in_sel ? B : reg_B;

fpu_arithmetic_top fpu_arithmetic_top(clk, reset, start, op, rounding_mode, csr_dynamic_rounding_mode, in_A, in_B, rs2_lsb, fpu_arith_out, done, overflow, underflow, invalid, inexact, div_by_zero);


fpu_top_ctrl fpu_top_ctrl(clk, reset, start, op, done, in_sel, reg_AB_en);


always @ (posedge clk or negedge reset) begin
    if(!reset) begin
        reg_A <= 32'b0;
        reg_B <= 32'b0;
    end

    else begin 
        if (reg_AB_en) begin
            reg_A <= A;
            reg_B <= B;
        end
    end
end
endmodule