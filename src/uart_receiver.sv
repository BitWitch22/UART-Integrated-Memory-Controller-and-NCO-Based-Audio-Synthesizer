module uart_receiver #(
    parameter int CLOCK_FREQ = 100_000_000,
    parameter int BAUD_RATE  = 115_200
) (
    input  logic       clk,
    input  logic       reset,

    output logic [7:0] data_out,
    output logic       data_out_valid,
    input  logic       data_out_ready,

    input  logic       serial_in
);

    // Derived parameters
    localparam int SYMBOL_EDGE_TIME = CLOCK_FREQ / BAUD_RATE;
    localparam int SAMPLE_TIME      = SYMBOL_EDGE_TIME / 2;
    localparam int CLOCK_COUNTER_WIDTH = $clog2(SYMBOL_EDGE_TIME);

    // Internal signals using 'logic'
    logic [9:0] rx_shift_value;
    logic       rx_shift_ce;
    logic [3:0] bit_counter_value;
    logic       bit_counter_ce, bit_counter_rst;
    logic [CLOCK_COUNTER_WIDTH-1:0] clock_counter_value;
    logic       clock_counter_ce, clock_counter_rst;
    logic       has_byte, start;

    // 1. Shift Register
    assign rx_shift_ce = (clock_counter_value == SAMPLE_TIME - 1);
    
    REGISTER_CE #(.N(10)) rx_shift (
        .q(rx_shift_value),
        .d({serial_in, rx_shift_value[9:1]}), // Shift next logic
        .ce(rx_shift_ce),
        .clk(clk)
    );

    // 2. Bit Counter
    assign bit_counter_ce = (clock_counter_value == SYMBOL_EDGE_TIME - 1);
    assign bit_counter_rst = ((bit_counter_value == 9) && (clock_counter_value == SAMPLE_TIME - 1)) | reset;

    REGISTER_R_CE #(.N(4), .INIT(0)) bit_counter (
        .q(bit_counter_value),
        .d(bit_counter_value + 1'b1),
        .ce(bit_counter_ce),
        .rst(bit_counter_rst),
        .clk(clk)
    );

    // 3. Clock Counter
    assign clock_counter_ce = start;
    assign clock_counter_rst = (clock_counter_value == SYMBOL_EDGE_TIME - 1) | 
                               ((bit_counter_value == 9) && (clock_counter_value == SAMPLE_TIME - 1)) | 
                               reset;

    REGISTER_R_CE #(.N(CLOCK_COUNTER_WIDTH), .INIT(0)) clock_counter (
        .q(clock_counter_value),
        .d(clock_counter_value + 1'b1),
        .ce(clock_counter_ce),
        .rst(clock_counter_rst),
        .clk(clk)
    );

    // 4. Status Flags
    REGISTER_R_CE #(.N(1), .INIT(0)) has_byte_reg (
        .q(has_byte),
        .d(1'b1),
        .ce((bit_counter_value == 9) && (clock_counter_value == SAMPLE_TIME - 1)),
        .rst((data_out_valid & data_out_ready) | reset),
        .clk(clk)
    );

    REGISTER_R_CE #(.N(1), .INIT(0)) start_reg (
        .q(start),
        .d(1'b1),
        .ce((serial_in == 1'b0) && (bit_counter_value == 0)),
        .rst((bit_counter_value == 9) && (clock_counter_value == SAMPLE_TIME - 1)),
        .clk(clk)
    );

    // 5. Output Assignments
    assign data_out       = rx_shift_value[8:1];
    assign data_out_valid = has_byte;

endmodule