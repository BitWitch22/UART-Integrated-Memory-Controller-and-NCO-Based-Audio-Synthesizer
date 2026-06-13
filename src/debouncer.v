module debouncer #(
    parameter WIDTH              = 1,
    parameter SAMPLE_CNT_MAX     = 62500,
    parameter PULSE_CNT_MAX      = 200,
    parameter WRAPPING_CNT_WIDTH = $clog2(SAMPLE_CNT_MAX),
    parameter SAT_CNT_WIDTH      = $clog2(PULSE_CNT_MAX) + 1
) (
    input clk,
    input [WIDTH-1:0] glitchy_signal,
    output [WIDTH-1:0] debounced_signal
);

    // 1. Wrapping Counter (The Sample Timer)
    // Continuously counts up to SAMPLE_CNT_MAX-1 and generates a single-cycle pulse.
    wire [WRAPPING_CNT_WIDTH-1:0] wrap_cnt_val;
    wire sample_pulse = (wrap_cnt_val == SAMPLE_CNT_MAX - 1);

    REGISTER_R_CE #(.N(WRAPPING_CNT_WIDTH), .INIT(0)) wrap_counter (
        .q(wrap_cnt_val),
        .d(wrap_cnt_val + 1'b1),
        .ce(1'b1),              // Always enabled
        .rst(sample_pulse),     // Resets to 0 when max is reached
        .clk(clk)
    );

    // 2. Saturating Counters
    // Generates a separate counter for every bit of the glitchy_signal bus.
    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : debouncer_gen
            wire [SAT_CNT_WIDTH-1:0] sat_cnt_val;
            wire sat_max = (sat_cnt_val == PULSE_CNT_MAX);

            // If the max count is reached, hold the value. Otherwise, increment.
            wire [SAT_CNT_WIDTH-1:0] sat_cnt_next = sat_max ? sat_cnt_val : sat_cnt_val + 1'b1;

            REGISTER_R_CE #(.N(SAT_CNT_WIDTH), .INIT(0)) sat_counter (
                .q(sat_cnt_val),
                .d(sat_cnt_next),
                .ce(sample_pulse & glitchy_signal[i]), // Only increment on a sample tick if signal is high
                .rst(~glitchy_signal[i]),              // Reset instantly if the noisy signal drops low
                .clk(clk)
            );

            // Output goes high only when the counter reaches the required consecutive pulses
            assign debounced_signal[i] = sat_max;
        end
    endgenerate

endmodule