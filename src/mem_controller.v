module mem_controller #(
  parameter FIFO_WIDTH = 8
) (
  input clk,
  input rst,
  input rx_fifo_empty,
  input tx_fifo_full,
  input [FIFO_WIDTH-1:0] din,

  output rx_fifo_rd_en,
  output tx_fifo_wr_en,
  output [FIFO_WIDTH-1:0] dout,
  output [5:0] state_leds
);

  localparam MEM_WIDTH = 8;   /* Width of each mem entry (word) */
  localparam MEM_DEPTH = 256; /* Number of entries */
  localparam NUM_BYTES_PER_WORD = MEM_WIDTH/8;
  localparam MEM_ADDR_WIDTH = $clog2(MEM_DEPTH); 

  // Converted from wires to regs to allow assignment in the always block
  reg [NUM_BYTES_PER_WORD-1:0] mem_we_logic;
  reg [MEM_ADDR_WIDTH-1:0] mem_addr_logic;
  reg [MEM_WIDTH-1:0] mem_din_logic;
  wire [MEM_WIDTH-1:0] mem_dout;

  SYNC_RAM_WBE #(
    .DWIDTH(MEM_WIDTH),
    .AWIDTH(MEM_ADDR_WIDTH)
  ) mem (
    .clk(clk),
    .en(1'b1),
    .wbe(mem_we_logic),
    .addr(mem_addr_logic),
    .d(mem_din_logic),
    .q(mem_dout)
  );

  localparam 
    IDLE = 3'd0,
    READ_CMD = 3'd1,
    READ_ADDR = 3'd2,
    READ_DATA = 3'd3,
    READ_MEM_VAL = 3'd4,
    ECHO_VAL = 3'd5,
    WRITE_MEM_VAL = 3'd6;

  wire [2:0] curr_state;
  reg  [2:0] next_state;

  /* State Update */
  REGISTER_R #(.N(3), .INIT(IDLE)) state_reg (
    .q(curr_state), .d(next_state), .rst(rst), .clk(clk)
  );

  wire [MEM_WIDTH-1:0] cmd;
  wire [MEM_WIDTH-1:0] addr;
  wire [MEM_WIDTH-1:0] data;

  /* Registers for byte reading */
  // Data is continuously sampled while in these states. The final value 
  // correctly latches exactly as the FSM transitions to the next state.
  wire cmd_ce = (curr_state == READ_CMD);
  REGISTER_CE #(.N(MEM_WIDTH)) cmd_reg (
    .q(cmd), .d(din), .ce(cmd_ce), .clk(clk)
  );

  wire addr_ce = (curr_state == READ_ADDR);
  REGISTER_CE #(.N(MEM_WIDTH)) addr_reg (
    .q(addr), .d(din), .ce(addr_ce), .clk(clk)
  );

  wire data_ce = (curr_state == READ_DATA);
  REGISTER_CE #(.N(MEM_WIDTH)) data_reg (
    .q(data), .d(din), .ce(data_ce), .clk(clk)
  );

  // Internal routing for outputs
  reg rx_fifo_rd_en_logic;
  reg tx_fifo_wr_en_logic;
  reg [FIFO_WIDTH-1:0] dout_logic;

  /* Next State Logic */
  always @(*) begin
    /* initial values to avoid latch synthesis */
    next_state = curr_state;

    case (curr_state)
      IDLE: begin
        if (~rx_fifo_empty) next_state = READ_CMD;
      end
      READ_CMD: begin
        if (~rx_fifo_empty) next_state = READ_ADDR;
      end
      READ_ADDR: begin
        if (cmd == 8'd49) begin // '1' = Write Command
          if (~rx_fifo_empty) next_state = READ_DATA;
        end else if (cmd == 8'd48) begin // '0' = Read Command
          next_state = READ_MEM_VAL;
        end else begin
          next_state = IDLE; // Fallback recovery for garbage data
        end
      end
      READ_DATA: begin
        next_state = WRITE_MEM_VAL;
      end
      READ_MEM_VAL: begin
        next_state = ECHO_VAL;
      end
      ECHO_VAL: begin
        if (~tx_fifo_full) next_state = IDLE;
      end
      WRITE_MEM_VAL: begin
        next_state = IDLE;
      end
    endcase
  end

  /* Output and Mem Signal Logic */
  always @(*) begin
    /* initial values to avoid latch synthesis */
    rx_fifo_rd_en_logic = 1'b0;
    tx_fifo_wr_en_logic = 1'b0;
    mem_we_logic        = 1'b0;
    mem_addr_logic      = addr[MEM_ADDR_WIDTH-1:0];
    mem_din_logic       = data;
    dout_logic          = mem_dout;
    
    case (curr_state)
      IDLE: begin
        rx_fifo_rd_en_logic = ~rx_fifo_empty;
      end
      READ_CMD: begin
        rx_fifo_rd_en_logic = ~rx_fifo_empty;
      end
      READ_ADDR: begin
        if (cmd == 8'd49) begin
          rx_fifo_rd_en_logic = ~rx_fifo_empty;
        end
      end
      READ_DATA: begin
        // Wait state for next_state transition. The 'data' register handles capture.
      end
      READ_MEM_VAL: begin
        // RAM automatically reads mem_addr_logic when en=1 and wbe=0
      end
      ECHO_VAL: begin
        tx_fifo_wr_en_logic = ~tx_fifo_full;
      end
      WRITE_MEM_VAL: begin
        mem_we_logic = 1'b1;
      end
    endcase
  end

  // Output Assignments
  assign rx_fifo_rd_en = rx_fifo_rd_en_logic;
  assign tx_fifo_wr_en = tx_fifo_wr_en_logic;
  assign dout = dout_logic;
  
  // Pad the 3-bit state variable with zeros to fill the 6-bit state_leds output
  assign state_leds = {3'b000, curr_state};

endmodule