`timescale 1ns/1ps

`define CLOCK_FREQ 100_000_000
`define BAUD_RATE 115_200
`define CLK_PERIOD 10 // Adjusted for 100MHz

module uart2uart_tb();
    // System signals
    logic clk = 0;
    logic reset;

    // Interface signals
    logic [7:0] data_in;
    logic       data_in_valid;
    logic       data_in_ready;
    logic [7:0] data_out;
    logic       data_out_valid;
    logic       data_out_ready;

    // Serial lines
    wire FPGA_SERIAL_RX;
    wire FPGA_SERIAL_TX;

    // Generate 100MHz clock
    always #(`CLK_PERIOD/2) clk <= ~clk;

    // Off-chip UART (Transmitter)
    uart #(
        .CLOCK_FREQ(`CLOCK_FREQ),
        .BAUD_RATE(`BAUD_RATE)
    ) off_chip_uart (
        .clk(clk),
        .reset(reset),
        .data_in(data_in),
        .data_in_valid(data_in_valid),
        .data_in_ready(data_in_ready),
        .data_out(),
        .data_out_valid(),
        .data_out_ready(1'b0),
        .serial_in(FPGA_SERIAL_RX),
        .serial_out(FPGA_SERIAL_TX)
    );

    // On-chip UART (Receiver)
    uart #(
        .CLOCK_FREQ(`CLOCK_FREQ),
        .BAUD_RATE(`BAUD_RATE)
    ) on_chip_uart (
        .clk(clk),
        .reset(reset),
        .data_in(8'd0),
        .data_in_valid(1'b0),
        .data_in_ready(),
        .data_out(data_out),
        .data_out_valid(data_out_valid),
        .data_out_ready(data_out_ready),
        .serial_in(FPGA_SERIAL_TX), // Loopback TX -> RX
        .serial_out(FPGA_SERIAL_RX)
    );

    bit done = 0;

    initial begin
        `ifndef IVERILOG
            $vcdpluson;
        `endif

        // Initialization
        reset = 1'b0;
        data_in = 8'd0;
        data_in_valid = 1'b0;
        data_out_ready = 1'b0;
        
        repeat (2) @(posedge clk); 
        
        // Reset sequence
        reset = 1'b1;
        @(posedge clk); #1;
        reset = 1'b0;

        fork
            // Producer Thread
            begin
                wait(data_in_ready);
                #1;
                $display("[%0t] Sending byte: 8'h21", $time);
                data_in = 8'h21;
                data_in_valid = 1'b1;
                @(posedge clk); #1;
                data_in_valid = 1'b0;

                // Wait for receipt
                wait(data_out_valid);
                #1;
                
                // Verification
                if (data_out !== 8'h21) 
                    $error("Mismatch: Expected 8'h21, got 8'h%h", data_out);
                else 
                    $display("[%0t] Received correct data: 8'h21", $time);

                // Handshake acknowledgement
                data_out_ready = 1'b1;
                @(posedge clk); #1;
                data_out_ready = 1'b0;
                @(posedge clk); #1;

                if (data_out_valid) 
                    $error("Failure: data_out_valid did not clear after ready handshake");
                
                done = 1;
            end

            // Timeout Thread
            begin
                repeat (50000) @(posedge clk);
                if (!done) begin
                    $error("Failure: Simulation timed out");
                    $fatal();
                end
            end
        join

        $display("Test finished successfully.");
        $finish();
    end
endmodule