`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/11/2025 04:10:55 PM
// Design Name: 
// Module Name: gpio_wb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module gpio_wb(
               input         wb_cyc_i,
               input         wb_stb_i,
               input         wb_we_i,
               input [31:0]  wb_adr_i,
               input [31:0]  wb_dat_i,
               input [3:0]   wb_sel_i,
               output        wb_stall_o,
               output        wb_ack_o,
               output [31:0] wb_dat_o,
               output        wb_err_o,
               input         wb_rst_i,
               input         wb_clk_i,
               output trigger_o);



wire clk, rst;
reg stb, we;
reg [3:0] sel;
reg [31:0] adr,dat;

reg trigger;

assign clk = wb_clk_i;
assign rst = ~wb_rst_i;

assign wb_err_o = 1'b0;
assign wb_stall_o = 1'b0;
assign wb_ack_o = stb & wb_cyc_i;

assign trigger_o = trigger;

//input registers
always @(posedge clk or negedge rst)
begin
    if(!rst)
        {stb,we,sel,adr,dat} <= 70'b0; //Fixed from 69'b0 ?
    else
    begin
        stb <= wb_stb_i;
        we <= wb_we_i;
        sel <= wb_sel_i;
        adr <= wb_adr_i;
        dat <= wb_dat_i;
    end
end

always @(posedge clk or negedge rst)
begin
    if(!rst)
        trigger <= 0; //Fixed from 69'b0 ?
    else
    begin
        if(we & stb & sel[0]) begin
            trigger <= dat[0];
        end
        else trigger <= trigger;
    end
end





    
endmodule
