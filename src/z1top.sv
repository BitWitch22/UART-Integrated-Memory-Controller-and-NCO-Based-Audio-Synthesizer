module z1top #(
    parameter int CLOCK_FREQ = 100_000_000,
    parameter int BAUD_RATE  = 115_200,
    /* verilator lint_off REALCVT */
    // Sample the button signal every 500us
    parameter int B_SAMPLE_CNT_MAX = int'(0.0005 * CLOCK_FREQ),
    // The button is considered 'pressed' after 100ms of continuous pressing
    parameter int B_PULSE_CNT_MAX  = int'(0.100 / 0.0005),
    /* lint_on */
    parameter int CYCLES_PER_SECOND = 100_000_000
) (
    input  logic        CLK_100MHZ_FPGA,
    input  logic [3:0]  BUTTONS,
    input  logic [1:0]  SWITCHES,
    output logic [5:0]  LEDS,
    output logic        AUD_PWM,
    output logic        AUD_SD,
    input  logic        FPGA_SERIAL_RX,
    output logic        FPGA_SERIAL_TX
);
    
    logic [2:0] buttons_pressed;
    logic       reset;
    logic [1:0] switches_sync;
    
    button_parser #(
        .WIDTH(4),
        .SAMPLE_CNT_MAX(B_SAMPLE_CNT_MAX),
        .PULSE_CNT_MAX(B_PULSE_CNT_MAX)
    ) bp (
        .clk(CLK_100MHZ_FPGA),
        .in(BUTTONS),
        .out({buttons_pressed, reset})
    );

    synchronizer #(.WIDTH(2)) switch_sync (
        .clk(CLK_100MHZ_FPGA),
        .async_signal(SWITCHES),
        .sync_signal(switches_sync)
    );

    logic [7:0] data_in, data_out;
    logic       data_in_valid, data_in_ready, data_out_valid, data_out_ready;

    //---------------------- LED OUTPUT ---------------------
    logic [5:0] fl_leds, mem_state_leds;
    assign LEDS = switches_sync[0] ? fl_leds : mem_state_leds;

    //------------------------- UART ---------------------------
    uart #(.CLOCK_FREQ(CLOCK_FREQ), .BAUD_RATE(BAUD_RATE)) 
    on_chip_uart (
        .clk(CLK_100MHZ_FPGA),
        .reset(reset),
        .data_in(data_in),
        .data_in_valid(data_in_valid),
        .data_in_ready(data_in_ready),
        .data_out(data_out),
        .data_out_valid(data_out_valid),
        .data_out_ready(data_out_ready),
        .serial_in(FPGA_SERIAL_RX),
        .serial_out(FPGA_SERIAL_TX)
    );

    //------------------------- RX FIFO ---------------------------
    logic rx_fifo_full, rx_fifo_empty;
    logic [7:0] rx_dout;
    logic rx_rd_en, fl_rx_rd_en, mem_rx_rd_en;

    assign data_out_ready = ~rx_fifo_full;
    assign rx_rd_en       = switches_sync[0] ? fl_rx_rd_en : mem_rx_rd_en;

    fifo #(.WIDTH(8), .DEPTH(8)) 
    rx_fifo (
        .clk(CLK_100MHZ_FPGA), .rst(reset),
        .wr_en(data_out_valid && ~rx_fifo_full),
        .din(data_out),
        .full(rx_fifo_full),
        .rd_en(rx_rd_en),
        .dout(rx_dout),
        .empty(rx_fifo_empty)
    );

    //------------------------- TX FIFO ---------------------------
    logic [7:0] tx_din, fl_din, mem_din;
    logic tx_fifo_full, tx_fifo_empty, tx_fifo_empty_delayed;
    logic tx_wr_en, fl_tx_wr_en, mem_tx_wr_en;

    assign tx_din  = switches_sync[0] ? fl_din : mem_din;
    assign tx_wr_en = switches_sync[0] ? fl_tx_wr_en : mem_tx_wr_en;
    
    REGISTER #(.N(1)) tx_delay_reg (
        .q(tx_fifo_empty_delayed),
        .d(tx_fifo_empty),
        .clk(CLK_100MHZ_FPGA)
    );
    
    assign data_in_valid = ~tx_fifo_empty_delayed;

    fifo #(.WIDTH(8), .DEPTH(8)) 
    tx_fifo (
        .clk(CLK_100MHZ_FPGA), .rst(reset),
        .wr_en(tx_wr_en),
        .din(tx_din),
        .full(tx_fifo_full),
        .rd_en(data_in_ready && ~tx_fifo_empty),
        .dout(data_in),
        .empty(tx_fifo_empty)
    );

    //------------------------- MEM CONTROLLER ---------------------------
    mem_controller #(.FIFO_WIDTH(8)) 
    mem_ctrl (
        .clk(CLK_100MHZ_FPGA), .rst(reset),
        .rx_fifo_empty(rx_fifo_empty),
        .tx_fifo_full(tx_fifo_full),
        .din(rx_dout),     
        .rx_fifo_rd_en(mem_rx_rd_en),
        .tx_fifo_wr_en(mem_tx_wr_en),
        .dout(mem_din),
        .state_leds(mem_state_leds)
    );

endmodule