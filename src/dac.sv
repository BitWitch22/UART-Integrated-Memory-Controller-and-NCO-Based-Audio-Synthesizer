module dac #(
    parameter int CYCLES_PER_WINDOW = 1024,
    parameter int CODE_WIDTH = $clog2(CYCLES_PER_WINDOW)
)(
    input  logic                   clk,
    input  logic                   rst,
    input  logic [CODE_WIDTH-1:0]  code,
    output logic                   next_sample,
    output logic                   pwm
);

    logic [CODE_WIDTH-1:0] counter_val;
    logic [CODE_WIDTH-1:0] counter_next;

    // Flag to detect when we reach the end of the 1024-cycle window
    logic counter_max;
    assign counter_max = (counter_val == CYCLES_PER_WINDOW - 1);

    // Wrapping counter: counts from 0 up to 1023, then rolls back to 0
    assign counter_next = counter_max ? '0 : counter_val + 1'b1;

    REGISTER_R #(.N(CODE_WIDTH), .INIT(0)) pwm_counter (
        .q(counter_val),
        .d(counter_next),
        .rst(rst),
        .clk(clk)
    );

    // 1. PWM Generation
    // The output stays HIGH as long as the counter is strictly less than the requested code.
    assign pwm = (counter_val < code);

    // 2. Next Sample Trigger
    // When the window is complete, fire a pulse to trigger the next NCO sample.
    assign next_sample = counter_max;

endmodule