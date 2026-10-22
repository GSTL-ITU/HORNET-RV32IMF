/*
Register Forwarding Unit
This module is responsible for detecting pipeline data hazards, and generating the controls signals
for the forwarding muxes(2, 4 and 8) in the EX stage.
It can forward data from MEM or the WB stage to EX stage, when necessary.
It is also responsible for the forwarding of the CSRs.
*/

module forwarding_unit(input [4:0] rs1,
                       input [4:0] rs2,
                       input [4:0] exmem_rd,
                       input [4:0] memwb_rd,
					   input       fpu_alu_mem_sel,
					   input       fpu_reg_bank_ex1, //Forward only if hazard generating registers are in the same bank
					   input       fpu_reg_bank_ex2,
					   input       fpu_reg_bank_exmem_rd,
					   input       fpu_reg_bank_memwb_rd,
                       input exmem_wb, memwb_wb,

                       output reg [1:0] mux1_ctrl, //control signal for mux2 in EX
                       output reg [1:0] mux2_ctrl); //control signal for mux4 in EX


always @(*)
begin
	if(!exmem_wb) //forward from MEM stage
	begin
		//forward rs1
		if(rs1 == exmem_rd && fpu_reg_bank_ex1 == fpu_reg_bank_exmem_rd && ((rs1 != 5'b0) || fpu_reg_bank_ex1)) //Skip forwarding if rs1 is x0, but forward if it is in the floating point register bank
		begin
			if(!fpu_alu_mem_sel)
				mux1_ctrl = 2'b10;
			else
				mux1_ctrl = 2'b11;
		end
		else if(!memwb_wb)
		begin
			if(rs1 == memwb_rd && fpu_reg_bank_ex1 == fpu_reg_bank_memwb_rd && ((rs1 != 5'b0) || fpu_reg_bank_ex1))
				mux1_ctrl = 2'b01;
			else
				mux1_ctrl = 2'b00;
		end
		else
			mux1_ctrl = 2'b00;

		//forward rs2
		if(rs2 == exmem_rd && fpu_reg_bank_ex2 == fpu_reg_bank_exmem_rd && ((rs2 != 5'b0) || fpu_reg_bank_ex2))
		begin
			if(!fpu_alu_mem_sel)
				mux2_ctrl = 2'b00;
			else
				mux2_ctrl = 2'b11;
		end
		else if(!memwb_wb)
		begin
			if(rs2 == memwb_rd && fpu_reg_bank_ex2 == fpu_reg_bank_memwb_rd && ((rs2 != 5'b0) || fpu_reg_bank_ex2))
				mux2_ctrl = 2'b01;
			else
				mux2_ctrl = 2'b10;
		end
		else
			mux2_ctrl = 2'b10;
	end

	else if(!memwb_wb) //forward from WB stage
	begin
		if(rs1 == memwb_rd && fpu_reg_bank_ex1 == fpu_reg_bank_memwb_rd && ((rs1 != 5'b0) || fpu_reg_bank_ex1))
			mux1_ctrl = 2'b01;
		else
			mux1_ctrl = 2'b00;

		if(rs2 == memwb_rd && fpu_reg_bank_ex2 == fpu_reg_bank_memwb_rd && ((rs2 != 5'b0) || fpu_reg_bank_ex2))
			mux2_ctrl = 2'b1;
		else
			mux2_ctrl = 2'b10;
	end

	else //no forwarding needed
	begin
		mux1_ctrl = 2'b0;
		mux2_ctrl = 2'b10;
	end
end

endmodule
