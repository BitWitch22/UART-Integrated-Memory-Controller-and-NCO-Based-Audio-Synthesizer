`timescale 1ns/1ps

`define CLK_PERIOD 10 // Adjusted for 100MHz clock
`define B_SAMPLE_CNT_MAX 5
`define B_PULSE_CNT_MAX 5
`define CLOCK_FREQ 100_000_000
`define BAUD_RATE 115_200
`define CYCLES_PER_CHAR ((`CLOCK_FREQ / `BAUD_RATE) * 10)
`define CYCLES_PER_SECOND (`CYCLES_PER_CHAR * 6)

module system_tb();

  logic clk = 0;
  logic rst; 
  logic [2:0] buttons;
  logic [1:0] switches;
  logic [7:0] off_chip_data_in;
  logic       off_chip_data_in_valid; 
  logic       off_chip_data_out_ready;
  
  wire        off_chip_data_out_valid;
  wire        off_chip_data_in_ready;
  wire  [7:0] off_chip_data_out;
  wire        FPGA_SERIAL_RX;
  wire        FPGA_SERIAL_TX;
  wire  [5:0] leds;

  localparam int MEM_DEPTH = 256;
  localparam int FIFO_DEPTH = 8;
  localparam int NUM_CHARS = 26;
  localparam int CHAR0 = 8'h41; // 'A'

  // Generate system clock
  always #(`CLK_PERIOD/2) clk <= ~clk;

  int tests_failed = 0;

  z1top #(
      .B_SAMPLE_CNT_MAX(`B_SAMPLE_CNT_MAX),
      .B_PULSE_CNT_MAX(`B_PULSE_CNT_MAX),
      .CLOCK_FREQ(`CLOCK_FREQ),
      .BAUD_RATE(`BAUD_RATE),
      .CYCLES_PER_SECOND(`CYCLES_PER_SECOND)
  ) top (
      .CLK_100MHZ_FPGA(clk), // Mapping to correct 100MHz port
      .BUTTONS({buttons, rst}),
      .SWITCHES(switches),
      .LEDS(leds),
      .AUD_PWM(),
      .AUD_SD(),
      .FPGA_SERIAL_RX(FPGA_SERIAL_RX),
      .FPGA_SERIAL_TX(FPGA_SERIAL_TX)
  );

  uart #(
      .BAUD_RATE(`BAUD_RATE),
      .CLOCK_FREQ(`CLOCK_FREQ)
  ) off_chip_uart (
      .clk(clk),
      .reset(rst),
      .data_in(off_chip_data_in),
      .data_in_valid(off_chip_data_in_valid),
      .data_in_ready(off_chip_data_in_ready),
      .data_out(off_chip_data_out),
      .data_out_valid(off_chip_data_out_valid),
      .data_out_ready(off_chip_data_out_ready),
      .serial_in(FPGA_SERIAL_TX),
      .serial_out(FPGA_SERIAL_RX)
  );

  task off_chip_uart_send(input [7:0] data);
    begin
        wait(off_chip_data_in_ready);
        #1;
        $display("[%0t] Sending byte: %d.", $time, data);
        off_chip_data_in_valid = 1'b1;
        off_chip_data_in = data;
        @(posedge clk); #1;
        off_chip_data_in_valid = 1'b0;
    end
  endtask

  task off_chip_uart_receive(input [7:0] data);
    begin
      wait(off_chip_data_out_valid);
      #1;
      off_chip_data_out_ready = 1'b0;
      if (off_chip_data_out == data)
          $display("[%0t] PASSED! Expected: %d, Actual: %d", $time, data, off_chip_data_out);
      else begin
          $display("[%0t] FAILED! Expected: %d, Actual: %d", $time, data, off_chip_data_out);
          tests_failed++;
      end
      @(posedge clk);
      off_chip_data_out_ready = 1'b1;
    end
  endtask 

  task write_packet(input [7:0] addr, input [7:0] data, input logic bool_delay);
    begin
      off_chip_uart_send(8'd49); // Command for write
      if (bool_delay) repeat (2) @(posedge clk);
      off_chip_uart_send(addr);
      if (bool_delay) repeat (1) @(posedge clk);
      off_chip_uart_send(data);
    end
  endtask

  task read_packet(input [7:0] addr, input [7:0] expected_data, input logic bool_delay);
    begin
      off_chip_uart_send(8'd48); // Command for read
      if(bool_delay) repeat (2) @(posedge clk);
      off_chip_uart_send(addr);
      if(bool_delay) repeat (1) @(posedge clk);
      
      wait(top.mem_tx_wr_en == 1'b1);
      @(posedge clk);
      off_chip_uart_receive(expected_data);
    end
  endtask 

  initial begin: TB
    off_chip_data_in = 8'd0;
    off_chip_data_in_valid = 1'b0;
    off_chip_data_out_ready = 1'b1;
    buttons = 0;
    switches = 0;

    rst = 1'b0;
    repeat (5) @(posedge clk); #1;
    rst = 1'b1;
    repeat (40) @(posedge clk); #1;
    rst = 1'b0;

    $display("------- Running simple test -------");
    write_packet(8'd11, CHAR0, 1'b0);
    repeat(`CYCLES_PER_CHAR * 5) @(posedge clk);
    read_packet(8'd11, CHAR0, 1'b0);

    repeat(10) @(posedge clk);

    $display("------- Running harder test -------");
    for(int i = 0; i < NUM_CHARS; i++) begin
        write_packet(8'(i), 8'(CHAR0 + i), 1'b0);
    end
    for(int i = NUM_CHARS - 1; i >= 0; i--) begin
        read_packet(8'(i), 8'(CHAR0 + i), 1'b0);
    end

    if (tests_failed == 0) $display("\nAll tests PASSED!\n");
    else $display("\n%d tests FAILED.\n", tests_failed);

    $finish();
  end

  initial begin
      repeat (`CYCLES_PER_CHAR * 500) @(posedge clk);
      $display("Timing out");
      $fatal();
  end
endmodule