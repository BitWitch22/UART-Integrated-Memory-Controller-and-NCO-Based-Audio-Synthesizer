module fixed_length_piano #(
    // Updated default for Nexys Artix-A7
    parameter CYCLES_PER_SECOND = 100_000_000
) (
    input clk,
    input rst,

    input [2:0] buttons, // buttons[0] = length UP, buttons[1] = length DOWN
    output [5:0] leds,

    output [7:0] ua_tx_din,
    output ua_tx_wr_en,
    input ua_tx_full,

    input [7:0] ua_rx_dout,
    input ua_rx_empty,
    output ua_rx_rd_en,

    output [23:0] fcw
);

    //------------------------- FSM States ---------------------------
    localparam IDLE = 1'b0;
    localparam PLAY = 1'b1;

    wire curr_state;
    reg  next_state;

    REGISTER_R #(.N(1), .INIT(IDLE)) state_reg (
        .q(curr_state), .d(next_state), .rst(rst), .clk(clk)
    );

    // Handshake logic to ensure safe FIFO communication
    wire can_fetch = ~ua_rx_empty & ~ua_tx_full;

    //------------------- Note Length Controller ---------------------
    wire [31:0] note_length_val;
    wire [31:0] note_length_next;
    wire note_length_ce = buttons[0] | buttons[1];

    // Change note length by 0.1 seconds
    localparam LENGTH_STEP = CYCLES_PER_SECOND / 10;

    assign note_length_next = buttons[0] ? note_length_val + LENGTH_STEP :
                              (buttons[1] && (note_length_val > LENGTH_STEP)) ? note_length_val - LENGTH_STEP :
                              note_length_val;

    // Defaults to 1/5th of a second
    REGISTER_R_CE #(.N(32), .INIT(CYCLES_PER_SECOND / 5)) note_length_reg (
        .q(note_length_val),
        .d(note_length_next),
        .ce(note_length_ce),
        .rst(rst),
        .clk(clk)
    );

    //---------------------- Playback Timer --------------------------
    wire [31:0] timer_val;
    wire timer_done = (timer_val == note_length_val - 1'b1);
    wire timer_rst  = (curr_state == IDLE) | timer_done | rst;

    REGISTER_R_CE #(.N(32), .INIT(0)) timer_reg (
        .q(timer_val),
        .d(timer_val + 1'b1),
        .ce(curr_state == PLAY),
        .rst(timer_rst),
        .clk(clk)
    );

    //---------------------- Character Capture -----------------------
    wire [7:0] active_char;
    
    // Grab the ASCII char off the bus exactly when we fetch it
    REGISTER_CE #(.N(8)) char_reg (
        .q(active_char),
        .d(ua_rx_dout),
        .ce((curr_state == IDLE) & can_fetch),
        .clk(clk)
    );

    //---------------------- ROM Instantiation -----------------------

    wire [23:0] rom_fcw;
    
    piano_scale_rom scale_rom (
        .address(active_char), // Feed the currently held character
        .data(rom_fcw),        // Maps to the 24-bit output
        .last_address()        // Leave unconnected, we don't need it
    );

    //---------------------- Next State Logic ------------------------
    always @(*) begin
        next_state = curr_state; // Default hold

        case (curr_state)
            IDLE: begin
                if (can_fetch) next_state = PLAY;
            end
            PLAY: begin
                if (timer_done) next_state = IDLE;
            end
        endcase
    end

    //---------------------- Output Routing --------------------------
    // 1. FIFO Handshaking
    // We instantly echo the RX data to the TX data line while moving it to the ROM
    assign ua_rx_rd_en = (curr_state == IDLE) & can_fetch;
    assign ua_tx_wr_en = (curr_state == IDLE) & can_fetch;
    assign ua_tx_din   = ua_rx_dout;

    // 2. Audio Control Word
    // Only pass the Frequency Control Word to the NCO while actively playing
    assign fcw = (curr_state == PLAY) ? rom_fcw : 24'd0;

    // 3. Status LEDs
    // Show current FSM state and the upper 5 bits of the pressed character
    assign leds = {active_char[4:0], curr_state};

endmodule