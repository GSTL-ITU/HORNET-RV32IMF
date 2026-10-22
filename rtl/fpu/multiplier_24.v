module multiplier_24 (input clk,
               input reset,
               input [23:0] M_inA,
               input [23:0] M_inB,
               output [47:0] P);


    wire [5:0] A[0:3], B[0:3];
    wire [11:0] PPHH[3:0], PPHL[3:0], PPLH[3:0], PPLL[3:0];

    wire [11:0] PPHHs2[3:0], PPHLs2[3:0], PPLHs2[3:0], PPLLs2[3:0];
    wire [23:0] MHHs2, MHLs2, MLHs2, MLLs2;



    //Registers
    reg [11:0] PPHH_mreg[3:0], PPHL_mreg[3:0], PPLH_mreg[3:0], PPLL_mreg[3:0];

 //Assignment of 6-bit multiplication operands
    assign A[3][5:0] = M_inA[23:18];
    assign A[2][5:0] = M_inA[17:12];
    assign A[1][5:0] = M_inA[11:6];
    assign A[0][5:0] = M_inA[5:0];

    assign B[3][5:0] = M_inB[23:18];
    assign B[2][5:0] = M_inB[17:12];
    assign B[1][5:0] = M_inB[11:6];
    assign B[0][5:0] = M_inB[5:0];

//Stage 1
    //Partial Products
        //For MHH
    multiplier_6 PPHH3(A[3], B[3], PPHH[3]);
    multiplier_6 PPHH2(A[3], B[2], PPHH[2]);
    multiplier_6 PPHH1(A[2], B[3], PPHH[1]);
    multiplier_6 PPHH0(A[2], B[2], PPHH[0]);

        //For MHL
    multiplier_6 PPHL3(A[3], B[1], PPHL[3]);
    multiplier_6 PPHL2(A[3], B[0], PPHL[2]);
    multiplier_6 PPHL1(A[2], B[1], PPHL[1]);
    multiplier_6 PPHL0(A[2], B[0], PPHL[0]);

        //For MLH
    multiplier_6 PPLH3(A[1], B[3], PPLH[3]);
    multiplier_6 PPLH2(A[1], B[2], PPLH[2]);
    multiplier_6 PPLH1(A[0], B[3], PPLH[1]);
    multiplier_6 PPLH0(A[0], B[2], PPLH[0]);


        //For MLL
    multiplier_6 PPLL3(A[1], B[1], PPLL[3]);
    multiplier_6 PPLL2(A[1], B[0], PPLL[2]);
    multiplier_6 PPLL1(A[0], B[1], PPLL[1]);
    multiplier_6 PPLL0(A[0], B[0], PPLL[0]);

  //Assigning Registers
    always @ (posedge clk or negedge reset)
    begin

        if(!reset) begin

            PPHH_mreg[0] <= 12'd0;
            PPHH_mreg[1] <= 12'd0;
            PPHH_mreg[2] <= 12'd0;
            PPHH_mreg[3] <= 12'd0;

            PPHL_mreg[0] <= 12'd0;
            PPHL_mreg[1] <= 12'd0;
            PPHL_mreg[2] <= 12'd0;
            PPHL_mreg[3] <= 12'd0;

            PPLH_mreg[0] <= 12'd0;
            PPLH_mreg[1] <= 12'd0;
            PPLH_mreg[2] <= 12'd0;
            PPLH_mreg[3] <= 12'd0;

            PPLL_mreg[0] <= 12'd0;
            PPLL_mreg[1] <= 12'd0;
            PPLL_mreg[2] <= 12'd0;
            PPLL_mreg[3] <= 12'd0;

        end

        else begin

            PPHH_mreg[0] <= PPHH[0];
            PPHH_mreg[1] <= PPHH[1];
            PPHH_mreg[2] <= PPHH[2];
            PPHH_mreg[3] <= PPHH[3];

            PPHL_mreg[0] <= PPHL[0];
            PPHL_mreg[1] <= PPHL[1];
            PPHL_mreg[2] <= PPHL[2];
            PPHL_mreg[3] <= PPHL[3];

            PPLH_mreg[0] <= PPLH[0];
            PPLH_mreg[1] <= PPLH[1];
            PPLH_mreg[2] <= PPLH[2];
            PPLH_mreg[3] <= PPLH[3];

            PPLL_mreg[0] <= PPLL[0];
            PPLL_mreg[1] <= PPLL[1];
            PPLL_mreg[2] <= PPLL[2];
            PPLL_mreg[3] <= PPLL[3];

        end
    end

//Stage 2

    //Inputting signals to registers
    assign PPHHs2[0] = PPHH_mreg[0];
    assign PPHHs2[1] = PPHH_mreg[1];
    assign PPHHs2[2] = PPHH_mreg[2];
    assign PPHHs2[3] = PPHH_mreg[3];

    assign PPHLs2[0] = PPHL_mreg[0];
    assign PPHLs2[1] = PPHL_mreg[1];
    assign PPHLs2[2] = PPHL_mreg[2];
    assign PPHLs2[3] = PPHL_mreg[3];

    assign PPLHs2[0] = PPLH_mreg[0];
    assign PPLHs2[1] = PPLH_mreg[1];
    assign PPLHs2[2] = PPLH_mreg[2];
    assign PPLHs2[3] = PPLH_mreg[3];

    assign PPLLs2[0] = PPLL_mreg[0];
    assign PPLLs2[1] = PPLL_mreg[1];
    assign PPLLs2[2] = PPLL_mreg[2];
    assign PPLLs2[3] = PPLL_mreg[3];    


   //Formation of 4x34 bit products
    assign MHHs2 = (PPHHs2[3] << 12) + ((PPHHs2[2] + PPHHs2[1]) << 6) + PPHHs2[0];
    assign MHLs2 = (PPHLs2[3] << 12) + ((PPHLs2[2] + PPHLs2[1]) << 6) + PPHLs2[0];
    assign MLHs2 = (PPLHs2[3] << 12) + ((PPLHs2[2] + PPLHs2[1]) << 6) + PPLHs2[0];
    assign MLLs2 = (PPLLs2[3] << 12) + ((PPLLs2[2] + PPLLs2[1]) << 6) + PPLLs2[0];

    //Final Product
    assign P = (MHHs2 << 24) + ((MHLs2 + MLHs2) << 12) + MLLs2;
endmodule   


module multiplier_6(
    input [5:0] a,
    input [5:0] b,
    output [11:0] f
    );

    assign f = a * b;

endmodule
    