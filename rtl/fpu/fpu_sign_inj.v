module fpu_sign_inj
(
    input [1:0] inj_type,
    input       sign_A,
    input       sign_B,
    output       sign_O_inj

);

assign sign_O_inj = inj_type == 2'b00 ?  sign_B          :
                    inj_type == 2'b01 ? !sign_B          :
                    inj_type == 2'b10 ?  sign_A ^ sign_B :
                    1'b0;

endmodule