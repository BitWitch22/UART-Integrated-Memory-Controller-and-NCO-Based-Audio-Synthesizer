module debouncer #(
    parameter int WIDTH              = 1,
    parameter int SAMPLE_CNT_MAX     = 62500,
    parameter int PULSE_CNT_MAX      = 200,
    parameter int WRAPPING_CNT_WIDTH = $clog2(SAMPLE_CNT_MAX),
    parameter int SAT_CNT_WIDTH      = $clog2(PULSE_CNT_MAX) + 1
) (
    input  logic             clk,
    input  logic [WIDTH-1:0] glitchy_signal,
    output logic [WIDTH-1:0] debounced_signal
);

    // 1. Wrapping Counter (The Sample Timer)
    logic [WRAPPING_CNT_WIDTH-1:0] wrap_cnt_val;
    logic sample_pulse;

    assign sample_pulse = (wrap_cnt_val == SAMPLE_CNT_MAX - 1);

    REGISTER_R_CE #(.N(WRAPPING_CNT_WIDTH), .INIT(0)) wrap_counter (
        .q(wrap_cnt_val),
        .d(wrap_cnt_val + 1'b1),
        .ce(1'b1),
        .rst(sample_pulse),
        .clk(clk)
    );

    // 2. Saturating Counters
    genvar i;
    generate
        for (i = 0; i < WIDTH; i++) begin : gen_debouncer
            logic [SAT_CNT_WIDTH-1:0] sat_cnt_val;
            logic                     sat_max;
            logic [SAT_CNT_WIDTH-1:0] sat_cnt_next;

            assign sat_max      = (sat_cnt_val == PULSE_CNT_MAX);
            assign sat_cnt_next = sat_max ? sat_cnt_val : sat_cnt_val + 1'b1;

            REGISTER_R_CE #(.N(SAT_CNT_WIDTH), .INIT(0)) sat_counter (
                .q(sat_cnt_val),
                .d(sat_cnt_next),
                .ce(sample_pulse & glitchy_signal[i]), 
                .rst(~glitchy_signal[i]),              
                .clk(clk)
            );

            assign debounced_signal[i] = sat_max;
        end
    endgenerate

endmodule