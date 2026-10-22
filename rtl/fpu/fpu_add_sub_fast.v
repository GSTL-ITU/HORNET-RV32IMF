module fpu_add_fast
(
    input [2:0] rounding_mode,
    input       isZeroA, isZeroB,
    input       isInfA, isInfB,
    input       isNaNA, isNaNB,
    input       isSignaling,
    input       sub_op,
    input       sign_A, sign_B,
    input [7:0] exp_A, exp_B,
    input [22:0] sig_A, sig_B,
    output reg mux_fastres_sel,
    output reg [31:0] fast_res,
    output reg overflow_fast,
    output reg invalid_fast


);
// 000 RNE Round to Nearest, ties to Even
// 001 RTZ Round towards Zero
// 010 RDN Round Down (towards -?)
// 011 RUP Round Up (towards +?)
// 100 RMM Round to Nearest, ties to Max Magnitude

always @(*)
begin


    if (!sub_op) begin // ADD OPERATION
            // A is Zero
            if      (isZeroA) begin
                
                overflow_fast = 0;

                // A = 0 & B = 0
                if(isZeroB) begin

                    invalid_fast = 0;
                    case(rounding_mode) 
                        3'b010: begin
                            if(!sign_A & !sign_B)
                                fast_res = {1'b0, 31'b0}; // +0;
                            else
                                fast_res = {1'b1, 31'b0}; // -0 otherwise  
                        end
                        default: begin
                            if(sign_A & sign_B)
                                fast_res = {1'b1, 31'b0}; // +0;
                            else
                                fast_res = {1'b0, 31'b0};
                        end
                    endcase


                end

                // A = 0 & B = INF

                else if(isInfB) begin
                    fast_res = {sign_B, exp_B, sig_B[22:0]}; // Infinity
                    invalid_fast = 0;                
                end

                // A = 0 & B = NAN
                else if (isNaNB) begin
//                  fast_res = {sign_B, exp_B, 1'b1, sig_B[21:0]}; //The spec dictates to always output 0x7fc00000, this can cause that to fail if A is a signalling NaN (mantissa != 0)
                    fast_res = {1'b0, exp_B, 1'b1, 22'b0};  //Since the spec dictates 0x7fc00000, sign bit is always 0
                    if(isSignaling)
                        invalid_fast = 1; //These may need further investigation
                    else
                        invalid_fast = 0;
                    

                end
                // A = 0 & B = (SUB)NORMAL
                else begin
                    fast_res = {sign_B, exp_B, sig_B[22:0]};
                    invalid_fast = 0;                    
                end
            mux_fastres_sel = 1'b1;
            end

            // A is INF
            else if (isInfA)begin

                // A = INF & B = 0
                if(isZeroB) begin
                    fast_res = {sign_A, exp_A, sig_A[22:0]};
                    overflow_fast = 0;
                    invalid_fast = 1;                    
                end

                // A = INF & B = INF
                else if(isInfB) begin
                    if(!(sign_A ^ sign_B)) begin
                        fast_res = {sign_A, exp_B, sig_B};
                        invalid_fast = 0;
                    end
                    else begin
                        fast_res = {1'b0, 8'd255, 1'b1, 22'b0}; 
                        invalid_fast = 1;
                    end
                    overflow_fast = 0; //Not sure
                end 

                // A = INF & B = NAN
                else if (isNaNB) begin
//                  fast_res = {sign_B, exp_B, 1'b1, sig_B[21:0]};
                    fast_res = {1'b0, exp_B, 1'b1, 22'b0};
                    overflow_fast = 0;
                    if(isSignaling)
                        invalid_fast = 1;
                    else
                        invalid_fast = 0;
                    
                end 

                // A = INF & B = (SUB)NORMAL   
                else begin
                    fast_res = {sign_A, exp_A, sig_A[22:0]};
                    overflow_fast = 0; //Not sure
                    invalid_fast = 0;                     
                end
            mux_fastres_sel = 1'b1;
            end

            // A is NaN
            else if (isNaNA) begin
//              fast_res = {sign_A, exp_A, 1'b1, sig_A[21:0]};
                fast_res = {1'b0, exp_A, 1'b1, 22'b0};
                overflow_fast = 0;
                if(isSignaling)
                    invalid_fast = 1;
                else
                    invalid_fast = 0;                 
            mux_fastres_sel = 1'b1;
            end

            // A is (sub)normal
            else begin

                // A = (SUB)NORMAL & B = 0
                if(isZeroB) begin 
                    fast_res = {sign_A, exp_A, sig_A[22:0]};
                    overflow_fast = 0;
                    invalid_fast = 0;  
                    mux_fastres_sel = 1'b1;
                end

                // A = (SUB)NORMAL & B = INF
                else if(isInfB) begin
                    fast_res = {sign_B, exp_B, sig_B[22:0]};
                    overflow_fast = 0; //Not sure
                    invalid_fast = 0;                    
                    mux_fastres_sel = 1'b1;
                end

                // A = (SUB)NORMAL & B = NAN
                else if (isNaNB) begin
//                  fast_res = {sign_B, exp_B, 1'b1, sig_B[21:0]};
                    fast_res = {1'b0, exp_B, 1'b1, 22'b0};
                    overflow_fast = 0;
                    if(isSignaling)
                        invalid_fast = 1;
                    else
                        invalid_fast = 0;                    
                    mux_fastres_sel = 1'b1;
                end

                // A = (SUB)NORMAL & B = (SUB)NORMAL
                else begin
                    fast_res = 0;
                    overflow_fast = 0;
                    invalid_fast = 0;                    
                    mux_fastres_sel = 1'b0;
                end
            end
    end

    else begin
            // A is Zero
            if      (isZeroA) begin
                
                overflow_fast = 0;

                // A = 0 & B = 0
                if(isZeroB) begin
                        
                    invalid_fast = 0;
                    case(rounding_mode) 
                        3'b010: begin
                            if(!sign_A & sign_B)
                                fast_res = {1'b0, 31'b0}; // +0;
                            else
                                fast_res = {1'b1, 31'b0}; // -0 otherwise  
                        end
                        default: begin
                            if(sign_A & !sign_B)
                                fast_res = {1'b1, 31'b0}; // -0;
                            else
                                fast_res = {1'b0, 31'b0}; // +0
                        end
                    endcase


                end

                // A = 0 & B = INF

                else if(isInfB) begin
                    fast_res = {!sign_B, exp_B, sig_B[22:0]}; // Infinity
                    invalid_fast = 0;                
                end

                // A = 0 & B = NAN
                else if (isNaNB) begin
//                  fast_res = {sign_B, exp_B, 1'b1, sig_B[21:0]};
                    fast_res = {1'b0, exp_B, 1'b1, 22'b0};
                    if(isSignaling)
                        invalid_fast = 1;
                    else
                        invalid_fast = 0;
                    

                end
                // A = 0 & B = (SUB)NORMAL
                else begin
                    fast_res = {!sign_B, exp_B, sig_B[22:0]};
                    invalid_fast = 0;                    
                end
            mux_fastres_sel = 1'b1;
            end

            // A is INF
            else if (isInfA)begin

                // A = INF & B = 0
                if(isZeroB) begin
                    fast_res = {sign_A, exp_A, sig_A[22:0]};
                    overflow_fast = 0;
                    invalid_fast = 1;                    
                end

                // A = INF & B = INF
                else if(isInfB) begin
                    if((sign_A ^ sign_B)) begin
                        fast_res = {sign_A, exp_B, sig_B};
                        invalid_fast = 0;
                    end
                    else begin
                        fast_res = {1'b0, 8'd255, 1'b1, 22'b0}; //QNaN
                        invalid_fast = 1;
                    end
                    overflow_fast = 0; //Not sure
                end 

                // A = INF & B = NAN
                else if (isNaNB) begin
//                  fast_res = {sign_B, exp_B, 1'b1, sig_B[21:0]};
                    fast_res = {1'b0, exp_B, 1'b1, 22'b0};
                    overflow_fast = 0;
                    if(isSignaling)
                        invalid_fast = 1;
                    else
                        invalid_fast = 0;
                    
                end 

                // A = INF & B = (SUB)NORMAL   
                else begin
                    fast_res = {sign_A, exp_A, sig_A[22:0]};
                    overflow_fast = 0; //Not sure
                    invalid_fast = 0;                     
                end
            mux_fastres_sel = 1'b1;
            end

            // A is NaN
            else if (isNaNA) begin
//              fast_res = {sign_A, exp_A, 1'b1, sig_A[21:0]};
                fast_res = {1'b0, exp_A, 1'b1, 22'b0};
                overflow_fast = 0;
                if(isSignaling)
                    invalid_fast = 1;
                else
                    invalid_fast = 0;                 
            mux_fastres_sel = 1'b1;
            end

            // A is (sub)normal
            else begin

                // A = (SUB)NORMAL & B = 0
                if(isZeroB) begin 
                    fast_res = {sign_A, exp_A, sig_A[22:0]};
                    overflow_fast = 0;
                    invalid_fast = 0;  
                    mux_fastres_sel = 1'b1;
                end

                // A = (SUB)NORMAL & B = INF
                else if(isInfB) begin
                    fast_res = {!sign_B, exp_B, sig_B[22:0]}; //Forgot to invert sign of B
                    overflow_fast = 0; //Not sure
                    invalid_fast = 0;                    
                    mux_fastres_sel = 1'b1;
                end

                // A = (SUB)NORMAL & B = NAN
                else if (isNaNB) begin
//                  fast_res = {sign_B, exp_B, 1'b1, sig_B[21:0]};
                    fast_res = {1'b0, exp_B, 1'b1, 22'b0};
                    overflow_fast = 0;
                    if(isSignaling)
                        invalid_fast = 1;
                    else
                        invalid_fast = 0;                    
                    mux_fastres_sel = 1'b1;
                end

                // A = (SUB)NORMAL & B = (SUB)NORMAL
                else begin
                    fast_res = 0;
                    overflow_fast = 0;
                    invalid_fast = 0;                    
                    mux_fastres_sel = 1'b0;
                end
            end


    end


    
end

endmodule
           