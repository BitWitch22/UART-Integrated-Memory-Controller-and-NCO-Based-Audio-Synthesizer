module synchronizer #(
    parameter int WIDTH = 1
) (
    input  logic             clk,
    input  logic [WIDTH-1:0] async_signal,
    output logic [WIDTH-1:0] sync_signal
);
    // Intermediate signal connecting the two flip-flop stages
    logic [WIDTH-1:0] stage1_out;

    // First stage: Captures the asynchronous input.
    // This flip-flop may go metastable if async_signal transitions on the clock edge.
    REGISTER #(.N(WIDTH)) stage1_reg (
        .q(stage1_out),
        .d(async_signal),
        .clk(clk)
    );

    // Second stage: Captures the output of the first stage.
    // Provides a full clock cycle for any metastability in stage1_out to settle.
    REGISTER #(.N(WIDTH)) stage2_reg (
        .q(sync_signal),
        .d(stage1_out),
        .clk(clk)
    );

endmodule