module fifo #(
    parameter int WIDTH         = 8,
    parameter int DEPTH         = 32,
    parameter int POINTER_WIDTH = $clog2(DEPTH)
) (
    input  logic                   clk, 
    input  logic                   rst,

    // Write side
    input  logic                   wr_en,
    input  logic [WIDTH-1:0]       din,
    output logic                   full,

    // Read side
    input  logic                   rd_en,
    output logic [WIDTH-1:0]       dout,
    output logic                   empty
);

    // Pointers are given an extra bit to track wrap-around
    logic [POINTER_WIDTH:0] wr_ptr_val, rd_ptr_val;
    logic [POINTER_WIDTH:0] wr_ptr_next, rd_ptr_next;

    // Safety checks to prevent underflow/overflow
    logic wr_fire, rd_fire;
    assign wr_fire = wr_en & ~full;
    assign rd_fire = rd_en & ~empty;

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
    logic [WIDTH-1:0] mem_out [DEPTH];

    generate
        for (genvar i = 0; i < DEPTH; i++) begin : fifo_mem
            // Enable writing only to the register matching the current write pointer
            logic mem_we;
            assign mem_we = wr_fire && (wr_ptr_val[POINTER_WIDTH-1:0] == i);
            
            REGISTER_CE #(.N(WIDTH)) mem_reg (
                .q(mem_out[i]),
                .d(din),
                .ce(mem_we),
                .clk(clk)
            );
        end
    endgenerate

    // 5. Output Assignment
    // Combinational read from the array.
    assign dout = mem_out[rd_ptr_val[POINTER_WIDTH-1:0]];

endmodule