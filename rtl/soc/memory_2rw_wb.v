module memory_2rw_wb #(
    parameter NUM_WMASKS  = 4,
    parameter DATA_WIDTH  = 32,
    parameter RAM_DEPTH   = 120000,
    parameter ADDR_WIDTH  = $clog2(RAM_DEPTH),
    parameter MEMORY_INIT = "memory_init_tb.mem"
) (
    // ---------------------------------------------------------
    // Port 0 Interface
    // ---------------------------------------------------------
    input  wire                   port0_wb_cyc_i,
    input  wire                   port0_wb_stb_i,
    input  wire                   port0_wb_we_i,
    input  wire [31:0]            port0_wb_adr_i,
    input  wire [31:0]            port0_wb_dat_i,
    input  wire [ 3:0]            port0_wb_sel_i,
    output wire                   port0_wb_stall_o,
    output wire                   port0_wb_ack_o,
    output reg  [31:0]            port0_wb_dat_o,
    output wire                   port0_wb_err_o,
    input  wire                   port0_wb_rst_i,
    input  wire                   port0_wb_clk_i,

    // ---------------------------------------------------------
    // Port 1 Interface
    // ---------------------------------------------------------
    input  wire                   port1_wb_cyc_i,
    input  wire                   port1_wb_stb_i,
    input  wire                   port1_wb_we_i,
    input  wire [31:0]            port1_wb_adr_i,
    input  wire [31:0]            port1_wb_dat_i,
    input  wire [ 3:0]            port1_wb_sel_i,
    output wire                   port1_wb_stall_o,
    output wire                   port1_wb_ack_o,
    output reg  [31:0]            port1_wb_dat_o,
    output wire                   port1_wb_err_o,
    input  wire                   port1_wb_rst_i,
    input  wire                   port1_wb_clk_i
);

    // =========================================================
    // Internal Signals & Memory Array
    // =========================================================

    // Port 0 Internal Signals
    wire                      clk0;       // Clock
    wire                      cs0;        // Active-low chip select
    wire                      we0;        // Active-low write control
    wire [NUM_WMASKS-1:0]     wmask0;     // Write mask
    wire [ADDR_WIDTH-1:0]     addr0;      // Word-aligned address
    wire [DATA_WIDTH-1:0]     din0;       // Data in
    reg                       port0_ack;  // Acknowledge register

    // Port 1 Internal Signals
    wire                      clk1;       // Clock
    wire                      cs1;        // Active-low chip select
    wire                      we1;        // Active-low write control
    wire [NUM_WMASKS-1:0]     wmask1;     // Write mask
    wire [ADDR_WIDTH-1:0]     addr1;      // Word-aligned address
    wire [DATA_WIDTH-1:0]     din1;       // Data in
    reg                       port1_ack;  // Acknowledge register

    // Main Memory Array (Verilator public for simulation access)
    reg  [DATA_WIDTH-1:0]     mem [0:RAM_DEPTH-1] /*verilator public*/;


    // =========================================================
    // Port 0 Assignments & Logic
    // =========================================================
    
    assign clk0             = port0_wb_clk_i;
    assign cs0              = ~port0_wb_stb_i;
    assign we0              = ~port0_wb_we_i;
    assign wmask0           = port0_wb_sel_i;
    assign addr0            = port0_wb_adr_i[20:2];
    assign din0             = port0_wb_dat_i;
    
    assign port0_wb_stall_o = 1'b0;
    assign port0_wb_ack_o   = port0_ack;
    assign port0_wb_err_o   = 1'b0;

    // Port 0 Acknowledge Block
    always @(posedge port0_wb_clk_i or posedge port0_wb_rst_i) begin
        if (port0_wb_rst_i) begin
            port0_ack <= 1'b0;
        end else if (port0_wb_cyc_i) begin
            port0_ack <= port0_wb_stb_i;
        end
    end


    // =========================================================
    // Port 1 Assignments & Logic
    // =========================================================
    
    assign clk1             = port1_wb_clk_i;
    assign cs1              = ~port1_wb_stb_i;
    assign we1              = ~port1_wb_we_i;
    assign wmask1           = port1_wb_sel_i;
    assign addr1            = port1_wb_adr_i[20:2];
    assign din1             = port1_wb_dat_i;
    
    assign port1_wb_stall_o = 1'b0;
    assign port1_wb_ack_o   = port1_ack;
    assign port1_wb_err_o   = 1'b0;

    // Port 1 Acknowledge Block (Async memory reset removed for Vivado BRAM compatibility)
    always @(posedge port1_wb_clk_i or posedge port1_wb_rst_i) begin
        if (port1_wb_rst_i) begin
            port1_ack <= 1'b0; 
        end else if (port1_wb_cyc_i) begin
            port1_ack <= port1_wb_stb_i;
        end
    end


    // =========================================================
    // Memory Initialization & Read/Write Blocks
    // =========================================================

    // Initialize memory at power-up from file
    initial begin
        $readmemh(MEMORY_INIT, mem);
    end

    // Port 0 Write Operation (cs0 = 0, we0 = 0)
    always @(posedge clk0) begin
        if (!cs0 && !we0) begin
            if (wmask0[0]) mem[addr0][ 7: 0] <= din0[ 7: 0];
            if (wmask0[1]) mem[addr0][15: 8] <= din0[15: 8];
            if (wmask0[2]) mem[addr0][23:16] <= din0[23:16];
            if (wmask0[3]) mem[addr0][31:24] <= din0[31:24];
        end
    end

    // Port 0 Read Operation (cs0 = 0, we0 = 1)
    always @(posedge clk0) begin
        if (!cs0 && we0) begin
            port0_wb_dat_o <= mem[addr0];
        end
    end

    // Port 1 Write Operation (cs1 = 0, we1 = 0)
    always @(posedge clk1) begin
        if (!cs1 && !we1) begin
            if (wmask1[0]) mem[addr1][ 7: 0] <= din1[ 7: 0];
            if (wmask1[1]) mem[addr1][15: 8] <= din1[15: 8];
            if (wmask1[2]) mem[addr1][23:16] <= din1[23:16];
            if (wmask1[3]) mem[addr1][31:24] <= din1[31:24];
        end
    end

    // Port 1 Read Operation (cs1 = 0, we1 = 1)
    always @(posedge clk1) begin : MEM_READ1
        if (!cs1 && we1) begin
            port1_wb_dat_o <= mem[addr1];
        end
    end

endmodule