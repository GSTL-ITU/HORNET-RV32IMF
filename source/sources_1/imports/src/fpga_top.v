`timescale 1ns/1ps

module fpga_top (
    input  wire M100_clk_i,
    input  wire rst_ni,
    input  wire rx_i,
    output wire tx_o,
    output wire uart_debug_stb,
    // output wire led0,
    // output wire led1,
    // output wire led3,
    output wire gpio_trigger_o
);

    // -------------------------------------------------------------------------
    // Parameters
    // -------------------------------------------------------------------------
    parameter SYS_CLK_FREQ = 25000000;
    parameter NUM_SLAVES   = 5;
    parameter MEMORY_INIT  = "memory_init.mem";
    parameter RAM_DEPTH    = 120000;

    // -------------------------------------------------------------------------
    // Internal Signals
    // -------------------------------------------------------------------------
    wire tx_o_tmp;
    wire loader_reset;
    wire reset;
    wire irq_ack_o;
    wire mtip;
    wire rx_irq_o;
    wire [7:0] rx_byte;

    assign tx_o = tx_o_tmp;
    // loader_reset is intentionally removed, since the loader FSM resets the core
    // whenever the UART sees 0x2D, 0x5F*, 0x70    
    assign reset = rst_ni;

    // Clocking
    wire clk_i, locked;

    clk_wiz_0 clkwiz0 (
        .clk_in1(M100_clk_i),
        .reset(1'b0),
        .locked(locked),
        .clk_out1(clk_i)
    );

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

    // Slave 3: UART
    assign slave_adr_begin[3] = 32'h1000_8010;
    assign slave_adr_end[3]   = 32'h1000_8013;

/*
    // Slave 4: Loader
    assign slave_adr_begin[4] = 32'h1000_8014;
    assign slave_adr_end[4]   = 32'h1000_8014;
*/

    // Slave 5: GPIO
    assign slave_adr_begin[4] = 32'h1000_8020;
    assign slave_adr_end[4]   = 32'h1000_8023;

    // -------------------------------------------------------------------------
    // Crossbar / Interconnect Logic
    // -------------------------------------------------------------------------

    // Instruction Bus to Slave 0 Mapping
    assign wb_cyc_i[0]   = inst_wb_cyc_o;
    assign wb_stb_i[0]   = inst_wb_stb_o;
    assign wb_we_i[0]    = inst_wb_we_o;
    assign wb_adr_i[0]   = inst_wb_adr_o;
    assign wb_dat_i[0]   = inst_wb_dat_o;
    assign wb_sel_i[0]   = inst_wb_sel_o;
    assign wb_rst_i[0]   = ~reset;
    assign wb_clk_i[0]   = clk_i;
    
    assign inst_wb_dat_i = wb_dat_o[0];
    assign inst_wb_err_i = wb_err_o[0];

    // Debug assignments
    assign uart_debug_stb = wb_stb_i[3];

    // Data Bus to Slaves 1 to (NUM_SLAVES-1) Mapping
    genvar i;
    generate
        for (i = 1; i < NUM_SLAVES; i = i + 1) begin : DATA_WB_MAP
            assign wb_cyc_i[i] = data_wb_cyc_o;
            assign wb_stb_i[i] = data_wb_stb_o & ((slave_adr_begin[i] <= wb_adr_i[i]) && (wb_adr_i[i] <= slave_adr_end[i]));
            assign wb_we_i[i]  = data_wb_we_o;
            assign wb_adr_i[i] = data_wb_adr_o;
            assign wb_dat_i[i] = data_wb_dat_o;
            assign wb_sel_i[i] = data_wb_sel_o;
            assign wb_clk_i[i] = clk_i;
            
            // Special reset condition for Loader (Slave 4)
            if (i == 4) begin
                assign wb_rst_i[i] = ~rst_ni;
            end else begin
                assign wb_rst_i[i] = ~reset;
            end
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
    integer     k;

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
    assign data_wb_rst_i   = ~reset;

    // -------------------------------------------------------------------------
    // Module Instantiations
    // -------------------------------------------------------------------------

    core_wb #(
        .reset_vector(32'h0)
    ) core0 (
        .clk_i(clk_i),
        .rst_ni(reset), // active-low reset

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
        .meip_i(1'b0),
        .mtip_i(mtip),
        .msip_i(1'b0),
        .fast_irq_i({15'b0, rx_irq_o}),
        .irq_ack_o(irq_ack_o)
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

    uart_wb #(
        .SYS_CLK_FREQ(SYS_CLK_FREQ), 
        .BAUD(115200)
    ) uart0_inst (
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
        .wb_clk_i(wb_clk_i[3]),

        .rx_i(rx_i),
        .tx_o(tx_o_tmp),
        .rx_byte_o(rx_byte),
        .rx_irq_o(rx_irq_o)
    );

/*
    loader_wb #(
        .SYS_CLK_FREQ(SYS_CLK_FREQ)
    ) loader0_inst (
        .wb_cyc_i(wb_cyc_i[4]),
        .wb_stb_i(wb_stb_i[4]),
        .wb_we_i(wb_we_i[4]),
        .wb_adr_i(wb_adr_i[4]),
        .wb_dat_i(wb_dat_i[4]),
        .wb_sel_i(wb_sel_i[4]),
        .wb_stall_o(wb_stall_o[4]),
        .wb_ack_o(wb_ack_o[4]),
        .wb_dat_o(wb_dat_o[4]),
        .wb_err_o(wb_err_o[4]),
        .wb_rst_i(wb_rst_i[4]),
        .wb_clk_i(wb_clk_i[4]),

        .uart_rx_irq(rx_irq_o),
        .uart_rx_byte(rx_byte),
        .reset_o(loader_reset),
        .led0(), 
        .led1(), 
        .led3()
    );
*/

    gpio_wb gpio_inst (
        .wb_cyc_i(wb_cyc_i[4]),
        .wb_stb_i(wb_stb_i[4]),
        .wb_we_i(wb_we_i[4]),
        .wb_adr_i(wb_adr_i[4]),
        .wb_dat_i(wb_dat_i[4]),
        .wb_sel_i(wb_sel_i[4]),
        .wb_stall_o(wb_stall_o[4]),
        .wb_ack_o(wb_ack_o[4]),
        .wb_dat_o(wb_dat_o[4]),
        .wb_err_o(wb_err_o[4]),
        .wb_rst_i(wb_rst_i[4]),
        .wb_clk_i(wb_clk_i[4]),
        .trigger_o(gpio_trigger_o)
    );

endmodule