module edge_detector #(
    parameter WIDTH = 1
)(
    input clk,
    input [WIDTH-1:0] signal_in,
    output [WIDTH-1:0] edge_detect_pulse
);

    // Wire to hold the value of the signal from the previous clock cycle
    wire [WIDTH-1:0] signal_delay;

    // Register to delay the input signal by exactly one clock cycle
    REGISTER #(.N(WIDTH)) delay_reg (
        .q(signal_delay),
        .d(signal_in),
        .clk(clk)
    );

    // A rising edge is detected when the current signal is HIGH (1) 
    // AND the previous clock cycle's signal was LOW (0).
    assign edge_detect_pulse = signal_in & ~signal_delay;

endmodule