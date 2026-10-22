`timescale 1ns/1ps

module barebones_top_tb();

reg rst_ni, clk_i;
wire irq_ack_o;
reg meip_i;
reg [15:0] fast_irq_i;
integer i;

barebones_wb_top uut(
    .rst_ni(rst_ni), 
    .clk_i(clk_i), 
    .meip_i(meip_i), 
    .fast_irq_i(fast_irq_i), 
    .irq_ack_o(irq_ack_o)
);

// 100 MHz clock
always begin
    clk_i = 1'b0; #12.5; clk_i = 1'b1; #12.5;
end

initial begin
    rst_ni = 1'b0; fast_irq_i = 16'b0; meip_i = 1'b0;
    
    // Changed for Vivado_2025.2++: memory_2rw_wb -> memory_inst
    for (i = 0; i < uut.memory_inst.RAM_DEPTH; i = i + 1) begin
        uut.memory_inst.mem[i] = {uut.memory_inst.DATA_WIDTH{1'b0}};  // Initialize to 0
    end
    
    #200;
    // Changed for Vivado_2025.2++: memory_2rw_wb -> memory_inst
    $readmemh("memory_init_tb.mem", uut.memory_inst.mem); // read data after reset, because reset initializes memory to 0
    
    #25;
    rst_ni = 1'b1; // Wait a cycle so that the instruction memory is ready
end

endmodule