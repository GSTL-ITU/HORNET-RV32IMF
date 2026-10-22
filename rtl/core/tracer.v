module tracer(input clk_i,
                input valid,
                input [31:0] pc,
                input [31:0] instr,
                input [4:0] reg_addr,
                input [31:0] reg_data,
                input is_load, is_store, is_float,
                input [1:0] mem_size,
                input [31:0] mem_addr,
                input [31:0] mem_data,
                input [31:0] fpu_flags);
// This module is used to trace the execution of the processor. It writes the PC, instruction, register address, register data, memory write enable, memory address and memory data to a file.


integer file_pointer;

initial begin
file_pointer = $fopen("../../../../../trace.log", "w"); //The file is normally located in <vivado-dir>\HornetRISCV-vivado.sim\sim_1\behav\xsim, so let's use relative path to move it to the main folder
    forever begin
        @(posedge valid); //This is required otherwise testbench ignores the update signal
        $fwrite(file_pointer, "0x%8h (0x%8h)", pc, instr);
        if (is_store) begin
            if(mem_size == 2'b00) begin
                $fwrite(file_pointer, " mem 0x%8h 0x%2h", mem_addr, mem_data);
            end
            else if(mem_size == 2'b01) begin
                $fwrite(file_pointer, " mem 0x%8h 0x%4h", mem_addr, mem_data);
            end
            else begin
                $fwrite(file_pointer, " mem 0x%8h 0x%8h", mem_addr, mem_data);
            end
        end
        else begin
            if (!is_float) begin
                if (reg_addr == 0) begin
                    //$fwrite(file_pointer, "0x%8h (0x%8h)", pc, instr); Do nothing, as we moved the pc/instr writing out of the if-else tree
                end else begin
                    if (reg_addr > 9) begin
                        $fwrite(file_pointer, " x%0d 0x%8h", reg_addr, reg_data);
                        if (is_load) begin
                            $fwrite(file_pointer, " mem 0x%8h", mem_addr);
                        end
                    end else begin
                        $fwrite(file_pointer, " x%0d  0x%8h", reg_addr, reg_data);
                        if (is_load) begin
                            $fwrite(file_pointer, " mem 0x%8h", mem_addr);
                        end
                    end
                end
            end
            else begin
                if (fpu_flags != 0) $fwrite(file_pointer, " c1_fflags 0x%8h", fpu_flags);

                if (reg_addr > 9) begin
                    $fwrite(file_pointer, " f%0d 0x%8h", reg_addr, reg_data);
                    if (is_load) begin
                        $fwrite(file_pointer, " mem 0x%8h", mem_addr);
                    end
                end else begin
                    $fwrite(file_pointer, " f%0d  0x%8h", reg_addr, reg_data);
                    if (is_load) begin
                        $fwrite(file_pointer, " mem 0x%8h", mem_addr);
                    end
                end
            end
        end
        $fwrite(file_pointer, "\n");
    end
end

endmodule