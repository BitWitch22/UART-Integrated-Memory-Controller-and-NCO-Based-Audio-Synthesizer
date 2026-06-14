module uart #(
    parameter int CLOCK_FREQ = 100_000_000,
    parameter int BAUD_RATE  = 115_200
) (
    input  logic       clk,
    input  logic       reset,

    input  logic [7:0] data_in,
    input  logic       data_in_valid,
    output logic       data_in_ready,

    output logic [7:0] data_out,
    output logic       data_out_valid,
    input  logic       data_out_ready,

    input  logic       serial_in,
    output logic       serial_out
);

    logic serial_in_reg;
    logic serial_out_reg;
    logic serial_out_tx;

    assign serial_out = serial_out_reg;

    // UART rests high (1'b1), so the INIT state must be 1'b1.
    REGISTER_R #(.N(1), .INIT(1'b1)) serial_out_register (
        .q(serial_out_reg),
        .d(serial_out_tx),
        .rst(reset),
        .clk(clk)
    );

    REGISTER_R #(.N(1), .INIT(1'b1)) serial_in_register (
        .q(serial_in_reg),
        .d(serial_in),
        .rst(reset),
        .clk(clk)
    );

    uart_transmitter #(
        .CLOCK_FREQ(CLOCK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) uatransmit (
        .clk(clk),
        .reset(reset),
        .data_in(data_in),
        .data_in_valid(data_in_valid),
        .data_in_ready(data_in_ready),
        .serial_out(serial_out_tx)
    );

    uart_receiver #(
        .CLOCK_FREQ(CLOCK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) uareceive (
        .clk(clk),
        .reset(reset),
        .data_out(data_out),
        .data_out_valid(data_out_valid),
        .data_out_ready(data_out_ready),
        .serial_in(serial_in_reg)
    );

endmodule