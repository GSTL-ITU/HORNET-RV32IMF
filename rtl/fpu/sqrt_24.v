module sqrt_24
    (   input clk,  
        input reset,  
        input start,
        input is_exp_odd,
        input [23:0] significand,   
        output done,     
        output reg [43:0] sq_root 
    );

 
 
    wire [45:0] first_op, second_op; //From 28
    wire signed [45:0] result; //From 28
    reg [87:0] reg_adjusted_input; //From 53
    reg [45:0] reg_remainder; //From 28
    reg [43:0] reg_partial_root; //From 26
    assign first_op = { reg_remainder[43:0], reg_adjusted_input[87:86]};
    assign second_op = { reg_partial_root, reg_remainder[45], 1'b1};
    assign result = reg_remainder[45] ? first_op + second_op : first_op - second_op;
   
    wire shiftSig, shiftQ, load;

    sqrt_control control(clk,start,reset,done,shiftSig,shiftQ,load);
    always @ (posedge clk or negedge reset) begin
      
	   if(!reset) begin
            sq_root <= 0;
            reg_adjusted_input <= 0;
            reg_remainder <= 0;
            reg_partial_root <= 0;

	   end

	   else begin
            if (load) begin
                sq_root <= 0;
                reg_adjusted_input <= is_exp_odd ? {significand, 64'b0} : {1'b0, significand, 63'b0};
                reg_remainder <= 0;
                reg_partial_root <= 0;
            end

            else begin
                if (shiftSig) 
                    reg_adjusted_input <= {reg_adjusted_input[85:0], 2'b00};
                else 
                    reg_adjusted_input <= reg_adjusted_input;


                if (shiftQ)
                    reg_partial_root <= {reg_partial_root[42:0], !result[45]};
                else
                    reg_partial_root <= reg_partial_root;
                
                sq_root <= reg_partial_root;
                reg_remainder <= result;

            end
        end
	end
    
    
            



endmodule

module sqrt_control
(
    input  clk,
    input  start,
    input  reset,
    output reg done,
    output reg shiftSig,
    output reg shiftQ,
    output reg load
    
);

    parameter IDLE = 2'b00, LOAD = 2'b01, ITR = 2'b10;
    reg [1:0]current_state, next_state;
    reg [5:0] itr;
    reg       incr_itr;
    reg       done_b4_delay;
    always @ (posedge clk or negedge reset) begin
		if(!reset) begin 
			current_state <= IDLE;
            done <= 0;
        end
        else begin
			current_state <= next_state;
            done <= done_b4_delay;
        end
					
	end



    always @ (posedge clk or negedge reset) begin
		if(!reset) 
            itr <= 5'b0;
		else begin
			if(incr_itr)
				itr <= itr + 1;
			else
				itr <= 5'b0;			
		end
	end



    always @(*) begin

        case(current_state)
            IDLE: begin
                done_b4_delay = 0;
                load = 1'b0;
                shiftSig = 1'b0;
                shiftQ = 1'b0;
                incr_itr = 1'b0;                
                
                


                if (start)
           
                    next_state = LOAD;

                else begin

                    next_state = IDLE;
                end
            end

            LOAD: begin
                done_b4_delay = 0;
                load = 1'b1;
                shiftSig = 1'b0;
                shiftQ = 1'b0;
                incr_itr = 1'b0;  
                next_state = ITR;
                end  

            
            ITR: begin
              
                load = 1'b0;
                if(itr != 44) begin
                    shiftSig = 1'b1;
                    shiftQ = 1'b1;

                    incr_itr = 1'b1;
                    done_b4_delay = 1'b0;
                    next_state = ITR;
                
                end
                else begin
                    shiftSig = 1'b0;
                    shiftQ = 1'b0;

                    incr_itr = 1'b0;
                    done_b4_delay = 1'b1;    
                    next_state = IDLE;
                end
            end
            default: begin
                load = 1'b0;
                next_state = IDLE;
                incr_itr = 1'b0;
                done_b4_delay = 0;
                shiftSig = 1'b0;
                shiftQ = 1'b0;
              end  
        endcase
    end
endmodule    
