// Radix-2 restoring divider for DIV, DIVU, REM, REMU (EX stage)
module div(input             clk_i,
           input             rst_ni,
           input             start_i,
           input             kill_i, //the instruction leaves EX
           input      [1:0]  op_i,   //funct3[1:0]
           input      [31:0] a_i,
           input      [31:0] b_i,
           output            done_o,
           output     [31:0] result_o);

`ifdef RISCV_FORMAL_ALTOPS
localparam STEPS = 6'd3;
`else
localparam STEPS = 6'd32;
`endif

localparam IDLE = 2'd0, RUN = 2'd1, DONE = 2'd2, FIX = 2'd3;

reg  [1:0]  state;
reg  [5:0]  count;
reg  [31:0] quot, rem, divisor;
reg         neg_q, neg_r, is_rem;
reg  [31:0] result_q;
reg  [31:0] alt_a, alt_b;
reg  [1:0]  alt_op;

wire is_signed = !op_i[0];
wire a_neg = is_signed && a_i[31];
wire b_neg = is_signed && b_i[31];
wire [31:0] a_abs = a_neg ? -a_i : a_i;
wire [31:0] b_abs = b_neg ? -b_i : b_i;
wire by_zero  = b_i == 32'b0;
wire overflow = is_signed && a_i == 32'h8000_0000 && b_i == 32'hffff_ffff;

wire [32:0] diff = {rem[30:0], quot[31]} - {1'b0, divisor};

assign done_o = state == DONE;
`ifdef RISCV_FORMAL_ALTOPS
assign result_o = alt_op == 2'b00 ? (alt_a - alt_b) ^ 32'h7f8529ec
                : alt_op == 2'b01 ? (alt_a - alt_b) ^ 32'h10e8fd70
                : alt_op == 2'b10 ? (alt_a - alt_b) ^ 32'h8da68fa5
                :                   (alt_a - alt_b) ^ 32'h3138d0e1;
`else
assign result_o = result_q;
`endif

always @(posedge clk_i or negedge rst_ni)
begin
    if(!rst_ni)
    begin
        state <= IDLE;
        count <= 6'd0;
        {quot, rem, divisor, result_q} <= 128'b0;
        {neg_q, neg_r, is_rem} <= 3'b0;
        {alt_a, alt_b, alt_op} <= 66'b0;
    end
    else if(kill_i)
        state <= IDLE;
    else
        case(state)
            IDLE:
                if(start_i)
                begin
                    alt_a <= a_i;
                    alt_b <= b_i;
                    alt_op <= op_i;
                    is_rem <= op_i[1];
                    if(by_zero)
                    begin
                        result_q <= op_i[1] ? a_i : 32'hffff_ffff;
                        state <= DONE;
                    end
                    else if(overflow)
                    begin
                        result_q <= op_i[1] ? 32'b0 : 32'h8000_0000;
                        state <= DONE;
                    end
                    else
                    begin
                        quot <= a_abs;
                        rem <= 32'b0;
                        divisor <= b_abs;
                        neg_q <= a_neg ^ b_neg;
                        neg_r <= a_neg;
                        count <= STEPS;
                        state <= RUN;
                    end
                end
            RUN:
            begin
                if(diff[32])
                begin
                    rem <= {rem[30:0], quot[31]};
                    quot <= {quot[30:0], 1'b0};
                end
                else
                begin
                    rem <= diff[31:0];
                    quot <= {quot[30:0], 1'b1};
                end
                count <= count - 6'd1;
                if(count == 6'd1)
                    state <= FIX;
            end
            FIX: //sign correction
            begin
                result_q <= is_rem ? (neg_r ? -rem : rem) : (neg_q ? -quot : quot);
                state <= DONE;
            end
            default: ;
        endcase
end

endmodule
