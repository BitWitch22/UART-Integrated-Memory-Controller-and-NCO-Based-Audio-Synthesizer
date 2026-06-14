`timescale 1ns/1ps

module uart_transmitter_tb();
  // Constants
  localparam int CLOCK_FREQ   = 100_000_000;
  localparam real CLOCK_PERIOD = 1_000_000_000.0 / CLOCK_FREQ;
  localparam int BAUD_RATE    = 115_200;
  localparam int BAUD_PERIOD  = 1_000_000_000 / BAUD_RATE; 

  localparam int CHAR0 = 8'h61; // 'a'
  localparam int NUM_CHARS = 16;
  localparam int INPUT_DELAY = 1000;

  // Signals
  logic clk = 0;
  logic rst;
  logic [7:0] data_in;
  logic data_in_valid;
  logic data_in_ready;
  logic serial_out;

  // Clock Generation
  always #(CLOCK_PERIOD / 2.0) clk = ~clk;

  // DUT Instantiation
  uart_transmitter #(
    .CLOCK_FREQ(CLOCK_FREQ),
    .BAUD_RATE(BAUD_RATE)
  ) DUT (
    .clk(clk),
    .reset(rst),
    .data_in(data_in),
    .data_in_valid(data_in_valid),
    .data_in_ready(data_in_ready),
    .serial_out(serial_out)
  );

  // Arrays and counters
  logic [9:0] chars_to_host [NUM_CHARS];
  logic [7:0] chars_from_data_in [NUM_CHARS];
  int cnt;

  assign data_in = chars_from_data_in[cnt];

  // Producer logic
  initial begin
    for (int c = 0; c < NUM_CHARS; c++) begin
      chars_from_data_in[c] = CHAR0 + c;
    end
  end

  logic data_in_fired;
  always @(posedge clk) begin
    if (rst) begin
      cnt <= 0;
      data_in_fired <= 0;
    end else begin
      if (data_in_fired) begin
        data_in_fired <= 0;
        if (data_in_ready)
          $error("[time %0t] Failed: data_in_ready should go LOW after firing", $time);
      end else if (data_in_valid && data_in_ready) begin
        data_in_fired <= 1'b1;
        cnt <= cnt + 1;
        $display("[time %0t] [data_in] Sent char: 8'h%h", $time, data_in);
      end
    end
  end

  // Test Stimulus
  initial begin
    data_in_valid = 1'b0;
    rst = 1'b1;
    repeat (10) @(posedge clk);
    @(negedge clk) rst = 1'b0;

    for (int j = 0; j < NUM_CHARS; j++) begin
      wait (data_in_ready);
      #(INPUT_DELAY);
      @(negedge clk) data_in_valid = 1'b1;
      @(negedge clk) data_in_valid = 1'b0;
    end
  end

  // Checker logic
  initial begin
    int num_mismatches = 0;
    
    // Wait for reset
    wait(!rst);
    repeat (100) @(posedge clk);

    for (int c = 0; c < NUM_CHARS; c++) begin
      wait (!serial_out); // Wait for start bit
      for (int i = 0; i < 10; i++) begin
        #(BAUD_PERIOD / 2);
        chars_to_host[c][i] = serial_out;
        #(BAUD_PERIOD / 2);
      end
      $display("[time %0t] [serial_out] Got: 8'h%h", $time, chars_to_host[c][8:1]);
    end

    // Verification
    for (int c = 0; c < NUM_CHARS; c++) begin
      if (chars_from_data_in[c] !== chars_to_host[c][8:1]) begin
        $error("Mismatch at char %0d: expected %h, got %h", c, chars_from_data_in[c], chars_to_host[c][8:1]);
        num_mismatches++;
      end
    end

    $display(num_mismatches > 0 ? "Tests failed!" : "Tests passed!");
    $finish();
  end
endmodule