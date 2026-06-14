module fixed_length_piano #(
    parameter int CYCLES_PER_SECOND = 100_000_000
) (
    input  logic        clk,
    input  logic        rst,

    input  logic [2:0]  buttons, // buttons[0] = length UP, buttons[1] = length DOWN
    output logic [5:0]  leds,

    output logic [7:0]  ua_tx_din,
    output logic        ua_tx_wr_en,
    input  logic        ua_tx_full,

    input  logic [7:0]  ua_rx_dout,
    input  logic        ua_rx_empty,
    output logic        ua_rx_rd_en,

    output logic [23:0] fcw
);

    //------------------------- FSM States ---------------------------
    typedef enum logic {IDLE = 1'b0, PLAY = 1'b1} state_t;
    state_t curr_state, next_state;

    REGISTER_R #(.N(1), .INIT(IDLE)) state_reg (
        .q(curr_state), 
        .d(next_state), 
        .rst(rst), 
        .clk(clk)
    );

    // Handshake logic to ensure safe FIFO communication
    logic can_fetch;
    assign can_fetch = ~ua_rx_empty & ~ua_tx_full;

    //------------------- Note Length Controller ---------------------
    logic [31:0] note_length_val;
    logic [31:0] note_length_next;
    
    // Change note length by 0.1 seconds
    localparam int LENGTH_STEP = CYCLES_PER_SECOND / 10;

    assign note_length_next = buttons[0] ? note_length_val + LENGTH_STEP :
                             (buttons[1] && (note_length_val > LENGTH_STEP)) ? note_length_val - LENGTH_STEP :
                              note_length_val;

    // Defaults to 1/5th of a second
    REGISTER_R_CE #(.N(32), .INIT(CYCLES_PER_SECOND / 5)) note_length_reg (
        .q(note_length_val),
        .d(note_length_next),
        .ce(buttons[0] | buttons[1]),
        .rst(rst),
        .clk(clk)
    );

    //---------------------- Playback Timer --------------------------
    logic [31:0] timer_val;
    logic timer_done, timer_rst;
    
    assign timer_done = (timer_val == note_length_val - 1'b1);
    assign timer_rst  = (curr_state == IDLE) | timer_done | rst;

    REGISTER_R_CE #(.N(32), .INIT(0)) timer_reg (
        .q(timer_val),
        .d(timer_val + 1'b1),
        .ce(curr_state == PLAY),
        .rst(timer_rst),
        .clk(clk)
    );

    //---------------------- Character Capture -----------------------
    logic [7:0] active_char;
    
    REGISTER_CE #(.N(8)) char_reg (
        .q(active_char),
        .d(ua_rx_dout),
        .ce((curr_state == IDLE) & can_fetch),
        .clk(clk)
    );

    //---------------------- ROM Instantiation -----------------------
    logic [23:0] rom_fcw;
    
    piano_scale_rom scale_rom (
        .address(active_char),
        .data(rom_fcw),
        .last_address()
    );

    //---------------------- Next State Logic ------------------------
    always_comb begin
        next_state = curr_state;
        case (curr_state)
            IDLE: if (can_fetch) next_state = PLAY;
            PLAY: if (timer_done) next_state = IDLE;
        endcase
    end

    //---------------------- Output Routing --------------------------
    assign ua_rx_rd_en = (curr_state == IDLE) & can_fetch;
    assign ua_tx_wr_en = (curr_state == IDLE) & can_fetch;
    assign ua_tx_din   = ua_rx_dout;

    // Only pass the Frequency Control Word to the NCO while playing
    assign fcw = (curr_state == PLAY) ? rom_fcw : 24'd0;

    // Show current FSM state and the upper 5 bits of the pressed character
    assign leds = {active_char[4:0], curr_state};

endmodule