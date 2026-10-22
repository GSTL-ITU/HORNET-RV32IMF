// 33 x 33 signed multiplier for MUL, MULH, MULHSU, MULHU (MEM stage)
module mul(input  [1:0]  op_i, //funct3[1:0]
           input  [31:0] a_i,
           input  [31:0] b_i,
           output [31:0] result_o);

`ifdef RISCV_FORMAL_ALTOPS
assign result_o = op_i == 2'b00 ? (a_i + b_i) ^ 32'h5876063e
                : op_i == 2'b01 ? (a_i + b_i) ^ 32'hf6583fb7
                : op_i == 2'b10 ? (a_i - b_i) ^ 32'hecfbe137
                :                 (a_i + b_i) ^ 32'h949ce5e8;
`else
wire a_signed = op_i != 2'b11;
wire b_signed = op_i[1] == 1'b0;
wire signed [32:0] a = {a_signed & a_i[31], a_i};
wire signed [32:0] b = {b_signed & b_i[31], b_i};
wire signed [65:0] product = a * b;
assign result_o = op_i == 2'b00 ? product[31:0] : product[63:32];
`endif

endmodule
