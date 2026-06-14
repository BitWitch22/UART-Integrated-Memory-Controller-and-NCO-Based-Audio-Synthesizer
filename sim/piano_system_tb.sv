`timescale 1ns/100ps

`define CLK_PERIOD 10 // Corrected for 100MHz (10ns)
`define B_SAMPLE_CNT_MAX 5
`define B_PULSE_CNT_MAX 5
`define CLOCK_FREQ 100_000_000
`define BAUD_RATE 115_200
`define CYCLES_PER_CHAR ((`CLOCK_FREQ / `BAUD_RATE) * 10)
`define CYCLES_PER_SECOND (`CYCLES_PER_CHAR * 6)

module piano_system_tb();
    logic clk = 0;
    logic audio_pwm;
    logic [5:0] leds;
    logic [2:0] buttons;
    logic [1:0] switches; 
    logic rst;
    logic [7:0] data_in;
    logic data_in_valid;
    logic data_in_ready;

    logic FPGA_SERIAL_RX, FPGA_SERIAL_TX;

    // Generate 100MHz clock
    always #(`CLK_PERIOD/2) clk <= ~clk;

    // Instantiate Top Module
    z1top #(
        .B_SAMPLE_CNT_MAX(`B_SAMPLE_CNT_MAX),
        .B_PULSE_CNT_MAX(`B_PULSE_CNT_MAX),
        .CLOCK_FREQ(`CLOCK_FREQ),
        .BAUD_RATE(`BAUD_RATE),
        .CYCLES_PER_SECOND(`CYCLES_PER_SECOND)
    ) top (
        .CLK_100MHZ_FPGA(clk), // Updated clock port name
        .BUTTONS({buttons, rst}),
        .SWITCHES(switches),
        .LEDS(leds),
        .AUD_PWM(audio_pwm),
        .AUD_SD(),             // Added missing port
        .FPGA_SERIAL_RX(FPGA_SERIAL_RX),
        .FPGA_SERIAL_TX(FPGA_SERIAL_TX)
    );

    // Instantiate off-chip UART
    uart #(
        .BAUD_RATE(`BAUD_RATE),
        .CLOCK_FREQ(`CLOCK_FREQ)
    ) off_chip_uart (
        .clk(clk),
        .reset(rst),
        .data_in(data_in),
        .data_in_valid(data_in_valid),
        .data_in_ready(data_in_ready),
        .data_out(),
        .data_out_valid(),
        .data_out_ready(1'b0),
        .serial_in(FPGA_SERIAL_TX),
        .serial_out(FPGA_SERIAL_RX)
    );

    task ua_send(input [7:0] data);
        begin
            wait(data_in_ready);
            #1;
            data_in_valid = 1'b1;
            data_in = data;
            @(posedge clk); #1;
            data_in_valid = 1'b0;
        end
    endtask

    initial begin
        `ifndef IVERILOG
            $vcdpluson;
        `endif
        
        data_in = 8'd0;
        data_in_valid = 1'b0;
        buttons = 0;
        switches = 2'b11; // Enable both Piano and Audio Output
        
        rst = 1'b0;
        repeat (5) @(posedge clk); #1;
        rst = 1'b1;
        repeat (40) @(posedge clk); #1;
        rst = 1'b0;

        fork
            begin
                ua_send("z");
                ua_send("x");
                ua_send("c");
            end
            begin
                repeat (`CYCLES_PER_CHAR + 10) @(posedge clk);
                // Assertions for verification
                assert(top.fl_piano.fcw != 0) $display("Note playing!");
                else $error("FCW is 0, note not triggered.");
            end
        join

        repeat (`CYCLES_PER_SECOND / 5 + 50) @(posedge clk);
        $finish();
    end

    initial begin
        repeat (`CYCLES_PER_CHAR + `CYCLES_PER_SECOND * 4) @(posedge clk);
        $error("Timing out");
        $fatal();
    end
endmodule