`timescale 1ns/1ns
`define CLK_PERIOD 8

module fifo_tb();
  localparam WIDTH = 32;
  localparam LOGDEPTH = 3;
  localparam DEPTH = (1 << LOGDEPTH);

  logic clk = 0;
  logic rst = 0;

  always #(`CLK_PERIOD/2) clk <= ~clk;

  logic [WIDTH-1:0] test_values[50];
  logic [WIDTH-1:0] received_values[50];

  logic wr_en;
  logic [WIDTH-1:0] din;
  logic full;

  logic empty;
  logic [WIDTH-1:0] dout;
  logic rd_en;

  fifo #(.WIDTH(WIDTH), .DEPTH(DEPTH)) dut (
    .clk(clk), .rst(rst),
    .wr_en(wr_en), .din(din), .full(full),
    .empty(empty), .dout(dout), .rd_en(rd_en)
  );

  task write_to_fifo(input [WIDTH-1:0] write_data, input violate_interface);
    begin
      #1;
      wr_en = (!violate_interface && full) ? 1'b0 : 1'b1;
      din = write_data;
      @(posedge clk); #1;
      wr_en = 1'b0;
    end
  endtask

  task read_from_fifo(input violate_interface, output [WIDTH-1:0] read_data);
    begin
      #1;
      rd_en = (!violate_interface && empty) ? 1'b0 : 1'b1;
      @(posedge clk); #1;
      read_data = dout;
      rd_en = 1'b0;
    end
  endtask

  int i;
  int num_mismatches;
  int num_items = 50;
  int write_delay = 0, read_delay = 0;
  int write_idx, read_idx;
  bit write_start, read_start;

  initial begin: TB
    `ifndef IVERILOG
        $vcdpluson;
        $vcdplusmemon;
    `endif
    
    // Data generation
    for (i = 0; i < 50; i++) begin
      test_values[i] = i + 1000;
    end

    wr_en = 0; din = 0; rd_en = 0;
    rst = 1'b1;
    repeat (2) @(posedge clk); #1;
    rst = 1'b0;
    @(posedge clk); #1;

    // Basic tests
    for (i = 0; i < DEPTH; i++) begin
      write_to_fifo(test_values[i], 1'b0);
      @(posedge clk);
    end

    for (i = 0; i < DEPTH; i++) begin
      read_from_fifo(1'b0, received_values[i]);
      @(posedge clk);
    end

    // Concurrent Read/Write test
    fork
      begin
        write_start = 1;
        for (i = 0; i < num_items; i++) begin
          write_to_fifo(test_values[i], 1'b0);
          repeat (write_delay) @(posedge clk);
        end
      end
      begin
        repeat(2) @(posedge clk);
        read_start = 1;
        for (i = 0; i < num_items; i++) begin
          read_from_fifo(1'b0, received_values[i]);
          repeat (read_delay) @(posedge clk);
        end
      end
    join

    // Final verification
    num_mismatches = 0;
    for (i = 0; i < num_items; i++) begin
      if (test_values[i] !== received_values[i]) num_mismatches++;
    end

    if (num_mismatches == 0) $display("All tests PASSED!");
    else $display("Tests FAILED with %d mismatches.", num_mismatches);

    $finish();
  end

endmodule