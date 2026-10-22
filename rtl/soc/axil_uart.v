// UART 8N1 with 16-byte RX and TX FIFOs
//   0x00 DATA    write: send a byte; read: next received byte, bit 31 set when none
//   0x04 STATUS  [0] RX data  [1] TX full  [2] TX idle  [3] RX overrun  [4] frame error (write 1 to clear [4:3])
//   0x08 CTRL    [0] RX interrupt  [1] TX-empty interrupt
//   0x0C DIV     clock cycles per bit
module axil_uart #(parameter CLK_FREQ = 50000000,
                   parameter BAUD     = 115200)
(input             clk_i,
 input             rst_ni,

 input      [31:0] s_awaddr,
 input             s_awvalid,
 output            s_awready,
 input      [31:0] s_wdata,
 input      [3:0]  s_wstrb,
 input             s_wvalid,
 output            s_wready,
 output reg [1:0]  s_bresp,
 output reg        s_bvalid,
 input             s_bready,
 input      [31:0] s_araddr,
 input             s_arvalid,
 output            s_arready,
 output reg [31:0] s_rdata,
 output reg [1:0]  s_rresp,
 output reg        s_rvalid,
 input             s_rready,

 input             rx_i,
 output reg        tx_o,
 output            irq_o);

localparam integer DIV_RESET = CLK_FREQ / BAUD;

reg [15:0] div;
reg [1:0]  ctrl;
reg        overrun, frame_err;

wire wr = s_awvalid && s_wvalid && !s_bvalid;
wire rd = s_arvalid && !s_rvalid;
assign s_awready = wr;
assign s_wready  = wr;
assign s_arready = !s_rvalid;

//FIFOs
wire [7:0] tx_data, rx_data;
wire       tx_empty, tx_full, rx_empty, rx_full;
reg        tx_pop, rx_push;
reg  [7:0] rx_byte;
wire       tx_push = wr && s_awaddr[3:0] == 4'h0 && s_wstrb[0];
wire       rx_pop  = rd && s_araddr[3:0] == 4'h0;

sync_fifo #(.WIDTH(8), .DEPTH(16)) TX_FIFO(.clk_i(clk_i), .rst_ni(rst_ni), .push_i(tx_push), .data_i(s_wdata[7:0]),
                                           .pop_i(tx_pop), .data_o(tx_data), .empty_o(tx_empty), .full_o(tx_full));
sync_fifo #(.WIDTH(8), .DEPTH(16)) RX_FIFO(.clk_i(clk_i), .rst_ni(rst_ni), .push_i(rx_push), .data_i(rx_byte),
                                           .pop_i(rx_pop), .data_o(rx_data), .empty_o(rx_empty), .full_o(rx_full));

//transmitter
reg [15:0] tx_cnt;
reg [3:0]  tx_bit;
reg [8:0]  tx_shift;
reg        tx_busy;

always @(posedge clk_i or negedge rst_ni)
begin
    if(!rst_ni)
    begin
        tx_o <= 1'b1;
        tx_busy <= 1'b0;
        tx_cnt <= 16'b0;
        tx_bit <= 4'b0;
        tx_shift <= 9'h1ff;
        tx_pop <= 1'b0;
    end
    else
    begin
        tx_pop <= 1'b0;
        if(!tx_busy)
        begin
            if(!tx_empty && !tx_pop)
            begin
                tx_busy <= 1'b1;
                tx_pop <= 1'b1;
                tx_shift <= {1'b1, tx_data};
                tx_o <= 1'b0; //start bit
                tx_cnt <= div - 16'd1;
                tx_bit <= 4'd9;
            end
        end
        else if(tx_cnt != 16'b0)
            tx_cnt <= tx_cnt - 16'd1;
        else if(tx_bit == 4'd0)
            tx_busy <= 1'b0;
        else
        begin
            tx_o <= tx_shift[0];
            tx_shift <= {1'b1, tx_shift[8:1]};
            tx_bit <= tx_bit - 4'd1;
            tx_cnt <= div - 16'd1;
        end
    end
end

//receiver
reg [2:0]  rx_sync;
reg [15:0] rx_cnt;
reg [3:0]  rx_bit;
reg        rx_busy;
wire       rx_in = rx_sync[2];

always @(posedge clk_i or negedge rst_ni)
begin
    if(!rst_ni)
    begin
        rx_sync <= 3'b111;
        rx_busy <= 1'b0;
        rx_cnt <= 16'b0;
        rx_bit <= 4'b0;
        rx_byte <= 8'b0;
        rx_push <= 1'b0;
    end
    else
    begin
        rx_sync <= {rx_sync[1:0], rx_i};
        rx_push <= 1'b0;
        if(!rx_busy)
        begin
            if(!rx_in)
            begin
                rx_busy <= 1'b1;
                rx_cnt <= {1'b0, div[15:1]}; //middle of the start bit
                rx_bit <= 4'd0;
            end
        end
        else if(rx_cnt != 16'b0)
            rx_cnt <= rx_cnt - 16'd1;
        else
        begin
            rx_cnt <= div - 16'd1;
            rx_bit <= rx_bit + 4'd1;
            if(rx_bit == 4'd0)
            begin
                if(rx_in) //glitch, not a start bit
                    rx_busy <= 1'b0;
            end
            else if(rx_bit <= 4'd8)
                rx_byte <= {rx_in, rx_byte[7:1]};
            else
            begin
                rx_busy <= 1'b0;
                rx_push <= rx_in;
            end
        end
    end
end

assign irq_o = (ctrl[0] && !rx_empty) || (ctrl[1] && tx_empty);

wire rx_frame = rx_busy && rx_cnt == 16'b0 && rx_bit == 4'd9 && !rx_in;

always @(posedge clk_i or negedge rst_ni)
begin
    if(!rst_ni)
    begin
        div <= DIV_RESET[15:0];
        ctrl <= 2'b0;
        overrun <= 1'b0;
        frame_err <= 1'b0;
        s_bvalid <= 1'b0;
        s_bresp <= 2'b00;
        s_rvalid <= 1'b0;
        s_rresp <= 2'b00;
        s_rdata <= 32'b0;
    end
    else
    begin
        if(rx_push && rx_full)
            overrun <= 1'b1;
        if(rx_frame)
            frame_err <= 1'b1;

        if(s_bvalid && s_bready)
            s_bvalid <= 1'b0;
        if(wr)
        begin
            s_bvalid <= 1'b1;
            s_bresp <= 2'b00;
            case(s_awaddr[3:0])
                4'h0: ;
                4'h4: if(s_wstrb[0])
                      begin
                          if(s_wdata[3]) overrun <= 1'b0;
                          if(s_wdata[4]) frame_err <= 1'b0;
                      end
                4'h8: if(s_wstrb[0]) ctrl <= s_wdata[1:0];
                4'hC:
                begin
                    if(s_wstrb[0]) div[7:0] <= s_wdata[7:0];
                    if(s_wstrb[1]) div[15:8] <= s_wdata[15:8];
                end
                default: s_bresp <= 2'b10;
            endcase
        end

        if(s_rvalid && s_rready)
            s_rvalid <= 1'b0;
        if(rd)
        begin
            s_rvalid <= 1'b1;
            s_rresp <= 2'b00;
            case(s_araddr[3:0])
                4'h0: s_rdata <= rx_empty ? 32'h8000_0000 : {24'b0, rx_data};
                4'h4: s_rdata <= {27'b0, frame_err, overrun, tx_empty && !tx_busy, tx_full, !rx_empty};
                4'h8: s_rdata <= {30'b0, ctrl};
                4'hC: s_rdata <= {16'b0, div};
                default:
                begin
                    s_rdata <= 32'b0;
                    s_rresp <= 2'b10;
                end
            endcase
        end
    end
end

endmodule
