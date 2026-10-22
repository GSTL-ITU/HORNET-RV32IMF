// Stalls, flushes, redirects and forwarding selects
module hazard_unit(//ID
                   input             id_valid_i,
                   input      [4:0]  id_rs1_i, id_rs2_i, id_rs3_i,
                   input             id_rs1_fp_i, id_rs2_fp_i,
                   input             id_rs1_used_i, id_rs2_used_i, id_rs3_used_i,
                   input             id_jal_i,
                   input      [31:0] id_jal_pc_i,
                   //EX
                   input             ex_valid_i,
                   input      [4:0]  ex_rs1_i, ex_rs2_i, ex_rs3_i,
                   input             ex_rs1_fp_i, ex_rs2_fp_i,
                   input      [4:0]  ex_rd_i,
                   input             ex_rd_we_i, ex_rd_fp_i,
                   input             ex_late_i, //result exists only after MEM: load, multiply, CSR read
                   input             ex_busy_i,
                   input             ex_redirect_i,
                   input      [31:0] ex_redirect_pc_i,
                   //MEM
                   input             mem_valid_i,
                   input      [4:0]  mem_rd_i,
                   input             mem_rd_we_i, mem_rd_fp_i,
                   input             mem_wait_i,
                   input             mem_redirect_i,
                   input      [31:0] mem_redirect_pc_i,
                   //WB
                   input      [4:0]  wb_rd_i,
                   input             wb_rd_we_i, wb_rd_fp_i,
                   input             wb_wait_i,
                   input             wb_fault_i,
                   input      [31:0] wb_fault_pc_i,

                   output            hold_o,      //memory wait: the whole pipeline holds
                   output            if_stall_o,  //IF/ID holds
                   output            id_hold_o,   //ID/EX holds
                   output            id_bubble_o, //ID/EX gets a bubble
                   output            id_flush_o,  //ID/EX is cleared
                   output            ex_flush_o,  //EX/MEM is cleared, EX is killed
                   output            redirect_o,
                   output reg [31:0] redirect_pc_o,
                   output     [1:0]  fwd_a_o, fwd_b_o, fwd_c_o);

assign hold_o = mem_wait_i || wb_wait_i;

//load-use and every other late producer: one stall
wire ex_late = ex_valid_i && ex_rd_we_i && ex_late_i;
wire use1 = id_rs1_used_i && ex_rd_i == id_rs1_i && ex_rd_fp_i == id_rs1_fp_i && (id_rs1_fp_i || id_rs1_i != 5'd0);
wire use2 = id_rs2_used_i && ex_rd_i == id_rs2_i && ex_rd_fp_i == id_rs2_fp_i && (id_rs2_fp_i || id_rs2_i != 5'd0);
wire use3 = id_rs3_used_i && ex_rd_i == id_rs3_i && ex_rd_fp_i;
wire load_use = id_valid_i && ex_late && (use1 || use2 || use3);

wire mem_redirect = mem_redirect_i && !wb_fault_i;
wire ex_redirect  = ex_redirect_i && !hold_o && !mem_redirect && !wb_fault_i;
wire id_redirect  = id_jal_i && !hold_o && !ex_busy_i && !ex_redirect && !mem_redirect && !wb_fault_i;

assign if_stall_o  = hold_o || ex_busy_i || load_use;
assign id_hold_o   = hold_o || ex_busy_i;
assign id_bubble_o = load_use;
assign id_flush_o  = wb_fault_i || mem_redirect || ex_redirect;
assign ex_flush_o  = wb_fault_i || mem_redirect;

assign redirect_o = wb_fault_i || mem_redirect || ex_redirect || id_redirect;
always @*
begin
    if(wb_fault_i)
        redirect_pc_o = wb_fault_pc_i;
    else if(mem_redirect)
        redirect_pc_o = mem_redirect_pc_i;
    else if(ex_redirect)
        redirect_pc_o = ex_redirect_pc_i;
    else
        redirect_pc_o = id_jal_pc_i;
end

//forwarding into EX, newest first
function [1:0] fwd;
    input [4:0] rs;
    input       fp;
    begin
        if(mem_valid_i && mem_rd_we_i && mem_rd_i == rs && mem_rd_fp_i == fp && (fp || rs != 5'd0))
            fwd = 2'd1;
        else if(wb_rd_we_i && wb_rd_i == rs && wb_rd_fp_i == fp && (fp || rs != 5'd0))
            fwd = 2'd2;
        else
            fwd = 2'd0;
    end
endfunction

assign fwd_a_o = fwd(ex_rs1_i, ex_rs1_fp_i);
assign fwd_b_o = fwd(ex_rs2_i, ex_rs2_fp_i);
assign fwd_c_o = fwd(ex_rs3_i, 1'b1);

endmodule
