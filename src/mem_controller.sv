module mem_controller #(
    parameter int FIFO_WIDTH = 8
) (
    input  logic                   clk,
    input  logic                   rst,
    input  logic                   rx_fifo_empty,
    input  logic                   tx_fifo_full,
    input  logic [FIFO_WIDTH-1:0]  din,

    output logic                   rx_fifo_rd_en,
    output logic                   tx_fifo_wr_en,
    output logic [FIFO_WIDTH-1:0]  dout,
    output logic [5:0]             state_leds
);

    localparam int MEM_WIDTH = 8;
    localparam int MEM_DEPTH = 256;
    localparam int MEM_ADDR_WIDTH = $clog2(MEM_DEPTH);

    // FSM State definition
    typedef enum logic [2:0] {
        IDLE            = 3'd0,
        READ_CMD        = 3'd1,
        READ_ADDR       = 3'd2,
        READ_DATA       = 3'd3,
        READ_MEM_VAL    = 3'd4,
        ECHO_VAL        = 3'd5,
        WRITE_MEM_VAL   = 3'd6
    } state_t;

    state_t curr_state, next_state;
    
    logic [0:0]            mem_we_logic; // Reduced to [0:0] since MEM_WIDTH/8 = 1
    logic [MEM_ADDR_WIDTH-1:0] mem_addr_logic;
    logic [MEM_WIDTH-1:0]      mem_din_logic;
    logic [MEM_WIDTH-1:0]      mem_dout;

    SYNC_RAM_WBE #(.DWIDTH(MEM_WIDTH), .AWIDTH(MEM_ADDR_WIDTH)) mem (
        .clk(clk),
        .en(1'b1),
        .wbe(mem_we_logic),
        .addr(mem_addr_logic),
        .d(mem_din_logic),
        .q(mem_dout)
    );

    REGISTER_R #(.N(3), .INIT(IDLE)) state_reg (
        .q(curr_state), .d(next_state), .rst(rst), .clk(clk)
    );

    logic [MEM_WIDTH-1:0] cmd, addr, data;

    REGISTER_CE #(.N(MEM_WIDTH)) cmd_reg  (.q(cmd),  .d(din), .ce(curr_state == READ_CMD),  .clk(clk));
    REGISTER_CE #(.N(MEM_WIDTH)) addr_reg (.q(addr), .d(din), .ce(curr_state == READ_ADDR), .clk(clk));
    REGISTER_CE #(.N(MEM_WIDTH)) data_reg (.q(data), .d(din), .ce(curr_state == READ_DATA), .clk(clk));

    /* Next State Logic */
    always_comb begin
        next_state = curr_state;
        case (curr_state)
            IDLE:          if (~rx_fifo_empty) next_state = READ_CMD;
            READ_CMD:      if (~rx_fifo_empty) next_state = READ_ADDR;
            READ_ADDR: begin
                if      (cmd == 8'd49 && ~rx_fifo_empty) next_state = READ_DATA;
                else if (cmd == 8'd48)                   next_state = READ_MEM_VAL;
                else if (cmd != 8'd49 && cmd != 8'd48)   next_state = IDLE;
            end
            READ_DATA:     next_state = WRITE_MEM_VAL;
            READ_MEM_VAL:  next_state = ECHO_VAL;
            ECHO_VAL:      if (~tx_fifo_full) next_state = IDLE;
            WRITE_MEM_VAL: next_state = IDLE;
        endcase
    end

    /* Output and Mem Signal Logic */
    always_comb begin
        rx_fifo_rd_en = 1'b0;
        tx_fifo_wr_en = 1'b0;
        mem_we_logic  = 1'b0;
        mem_addr_logic = addr[MEM_ADDR_WIDTH-1:0];
        mem_din_logic  = data;
        dout           = mem_dout;
        
        case (curr_state)
            IDLE, READ_CMD: rx_fifo_rd_en = ~rx_fifo_empty;
            READ_ADDR:      if (cmd == 8'd49) rx_fifo_rd_en = ~rx_fifo_empty;
            ECHO_VAL:       tx_fifo_wr_en = ~tx_fifo_full;
            WRITE_MEM_VAL:  mem_we_logic  = 1'b1;
        endcase
    end

    assign state_leds = {3'b000, curr_state};

endmodule