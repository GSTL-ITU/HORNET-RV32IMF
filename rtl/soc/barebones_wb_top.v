module barebones_wb_top (
    input  wire        clk_i,
    input  wire        rst_ni,
    input  wire        meip_i,
    input  wire [15:0] fast_irq_i,
    output wire        irq_ack_o
);

    // -------------------------------------------------------------------------
    // Parameters
    // -------------------------------------------------------------------------
    parameter MEMORY_INIT  = "memory_init_tb.mem";
    parameter RAM_DEPTH    = 120000;
    parameter NUM_SLAVES   = 4;
    parameter reset_vector = 32'h0000_0000; // Starting address for the PC

    // -------------------------------------------------------------------------
    // Internal Signals
    // -------------------------------------------------------------------------
    wire mtip;

    // Wishbone master interface signals for data
    wire        data_wb_cyc_o;
    wire        data_wb_stb_o;
    wire        data_wb_we_o;
    wire [31:0] data_wb_adr_o;
    wire [31:0] data_wb_dat_o;
    wire [ 3:0] data_wb_sel_o;
    wire        data_wb_stall_i;
    wire        data_wb_ack_i;
    wire [31:0] data_wb_dat_i;
    wire        data_wb_err_i;
    wire        data_wb_rst_i;
    wire        data_wb_clk_i;

    // Wishbone master interface signals for instructions
    wire        inst_wb_cyc_o;
    wire        inst_wb_stb_o;
    wire        inst_wb_we_o;
    wire [31:0] inst_wb_adr_o;
    wire [31:0] inst_wb_dat_o;
    wire [ 3:0] inst_wb_sel_o;
    wire [31:0] inst_wb_dat_i;
    wire        inst_wb_err_i;

    // Wishbone slave signals for peripherals
    wire [NUM_SLAVES-1:0] wb_cyc_i;
    wire [NUM_SLAVES-1:0] wb_stb_i;
    wire [NUM_SLAVES-1:0] wb_we_i;
    wire [31:0]           wb_adr_i [NUM_SLAVES-1:0];
    wire [31:0]           wb_dat_i [NUM_SLAVES-1:0];
    wire [ 3:0]           wb_sel_i [NUM_SLAVES-1:0];
    wire [NUM_SLAVES-1:0] wb_stall_o;
    wire [NUM_SLAVES-1:0] wb_ack_o;
    wire [31:0]           wb_dat_o [NUM_SLAVES-1:0];
    wire [NUM_SLAVES-1:0] wb_err_o;
    wire [NUM_SLAVES-1:0] wb_rst_i;
    wire [NUM_SLAVES-1:0] wb_clk_i;

    reg  [NUM_SLAVES-1:0] r_stb;

    // -------------------------------------------------------------------------
    // Address Mapping
    // -------------------------------------------------------------------------
    wire [31:0] slave_adr_begin [NUM_SLAVES-1:0];
    wire [31:0] slave_adr_end   [NUM_SLAVES-1:0];

    // Slave 0: Instruction Memory
    assign slave_adr_begin[0] = 32'h0000_0000;
    assign slave_adr_end[0]   = 32'h1000_0000;

    // Slave 1: Data Memory
    assign slave_adr_begin[1] = 32'h0000_0000;
    assign slave_adr_end[1]   = 32'h1000_0000;

    // Slave 2: mtime Registers
    assign slave_adr_begin[2] = 32'h1000_8000;
    assign slave_adr_end[2]   = 32'h1000_800F;

    // Slave 3: Debug Interface
    assign slave_adr_begin[3] = 32'h1000_8010;
    assign slave_adr_end[3]   = 32'h1000_8010;

    // -------------------------------------------------------------------------
    // Crossbar / Interconnect Logic
    // -------------------------------------------------------------------------
    
    // Instruction Bus to Slave 0 Mapping
    assign wb_cyc_i[0] = inst_wb_cyc_o;
    assign wb_stb_i[0] = inst_wb_stb_o && ((slave_adr_begin[0] <= wb_adr_i[0]) && (wb_adr_i[0] <= slave_adr_end[0])); 
    assign wb_we_i[0]  = inst_wb_we_o;
    assign wb_adr_i[0] = inst_wb_adr_o;
    assign wb_dat_i[0] = inst_wb_dat_o;
    assign wb_sel_i[0] = inst_wb_sel_o;
    assign wb_rst_i[0] = ~rst_ni;
    assign wb_clk_i[0] = clk_i;
    
    assign inst_wb_dat_i = wb_dat_o[0];
    assign inst_wb_err_i = wb_err_o[0];

    // Data Bus to Slaves 1 to (NUM_SLAVES-1) Mapping
    genvar i;
    generate
        for (i = 1; i < NUM_SLAVES; i = i + 1) begin : DATA_WB_MAP
            assign wb_cyc_i[i] = data_wb_cyc_o;
            assign wb_stb_i[i] = data_wb_stb_o && ((slave_adr_begin[i] <= wb_adr_i[i]) && (wb_adr_i[i] <= slave_adr_end[i]));
            assign wb_we_i[i]  = data_wb_we_o;
            assign wb_adr_i[i] = data_wb_adr_o;
            assign wb_dat_i[i] = data_wb_dat_o;
            assign wb_sel_i[i] = data_wb_sel_o;
            assign wb_rst_i[i] = ~rst_ni;
            assign wb_clk_i[i] = clk_i;
        end
    endgenerate

    // Register strobe signals
    always @(posedge wb_clk_i[0] or posedge wb_rst_i[0]) begin
        if (wb_rst_i[0])
            r_stb <= 0;
        else
            r_stb <= wb_stb_i;
    end

    // Muxing Slave outputs back to the Data Master
    reg [31:0] r_data_wb_dat_i;
    reg        r_data_wb_err_i;
    reg        r_data_wb_stall_i;
    reg        r_data_wb_ack_i;
    reg        slave_match;
    integer    k;

    always @(*) begin
        // Default assignments to prevent latches
        slave_match       = 1'b0;
        r_data_wb_dat_i   = 32'b0;
        r_data_wb_stall_i = 1'b0;
        r_data_wb_err_i   = 1'b0;
        r_data_wb_ack_i   = 1'b0;

        for (k = 1; k < NUM_SLAVES; k = k + 1) begin
            if (!slave_match) begin
                if (r_stb[k]) begin
                    r_data_wb_dat_i   = wb_dat_o[k];
                    r_data_wb_stall_i = wb_stall_o[k];
                    r_data_wb_err_i   = wb_err_o[k];
                    r_data_wb_ack_i   = wb_ack_o[k];
                    slave_match       = 1'b1;
                end
            end
        end
    end

    assign data_wb_dat_i   = r_data_wb_dat_i;
    assign data_wb_ack_i   = r_data_wb_ack_i;
    assign data_wb_stall_i = r_data_wb_stall_i;
    assign data_wb_err_i   = r_data_wb_err_i;
    assign data_wb_clk_i   = clk_i;
    assign data_wb_rst_i   = ~rst_ni;

    // -------------------------------------------------------------------------
    // Tracer Signals
    // -------------------------------------------------------------------------
    wire [31:0] tr_mem_data, tr_mem_addr, tr_reg_data, tr_pc, tr_instr, fflags;
    wire [ 4:0] tr_reg_addr;
    wire [ 1:0] tr_mem_len;
    wire        tr_valid, tr_store, tr_load, tr_is_float;

    // -------------------------------------------------------------------------
    // Module Instantiations
    // -------------------------------------------------------------------------

    core_wb #(.reset_vector(reset_vector)) core0 (
        .rst_ni(rst_ni),
        .clk_i(clk_i),

        // Wishbone interface for data memory
        .data_wb_cyc_o(data_wb_cyc_o),
        .data_wb_stb_o(data_wb_stb_o),
        .data_wb_we_o(data_wb_we_o),
        .data_wb_adr_o(data_wb_adr_o),
        .data_wb_dat_o(data_wb_dat_o),
        .data_wb_sel_o(data_wb_sel_o),
        .data_wb_stall_i(data_wb_stall_i),
        .data_wb_ack_i(data_wb_ack_i),
        .data_wb_dat_i(data_wb_dat_i),
        .data_wb_err_i(data_wb_err_i),
        .data_wb_rst_i(data_wb_rst_i),
        .data_wb_clk_i(data_wb_clk_i),

        // Wishbone interface for instruction memory
        .inst_wb_cyc_o(inst_wb_cyc_o),
        .inst_wb_stb_o(inst_wb_stb_o),
        .inst_wb_we_o(inst_wb_we_o),
        .inst_wb_adr_o(inst_wb_adr_o),
        .inst_wb_dat_o(inst_wb_dat_o),
        .inst_wb_sel_o(inst_wb_sel_o),
        .inst_wb_dat_i(inst_wb_dat_i),
        .inst_wb_err_i(inst_wb_err_i),

        // Interrupts
        .meip_i(meip_i),
        .mtip_i(mtip),
        .msip_i(1'b0),
        .fast_irq_i(fast_irq_i),
        .irq_ack_o(irq_ack_o),        

        // Tracer
        .tr_mem_data(tr_mem_data),
        .tr_mem_addr(tr_mem_addr),
        .tr_reg_data(tr_reg_data),
        .tr_pc(tr_pc),
        .tr_instr(tr_instr),
        .tr_reg_addr(tr_reg_addr),
        .tr_mem_len(tr_mem_len),
        .tr_valid(tr_valid),
        .tr_load(tr_load),
        .tr_store(tr_store),
        .tr_is_float(tr_is_float),
        .fflags(fflags)
    );

    tracer tracer_inst (
        .clk_i(clk_i),
        .valid(tr_valid),
        .pc(tr_pc),
        .instr(tr_instr),
        .reg_addr(tr_reg_addr),
        .reg_data(tr_reg_data),
        .is_load(tr_load),
        .is_store(tr_store),
        .is_float(tr_is_float),
        .mem_size(tr_mem_len),
        .mem_addr(tr_mem_addr),
        .mem_data(tr_mem_data),
        .fpu_flags(fflags)
    );

    memory_2rw_wb #(
        .RAM_DEPTH(RAM_DEPTH), 
        .MEMORY_INIT(MEMORY_INIT)
    ) memory_inst (
        .port0_wb_cyc_i(wb_cyc_i[0]),
        .port0_wb_stb_i(wb_stb_i[0]),
        .port0_wb_we_i(wb_we_i[0]),
        .port0_wb_adr_i(wb_adr_i[0]),
        .port0_wb_dat_i(wb_dat_i[0]),
        .port0_wb_sel_i(wb_sel_i[0]),
        .port0_wb_stall_o(wb_stall_o[0]),
        .port0_wb_ack_o(wb_ack_o[0]),
        .port0_wb_dat_o(wb_dat_o[0]),
        .port0_wb_err_o(wb_err_o[0]),
        .port0_wb_rst_i(wb_rst_i[0]),
        .port0_wb_clk_i(wb_clk_i[0]),

        .port1_wb_cyc_i(wb_cyc_i[1]),
        .port1_wb_stb_i(wb_stb_i[1]),
        .port1_wb_we_i(wb_we_i[1]),
        .port1_wb_adr_i(wb_adr_i[1]),
        .port1_wb_dat_i(wb_dat_i[1]),
        .port1_wb_sel_i(wb_sel_i[1]),
        .port1_wb_stall_o(wb_stall_o[1]),
        .port1_wb_ack_o(wb_ack_o[1]),
        .port1_wb_dat_o(wb_dat_o[1]),
        .port1_wb_err_o(wb_err_o[1]),
        .port1_wb_rst_i(wb_rst_i[1]),
        .port1_wb_clk_i(wb_clk_i[1])
    );

    mtime_registers_wb #(
        .mtime_adr(32'h1000_8000),
        .mtimecmp_adr(32'h1000_8008)
    ) mtime_regs_inst (
        .wb_cyc_i(wb_cyc_i[2]),
        .wb_stb_i(wb_stb_i[2]),
        .wb_we_i(wb_we_i[2]),
        .wb_adr_i(wb_adr_i[2]),
        .wb_dat_i(wb_dat_i[2]),
        .wb_sel_i(wb_sel_i[2]),
        .wb_stall_o(wb_stall_o[2]),
        .wb_ack_o(wb_ack_o[2]),
        .wb_dat_o(wb_dat_o[2]),
        .wb_err_o(wb_err_o[2]),
        .wb_rst_i(wb_rst_i[2]),
        .wb_clk_i(wb_clk_i[2]),
        .mtip_o(mtip)
    );

    debug_interface_wb debug_if_inst (
        .wb_cyc_i(wb_cyc_i[3]),
        .wb_stb_i(wb_stb_i[3]),
        .wb_we_i(wb_we_i[3]),
        .wb_adr_i(wb_adr_i[3]),
        .wb_dat_i(wb_dat_i[3]),
        .wb_sel_i(wb_sel_i[3]),
        .wb_stall_o(wb_stall_o[3]),
        .wb_ack_o(wb_ack_o[3]),
        .wb_dat_o(wb_dat_o[3]),
        .wb_err_o(wb_err_o[3]),
        .wb_rst_i(wb_rst_i[3]),
        .wb_clk_i(wb_clk_i[3])
    );

endmodule