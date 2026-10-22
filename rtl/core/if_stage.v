// IF: fetch unit and the IF/ID register
module if_stage #(parameter RESET_VECTOR = 32'h0000_0000)
                (input             clk_i,
                 input             rst_ni,

                 output            instr_req_o,
                 input             instr_gnt_i,
                 output     [31:0] instr_addr_o,
                 input             instr_rvalid_i,
                 input      [31:0] instr_rdata_i,
                 input             instr_err_i,

                 input             redirect_i,
                 input      [31:0] redirect_pc_i,
                 input             stall_i, //hold IF/ID

                 output reg        valid_o,
                 output reg [31:0] pc_o,
                 output reg [31:0] instr_o,
                 output reg        fault_o);

reg  [31:0] pc_q;          //next address to request
reg         outstanding_q; //accepted, response not yet seen
reg  [31:0] out_pc_q;      //address of the outstanding request
reg         drop_q;        //drop the outstanding response
reg         waiting_q;     //request raised, not yet granted
reg  [31:0] wait_pc_q;
reg         stale_q;       //a redirect happened while waiting
reg         buf_valid_q;
reg  [31:0] buf_pc_q, buf_instr_q;
reg         buf_fault_q;

wire resp   = instr_rvalid_i && outstanding_q;
wire accept = instr_req_o && instr_gnt_i;
wire use_resp = resp && !drop_q && !redirect_i;

//the buffer must be empty when the next response can arrive
wire buf_next = redirect_i ? 1'b0
              : stall_i ? (buf_valid_q || use_resp)
              : (buf_valid_q && use_resp);

wire can_issue = !buf_next && (!outstanding_q || resp);

assign instr_req_o  = rst_ni && (waiting_q || can_issue);
//a redirect target is requested in the redirect cycle
assign instr_addr_o = waiting_q ? wait_pc_q : redirect_i ? redirect_pc_i : pc_q;

wire new_req = instr_req_o && !waiting_q;

always @(posedge clk_i or negedge rst_ni)
begin
    if(!rst_ni)
    begin
        pc_q <= RESET_VECTOR;
        outstanding_q <= 1'b0;
        out_pc_q <= 32'b0;
        drop_q <= 1'b0;
        waiting_q <= 1'b0;
        wait_pc_q <= 32'b0;
        stale_q <= 1'b0;
    end
    else
    begin
        if(redirect_i && !new_req)
            pc_q <= redirect_pc_i;
        else if(new_req)
            pc_q <= instr_addr_o + 32'd4;

        if(accept)
        begin
            outstanding_q <= 1'b1;
            out_pc_q <= instr_addr_o;
            drop_q <= waiting_q && (stale_q || redirect_i);
        end
        else if(resp)
        begin
            outstanding_q <= 1'b0;
            drop_q <= 1'b0;
        end
        else if(redirect_i && outstanding_q)
            drop_q <= 1'b1;

        waiting_q <= instr_req_o && !instr_gnt_i;
        if(new_req && !instr_gnt_i)
        begin
            wait_pc_q <= instr_addr_o;
            stale_q <= 1'b0;
        end
        else if(waiting_q && !instr_gnt_i && redirect_i)
            stale_q <= 1'b1;
    end
end

always @(posedge clk_i or negedge rst_ni)
begin
    if(!rst_ni)
    begin
        buf_valid_q <= 1'b0;
        buf_pc_q <= 32'b0;
        buf_instr_q <= 32'b0;
        buf_fault_q <= 1'b0;
        valid_o <= 1'b0;
        pc_o <= 32'b0;
        instr_o <= 32'h13;
        fault_o <= 1'b0;
    end
    else if(redirect_i)
    begin
        buf_valid_q <= 1'b0;
        valid_o <= 1'b0;
    end
    else if(stall_i)
    begin
        if(use_resp)
        begin
            buf_valid_q <= 1'b1;
            buf_pc_q <= out_pc_q;
            buf_instr_q <= instr_rdata_i;
            buf_fault_q <= instr_err_i;
        end
    end
    else if(buf_valid_q)
    begin
        valid_o <= 1'b1;
        pc_o <= buf_pc_q;
        instr_o <= buf_instr_q;
        fault_o <= buf_fault_q;
        buf_valid_q <= use_resp;
        buf_pc_q <= out_pc_q;
        buf_instr_q <= instr_rdata_i;
        buf_fault_q <= instr_err_i;
    end
    else
    begin
        valid_o <= use_resp;
        pc_o <= out_pc_q;
        instr_o <= instr_rdata_i;
        fault_o <= instr_err_i;
    end
end

endmodule
