module sigDiv(input        clk,
              input        start,
              input        reset,
			  input [4:0]  offSetB,
              input [49:0] dividend,
              input [49:0] divisor,
             output        rdy,
             output [26:0] div_out);

    wire [49:0] Q50;
    wire [49:0] Q_adjusted;
	//DividerBlock Signals
	wire A;
	wire [49:0] Rin, Rout, R;
	wire Q;

	//Control Signals
	wire [5:0] mux_A_sel;
	wire mux_Rin_sel;
	wire reg_Rin_en;
	wire reg_Q_en;

    //Registers
	reg [49:0] reg_R, reg_Q;

    
	fpu_div_control fpu_div_control(start, clk, reset, mux_A_sel, mux_Rin_sel, reg_Rin_en, reg_Q_en, rdy);

	fpu_div_block fpu_div_block(A, divisor, Rin, Rout, Q);

	assign A = dividend[49-mux_A_sel];
	
	assign Rin = mux_Rin_sel ? reg_R : 50'd0;

	assign Q50 = reg_Q;
    assign Q_adjusted = Q50 << 24 - offSetB;
	assign R = reg_R;

	assign div_out = {Q_adjusted[49:24], |Q_adjusted[23:0] | |R};

    always @ (posedge clk or negedge reset) begin

	   if(!reset) begin
	       reg_R <= 50'd0;
           reg_Q <= 50'd0;
	   end

	   else begin
            if (start == 0) begin
                reg_R <= 50'd0;
                reg_Q <= 50'd0;
            end

            else begin
                if (reg_Rin_en == 1)
                    reg_R <= Rout;
                else
                	reg_R <= reg_R;

                if (reg_Q_en == 1) begin
                    reg_Q[49:1] <= reg_Q[48:0];
                    reg_Q[0] <= Q;
                end else
                    reg_Q <= reg_Q;
            end
        end
	end

endmodule 


module fpu_div_array(
	input [49:0] a,
	input [49:0] b,
	output [49:0] r,
	output q);

	wire [50:0] r_temp;
	wire q_temp;

	assign r_temp = a - b;

	assign q_temp = ~r_temp[50];

	assign r = q_temp ? r_temp[49:0] : a;

	assign q = q_temp;

endmodule


module fpu_div_block(
	input A,
	input [49:0] B,
	input [49:0] Rin,
	output [49:0] Rout,
	output Q);

    fpu_div_array row_0({Rin[48:0], A}, B, Rout, Q);

endmodule




module fpu_div_control(
	input start,
	input clk,
	input reset,
	output reg [5:0] mux_A_sel,
	output reg mux_Rin_sel,
	output reg reg_Rin_en,
	output reg reg_Q_en,
	output reg rdy);

	parameter R1 = 1'b0, Rounds = 1'b1;

	reg current_state;
	reg next_state;
	reg [5:0] round_count;
	reg start_count, rdy_b4_delay;

	always @ (posedge clk or negedge reset) begin
		if(!reset) begin
			current_state <= 1'b0;
			rdy <= 1'b0;	
		end
		else begin
			current_state <= next_state;
			rdy <= rdy_b4_delay;			
		end
	end

	always @ (posedge clk or negedge reset) begin
		if(!reset)
			round_count <= 5'b0;
		else
		begin
			if(start_count)
				round_count <= round_count + 1;
			else
				round_count <= 5'b0;			
		end
	end

	always @* begin

    	case(current_state)
	    	R1: begin

	       		mux_A_sel = 5'b0;
	           	mux_Rin_sel = 1'b0;
	           	rdy_b4_delay = 1'b0;

	    		if(start) begin
	           	   	start_count = 1'b1;
	               	reg_Rin_en = 1'b1;
	               	reg_Q_en = 1'b1;
	               	next_state = Rounds;
	           	end

	           	else begin
	           		start_count = 1'b0;
	               	reg_Rin_en = 1'b0;
	               	reg_Q_en = 1'b0;
	               	next_state = R1;
	           	end
	       	end

	       	Rounds: begin
	       		if(round_count != 6'd49) begin

			   		mux_A_sel = round_count;
			   		start_count = 1'b1;
			   		mux_Rin_sel = 1'b1;
			       	reg_Rin_en = 1'b1;
			       	reg_Q_en = 1'b1;
			       	rdy_b4_delay = 1'b0;
			       	next_state = Rounds;
	           	end

	           	else begin
	           		mux_A_sel = round_count;
	           		start_count = 1'b0;
			   		mux_Rin_sel = 1'b1;
			       	reg_Rin_en = 1'b1;
			       	reg_Q_en = 1'b1;
			       	rdy_b4_delay = 1'b1;
			       	next_state = R1;
	           	end
	       	end


	       	default: begin
	           	next_state = R1;
	           	mux_A_sel = 5'b0;
	           	rdy_b4_delay = 0;
	           	mux_Rin_sel = 0;
	           	reg_Rin_en = 0;
	           	reg_Q_en = 0;
	       	end

        endcase
	end
endmodule