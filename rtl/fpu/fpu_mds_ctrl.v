`define qNaN_sig 23'b100_0000_0000_0000_0000_0000
module fpu_mds_ctrl(
    input clk,
    input start,
    input reset,
    input isZeroA, isZeroB,
    input isInfA, isInfB,
    input isNaNA, isNaNB,
    input isSignaling,
    input [1:0] mds_op_sel,
    input       sign_A, sign_B,
    input       sign_O,
    input [7:0] exp_A, exp_B,
    input [21:0] sig_A, sig_B,
    input div_rdy,
    input sqrt_rdy,
    output reg div_start,
    output reg sqrt_start,
    output reg reg_muldiv_sqrt_en,
    output reg [1:0] mux_muldiv_sqrt_out_sel,
    output reg mux_fastres_sel,
    output reg [31:0] fast_res,
    output reg overflow_fast, invalid_fast, divByZero_fast,
    output reg muldiv_sqrt_done

    );


    parameter IDLE = 3'd0, DIV = 3'd1, DIV_out = 3'd2,
    MUL1 = 3'd3, MUL2 = 3'd4, MUL_out = 3'd5, SQRT = 3'd6, SQRT_out = 3'd7;

    reg[2:0] current_state, next_state;
    reg mux_fastres_sel_temp;

always @ (posedge clk or negedge reset) begin
    if(!reset)
        current_state <= IDLE;
    else
        current_state <= next_state;
end    


always @*
    mux_fastres_sel = mux_fastres_sel_temp;

always @(*)
begin
    case (mds_op_sel)
        // FMUL
        2'b00: begin
                divByZero_fast = 1'b0;        
            // A is Zero
            if      (isZeroA ) begin
                
                overflow_fast = 0;
                // A = 0 & B = 0
                if(isZeroB) begin
                    // Not sure if negative zeros have an effect for 0*0, let's add it for now
                    fast_res = {sign_O, 31'b0}; //If either one is negative, result is negative 0, if both neg or pos then it's positive.
                    invalid_fast = 0;

                end

                // A = 0 & B = INF

                else if(isInfB) begin
                    fast_res = {1'b0, 8'd255, `qNaN_sig};
                    invalid_fast = 1;                
                end

                // A = 0 & B = NAN
                else if (isNaNB) begin
//                  fast_res = {sign_B, exp_B, 1'b1, sig_B};
                    fast_res = {1'b0, exp_B, 1'b1, 22'b0}; //Standard dictates all NaN outputs are 0x7fc00000
                    if(isSignaling)
                        invalid_fast = 1;
                    else
                        invalid_fast = 0;
                    

                end
                // A = 0 & B = (SUB)NORMAL
                else begin
                    fast_res = {sign_O,31'b0};
                    invalid_fast = 0;                    
                end
            mux_fastres_sel_temp = 1'b1;
            end

            // A is INF
            else if (isInfA)begin

                // A = INF & B = 0
                if(isZeroB) begin
                    fast_res = {1'b0, 8'd255, `qNaN_sig};
                    overflow_fast = 0;
                    invalid_fast = 1;                    
                end

                // A = INF & B = INF
                else if(isInfB) begin
                    fast_res = {sign_O, 8'd255, 23'd0};
                    overflow_fast = 0;
                    invalid_fast = 0;                       
                end 

                // A = INF & B = NAN
                else if (isNaNB) begin
//                  fast_res = {sign_B, exp_B, 1'b1, sig_B};
                    fast_res = {1'b0, exp_B, 1'b1, 22'b0};
                    overflow_fast = 0;
                    if(isSignaling)
                        invalid_fast = 1;
                    else
                        invalid_fast = 0;
                    
                end 

                // A = INF & B = (SUB)NORMAL   
                else begin
                    fast_res = {sign_O, 8'd255, 23'd0};
                    overflow_fast = 0;
                    invalid_fast = 0;                     
                end
            mux_fastres_sel_temp = 1'b1;
            end

            // A is NaN
            else if (isNaNA) begin
//              fast_res = {sign_A, exp_A, 1'b1, sig_A};
                fast_res = {1'b0, exp_A, 1'b1, 22'b0};
                overflow_fast = 0;
                if(isSignaling)
                    invalid_fast = 1;
                else
                    invalid_fast = 0;                 
            mux_fastres_sel_temp = 1'b1;
            end

            // A is (sub)normal
            else begin

                // A = (SUB)NORMAL & B = 0
                if(isZeroB) begin 
                    fast_res = {sign_O, 31'b0};
                    overflow_fast = 0;
                    invalid_fast = 0;  
                    mux_fastres_sel_temp = 1'b1;
                end

                // A = (SUB)NORMAL & B = INF
                else if(isInfB) begin
                    fast_res = {sign_O, 8'd255, 23'd0};
                    overflow_fast = 0;
                    invalid_fast = 0;                    
                    mux_fastres_sel_temp = 1'b1;
                end

                // A = (SUB)NORMAL & B = NAN
                else if (isNaNB) begin
//                  fast_res = {sign_B, exp_B, 1'b1, sig_B};
                    fast_res = {1'b0, exp_B, 1'b1, 22'b0};
                    overflow_fast = 0;
                    if(isSignaling)
                        invalid_fast = 1;
                    else
                        invalid_fast = 0;                    
                    mux_fastres_sel_temp = 1'b1;
                end

                // A = (SUB)NORMAL & B = SUBNORMAL
                else begin
                    fast_res = 0;
                    overflow_fast = 0;
                    invalid_fast = 0;                    
                    mux_fastres_sel_temp = 1'b0;
                end
            end

        end

        // FDIV
        2'b01:
        begin

            // A is Zero
            if      (isZeroA) begin
                overflow_fast = 0;
                

                // A = 0 & B = 0

                if(isZeroB) begin
                    fast_res = {1'b0, 8'd255, `qNaN_sig};
                    invalid_fast = 1;
                    divByZero_fast = 1;                    
                end 
                // A = 0 & B = INF
                else if(isInfB) begin
                    fast_res = {sign_O,31'b0}; //Not sure
                    invalid_fast = 0;
                    divByZero_fast = 0;                                       
                end 
                // A = 0 & B = NAN
                else if (isNaNB) begin
//                  fast_res = {sign_B, exp_B, 1'b1, sig_B};
                    fast_res = {1'b0, exp_B, 1'b1, 22'b0};
                    if(isSignaling)
                        invalid_fast = 1;
                    else
                        invalid_fast = 0; 
                    divByZero_fast = 0;                                       
                end 
                // A = 0 & B = (SUB)NORMAL
                else begin
                    fast_res = {sign_O,31'b0}; //Not sure
                    invalid_fast = 0; 
                    divByZero_fast = 0;                                       
                end 
            mux_fastres_sel_temp = 1'b1;
            end

            // A is INF
            else if (isInfA)begin

                // A = INF & B = 0

                if(isZeroB) begin
                    fast_res = {sign_O, 8'd255, 23'd0};
                    overflow_fast = 0;
                    invalid_fast = 0;                     
                    divByZero_fast = 1;                                       
                end 

                // A = INF & B = INF

                else if(isInfB) begin
                    fast_res = {1'b0, 8'd255, `qNaN_sig};
                    overflow_fast = 0;
                    invalid_fast = 1;                     
                    divByZero_fast = 0;                                       
                end 

                // A = INF & B = NAN

                else if (isNaNB) begin
//                  fast_res = {sign_B, exp_B, 1'b1, sig_B};
                    fast_res = {1'b0, exp_B, 1'b1, 22'b0};
                    overflow_fast = 0;
                    if(isSignaling)
                        invalid_fast = 1;
                    else
                        invalid_fast = 0;                      
                    divByZero_fast = 0;                                       
                end 

                // A = INF & B = (SUB)NORMAL   

                else begin
                    fast_res = {sign_O, 8'd255, 23'd0};
                    overflow_fast = 0;
                    invalid_fast = 0;                     
                    divByZero_fast = 0;                                       
                end 
            mux_fastres_sel_temp = 1'b1;
            end

            // A is NaN
            else if (isNaNA) begin
//              fast_res = {sign_A, exp_A, 1'b1, sig_A};
                fast_res = {1'b0, exp_A, 1'b1, 22'b0};

                overflow_fast = 0;
                
                if(isSignaling)
                    invalid_fast = 1;
                else
                    invalid_fast = 0;  
                divByZero_fast = 0;
            mux_fastres_sel_temp = 1'b1;
            end

            // A is (sub)normal
            else begin

                // A = (SUB)NORMAL & B = 0
                if(isZeroB) begin 
                    fast_res = {sign_O, 8'd255, 23'd0}; //For negative A, the output is negative infinity //Doesn't the sign of B matter too?
                    overflow_fast = 0;
                    invalid_fast = 0;                     
                    divByZero_fast = 1; 
                    mux_fastres_sel_temp = 1'b1;
                end
                
                // A = (SUB)NORMAL & B = INF
                else if(isInfB) begin
                    fast_res = {sign_O,31'b0}; //Not sure
                    overflow_fast = 0;
                    invalid_fast = 0;                     
                    divByZero_fast = 0;                    
                    mux_fastres_sel_temp = 1'b1;
                end
                
                // A = (SUB)NORMAL & B = NAN

                else if (isNaNB) begin
//                  fast_res = {sign_B, exp_B, 1'b1, sig_B};
                    fast_res = {1'b0, exp_B, 1'b1, 22'b0};
                    overflow_fast = 0;
                    if(isSignaling)
                        invalid_fast = 1;
                    else
                        invalid_fast = 0;                       
                    divByZero_fast = 0;                    
                    mux_fastres_sel_temp = 1'b1;
                end
                
                // A = (SUB)NORMAL & B = (SUB)NORMAL
                else begin
                    fast_res = {sign_O,31'b0}; //Not sure
                    overflow_fast = 0;
                    invalid_fast = 0;                     
                    divByZero_fast = 0;                    
                    mux_fastres_sel_temp = 1'b0;
                end
            end

        end


        // FSQRT
        2'b10:begin
            divByZero_fast = 1'b0;
            if(isZeroA) begin 
                fast_res = {sign_A ? 1'b1 : 1'b0, 31'b0};
                mux_fastres_sel_temp = 1'b1;
                overflow_fast = 0;
                invalid_fast = 0;  
            end
            else if (isInfA) begin
                if (sign_A) begin
                    fast_res = {1'b0, 8'd255, `qNaN_sig};
                    mux_fastres_sel_temp = 1'b1;
                    overflow_fast = 0;
                    invalid_fast = 1;  
                end
                else begin
                    fast_res = {sign_O, 8'd255, 23'd0};
                    mux_fastres_sel_temp = 1'b1;
                    overflow_fast = 0;
                    invalid_fast = 0;
                end  
            end
            else if (isNaNA) begin
//              fast_res = {sign_A, exp_A, 1'b1, sig_A}; //The spec dictates to always output 0x7fc00000, this can cause that to fail if A is a signalling NaN (mantissa != 0)
                fast_res = {1'b0, exp_A, 1'b1, 22'b0};
                mux_fastres_sel_temp = 1'b1;
                overflow_fast = 0;
                if(isSignaling)
                    invalid_fast = 1;
                else
                    invalid_fast = 0; 
            end
            else if (sign_A) begin
                fast_res = {1'b0, 8'd255, `qNaN_sig};
                mux_fastres_sel_temp = 1'b1;
                overflow_fast = 0;
                invalid_fast = 1;  
            end
            else begin
                fast_res = 0;
                mux_fastres_sel_temp = 1'b0;
                overflow_fast = 0;
                invalid_fast = 0;
            end

        end

        default: begin
        fast_res = 0;
        mux_fastres_sel_temp = 1'b0;
        overflow_fast = 1'b0;
        invalid_fast = 1'b0;
        divByZero_fast = 1'b0;     
        end   
    endcase
end


// determine control signals
always @* begin
    case(current_state)
        IDLE: begin
            if(start == 1'b1) begin
                sqrt_start = 1'b0;
                div_start = 1'b0;
                mux_muldiv_sqrt_out_sel = 2'b00;

                if(mux_fastres_sel_temp) begin
                    reg_muldiv_sqrt_en = 1'b1;
                    muldiv_sqrt_done = 1'b1;
                    next_state = IDLE;
                end
                else begin
                    muldiv_sqrt_done = 1'b0;
                    reg_muldiv_sqrt_en = 1'b0;
                    if(mds_op_sel == 2'b00)
                        next_state = MUL1;
                    else if(mds_op_sel ==2'b01)
                        next_state = DIV;
                    else
                        next_state = SQRT;
                end
            end
            else begin
                sqrt_start = 1'b0;
                div_start = 1'b0;
                reg_muldiv_sqrt_en = 1'b0;
                mux_muldiv_sqrt_out_sel = 2'b00;
                muldiv_sqrt_done = 1'b0;
                next_state = IDLE;
            end
        end

        DIV: begin
            sqrt_start = 1'b0;
            mux_muldiv_sqrt_out_sel = 2'b00;
            muldiv_sqrt_done = 1'b0;
            if (div_rdy == 1'b1) begin
                div_start = 1'b0;
                reg_muldiv_sqrt_en = 1'b1;
                next_state = DIV_out;
            end

            else begin
                div_start = 1'b1;
                reg_muldiv_sqrt_en = 1'b0;
                next_state = DIV;
            end
        end

        DIV_out: begin
            div_start = 1'b0;
            sqrt_start = 1'b0;
            reg_muldiv_sqrt_en = 1'b0;
            mux_muldiv_sqrt_out_sel = 2'b01;
            muldiv_sqrt_done = 1'b1;
            next_state = IDLE;
        end


        MUL1: begin
            div_start = 1'b0;
            sqrt_start = 1'b0;
            reg_muldiv_sqrt_en = 1'b0;
            mux_muldiv_sqrt_out_sel = 2'b00;
            muldiv_sqrt_done = 1'b0;
            next_state = MUL2;
        end

        MUL2: begin
            div_start = 1'b0;
            sqrt_start = 1'b0;
            reg_muldiv_sqrt_en = 1'b1;
            mux_muldiv_sqrt_out_sel = 2'b00;
            muldiv_sqrt_done = 1'b0;
            next_state = MUL_out;
        end

        MUL_out: begin
            div_start = 1'b0;
            sqrt_start = 1'b0;
            reg_muldiv_sqrt_en = 1'b1;
            mux_muldiv_sqrt_out_sel = 2'b0;
            muldiv_sqrt_done = 1'b1;
            next_state = IDLE;
        end

        SQRT: begin
            div_start = 1'b0;
            mux_muldiv_sqrt_out_sel = 2'b00;
            muldiv_sqrt_done = 1'b0;
            
            if(sqrt_rdy == 1'b1) begin
                sqrt_start = 1'b0;
                reg_muldiv_sqrt_en = 1'b1;
                next_state = SQRT_out;
            end
            else begin
                sqrt_start = 1'b1;
                reg_muldiv_sqrt_en = 1'b0;
                next_state = SQRT;
            end
        end

        SQRT_out: begin
            div_start = 1'b0;
            sqrt_start = 1'b0;       
            reg_muldiv_sqrt_en = 1'b0;
            mux_muldiv_sqrt_out_sel = 2'b10;
            muldiv_sqrt_done = 1'b1;
            next_state = IDLE;
        end

        default: begin
            div_start = 1'b0;
            sqrt_start = 1'b0;  
            reg_muldiv_sqrt_en = 1'b0;
            mux_muldiv_sqrt_out_sel = 2'b00;
            muldiv_sqrt_done = 1'b0;
            next_state = IDLE;
        end
    endcase
end

endmodule



                 


