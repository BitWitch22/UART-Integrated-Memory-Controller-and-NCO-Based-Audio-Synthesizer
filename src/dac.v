module dac #(
    parameter CYCLES_PER_WINDOW = 1024,
    parameter CODE_WIDTH = $clog2(CYCLES_PER_WINDOW)
)(
    input clk,
    input rst,
    input [CODE_WIDTH-1:0] code,
    output next_sample,
    output pwm
);

    wire [CODE_WIDTH-1:0] counter_val;
    wire [CODE_WIDTH-1:0] counter_next;

    // Flag to detect when we reach the end of the 1024-cycle window
    wire counter_max = (counter_val == CYCLES_PER_WINDOW - 1);

    // Wrapping counter: counts from 0 up to 1023, then rolls back to 0
    assign counter_next = counter_max ? 'd0 : counter_val + 1'b1;

    REGISTER_R #(.N(CODE_WIDTH), .INIT(0)) pwm_counter (
        .q(counter_val),
        .d(counter_next),
        .rst(rst),
        .clk(clk)
    );

    // 1. PWM Generation
    // The output stays HIGH as long as the counter is strictly less than the requested code.
    // E.g., if code is 512, the pin is HIGH for 512 cycles and LOW for 512 cycles (50% duty).
    assign pwm = (counter_val < code);

    // 2. Next Sample Trigger
    // When the window is complete, fire a 1-cycle pulse to tell the NCO to fetch the next sine value.
    assign next_sample = counter_max;

endmodule