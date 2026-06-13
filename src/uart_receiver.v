module uart_transmitter #(
    parameter CLOCK_FREQ = 100_000_000,
    parameter BAUD_RATE = 115_200)
(
    input clk,
    input reset,

    input [7:0] data_in,
    input data_in_valid,
    output data_in_ready,

    output serial_out
);
    // See diagram in the lab guide
    localparam  SYMBOL_EDGE_TIME    =   CLOCK_FREQ / BAUD_RATE;
    localparam  CLOCK_COUNTER_WIDTH =   $clog2(SYMBOL_EDGE_TIME);

    wire tx_active_value;
    wire [CLOCK_COUNTER_WIDTH-1:0] clock_counter_value;
    wire [3:0] bit_counter_value;
    wire [9:0] tx_shift_value;

    wire data_in_fire = data_in_valid & data_in_ready;
    wire symbol_edge  = (clock_counter_value == SYMBOL_EDGE_TIME - 1);
    wire done         = (bit_counter_value == 9) & symbol_edge;

    // 1. Transmission Active Flag
    REGISTER_R_CE #(.N(1), .INIT(0)) tx_active (
        .q(tx_active_value),
        .d(1'b1),
        .ce(data_in_fire),
        .rst(done | reset),
        .clk(clk)
    );

    // 2. Baud Rate Clock Counter
    REGISTER_R_CE #(.N(CLOCK_COUNTER_WIDTH), .INIT(0)) clock_counter (
        .q(clock_counter_value),
        .d(clock_counter_value + 1'b1),
        .ce(tx_active_value),
        .rst(symbol_edge | done | reset),
        .clk(clk)
    );

    // 3. Bit Counter (Tracks 10 bits: Start + 8 Data + Stop)
    REGISTER_R_CE #(.N(4), .INIT(0)) bit_counter (
        .q(bit_counter_value),
        .d(bit_counter_value + 1'b1),
        .ce(symbol_edge),
        .rst(done | reset),
        .clk(clk)
    );

    // 4. Shift Register
    wire [9:0] tx_shift_next = data_in_fire ? {1'b1, data_in, 1'b0} : {1'b1, tx_shift_value[9:1]};
    wire tx_shift_ce = data_in_fire | symbol_edge;

    REGISTER_CE #(.N(10)) tx_shift (
        .q(tx_shift_value),
        .d(tx_shift_next),
        .ce(tx_shift_ce),
        .clk(clk)
    );

    // 5. Output Assignments
    assign data_in_ready = ~tx_active_value;
    
    // UART rests high (1'b1). When active, output the LSB of the shift register.
    assign serial_out = tx_active_value ? tx_shift_value[0] : 1'b1;

endmodule