`ifndef EECS151_SV
`define EECS151_SV

`timescale 1ns/1ps

// Register of D-Type Flip-flops
module REGISTER #(parameter int N = 1) (
    input  logic [N-1:0] d,
    input  logic         clk,
    output logic [N-1:0] q
);
    initial q = '0;
    always_ff @(posedge clk) q <= d;
endmodule

// Register with clock enable
module REGISTER_CE #(parameter int N = 1) (
    input  logic [N-1:0] d,
    input  logic         ce, clk,
    output logic [N-1:0] q
);
    initial q = '0;
    always_ff @(posedge clk) if (ce) q <= d;
endmodule

// Register with reset value
module REGISTER_R #(
    parameter int N = 1,
    parameter logic [N-1:0] INIT = '0
) (
    input  logic [N-1:0] d,
    input  logic         rst, clk,
    output logic [N-1:0] q
);
    initial q = INIT;
    always_ff @(posedge clk) begin
        if (rst) q <= INIT;
        else     q <= d;
    end
endmodule

// Register with reset and clock enable
module REGISTER_R_CE #(
    parameter int N = 1,
    parameter logic [N-1:0] INIT = '0
) (
    input  logic [N-1:0] d,
    input  logic         rst, ce, clk,
    output logic [N-1:0] q
);
    initial q = INIT;
    always_ff @(posedge clk) begin
        if (rst)      q <= INIT;
        else if (ce)  q <= d;
    end
endmodule

// Note: For memory modules, modern synthesis tools prefer 
// standard inference patterns. The following preserves your 
// specific distributed/block RAM style attributes.

module SYNC_RAM_WBE #(
    parameter int DWIDTH = 8,
    parameter int AWIDTH = 8,
    parameter int DEPTH  = (1 << AWIDTH)
) (
    input  logic              clk, en,
    input  logic [AWIDTH-1:0] addr,
    input  logic [DWIDTH-1:0] d,
    input  logic [DWIDTH/8-1:0] wbe,
    output logic [DWIDTH-1:0] q
);
    (* ram_style = "block" *) logic [DWIDTH-1:0] mem [0:DEPTH-1];

    initial begin
        // You can keep $readmemh/b logic here as before
        for (int i = 0; i < DEPTH; i++) mem[i] = '0;
    end

    logic [DWIDTH-1:0] read_data_reg;
    always_ff @(posedge clk) begin
        if (en) begin
            for (int i = 0; i < DWIDTH/8; i++) begin
                if (wbe[i]) mem[addr][i*8 +: 8] <= d[i*8 +: 8];
            end
            read_data_reg <= mem[addr];
        end
    end
    assign q = read_data_reg;
endmodule

`endif