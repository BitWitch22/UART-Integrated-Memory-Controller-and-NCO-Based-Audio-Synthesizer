module fifo #(
    parameter WIDTH = 8,
    parameter DEPTH = 32,
    parameter POINTER_WIDTH = $clog2(DEPTH)
) (
    input clk, rst,

    // Write side
    input wr_en,
    input [WIDTH-1:0] din,
    output full,

    // Read side
    input rd_en,
    output [WIDTH-1:0] dout,
    output empty
);

    // Pointers are given an extra bit to track wrap-around
    wire [POINTER_WIDTH:0] wr_ptr_val;
    wire [POINTER_WIDTH:0] rd_ptr_val;
    wire [POINTER_WIDTH:0] wr_ptr_next;
    wire [POINTER_WIDTH:0] rd_ptr_next;

    // Safety checks to prevent underflow/overflow
    wire wr_fire = wr_en & ~full;
    wire rd_fire = rd_en & ~empty;

    assign wr_ptr_next = wr_ptr_val + 1'b1;
    assign rd_ptr_next = rd_ptr_val + 1'b1;

    // 1. Write Pointer
    REGISTER_R_CE #(.N(POINTER_WIDTH + 1), .INIT(0)) wr_ptr (
        .q(wr_ptr_val),
        .d(wr_ptr_next),
        .ce(wr_fire),
        .rst(rst),
        .clk(clk)
    );

    // 2. Read Pointer
    REGISTER_R_CE #(.N(POINTER_WIDTH + 1), .INIT(0)) rd_ptr (
        .q(rd_ptr_val),
        .d(rd_ptr_next),
        .ce(rd_fire),
        .rst(rst),
        .clk(clk)
    );

    // 3. Status Flags
    assign empty = (wr_ptr_val == rd_ptr_val);
    
    // Full when the MSBs are different, but the rest of the address matches
    assign full = (wr_ptr_val[POINTER_WIDTH] != rd_ptr_val[POINTER_WIDTH]) &&
                  (wr_ptr_val[POINTER_WIDTH-1:0] == rd_ptr_val[POINTER_WIDTH-1:0]);

    // 4. Memory Array Generation
    wire [WIDTH-1:0] mem_out [DEPTH-1:0];

    genvar i;
    generate
        for (i = 0; i < DEPTH; i = i + 1) begin : fifo_mem
            // Enable writing only to the register matching the current write pointer
            wire mem_we = wr_fire && (wr_ptr_val[POINTER_WIDTH-1:0] == i);
            
            REGISTER_CE #(.N(WIDTH)) mem_reg (
                .q(mem_out[i]),
                .d(din),
                .ce(mem_we),
                .clk(clk)
            );
        end
    endgenerate

    // 5. Output Assignment
    // Combinational read from the array. Since rd_ptr updates on the clock edge,
    // dout effectively updates one cycle after rd_en is asserted.
    assign dout = mem_out[rd_ptr_val[POINTER_WIDTH-1:0]];

endmodule