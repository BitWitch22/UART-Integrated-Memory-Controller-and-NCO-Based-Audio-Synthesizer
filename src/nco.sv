module nco(
    input clk,
    input rst,
    input [23:0] fcw,
    input next_sample,
    output [9:0] code
);

    // 1. Phase Accumulator
    // A 24-bit register that dictates where we are in the sine wave cycle.
    wire [23:0] phase_val;
    wire [23:0] phase_next = phase_val + fcw;

    REGISTER_R_CE #(.N(24), .INIT(0)) phase_acc (
        .q(phase_val),
        .d(phase_next),
        .ce(next_sample), // Only advance the phase when the DAC finishes its window
        .rst(rst),
        .clk(clk)
    );

    // 2. Sine Wave Lookup Table (ROM)
    // 256 entries (requiring an 8-bit address space), each 10 bits wide.
    reg [9:0] sine_rom [0:255];

    // Tell the synthesis tool to burn the sine.bin file into the FPGA's Block RAM
    initial begin
        $readmemb("sine.bin", sine_rom);
    end

    // 3. Output Assignment
    // We use the top 8 bits of the 24-bit phase accumulator to address the 256-entry ROM.
    // The larger the FCW, the faster these top 8 bits increment, resulting in a higher pitched note.
    assign code = sine_rom[phase_val[23:16]];

endmodule