`timescale 1ns/1ns
`define CLK_PERIOD 8

module mem_controller_tb();

    localparam FIFO_WIDTH = 8;
    localparam FIFO_DEPTH = 8;
    localparam MEM_DEPTH = 256;
    localparam NUM_WRITES = 10;
    localparam NUM_READS = 10;
    localparam CHAR0 = 8'd65; /* ASCII 'A' */

    logic clk = 0;
    logic rst = 0;

    always #(`CLK_PERIOD/2) clk <= ~clk;

    /* Mem <-> RX_FIFO and TX_FIFO signals */
    wire mem_rx_empty;
    wire mem_tx_full;
    wire mem_rx_rd_en;
    wire mem_tx_wr_en;
    wire [FIFO_WIDTH-1:0] rx_dout;
    wire [FIFO_WIDTH-1:0] tx_din;
    wire [5:0] LEDS;

    /* TB <-> RX_FIFO signals */
    logic tb_rx_wr_en = 0;
    logic [FIFO_WIDTH-1:0] tb_rx_din;
    wire tb_rx_full;

    wire tb_tx_empty;
    wire [FIFO_WIDTH-1:0] tb_tx_dout;
    logic tb_tx_rd_en = 0;

    fifo #(.WIDTH(FIFO_WIDTH), .DEPTH(FIFO_DEPTH)) rx_fifo (
        .clk(clk), .rst(rst),
        .wr_en(tb_rx_wr_en), .din(tb_rx_din), .full(tb_rx_full),
        .empty(mem_rx_empty), .dout(rx_dout), .rd_en(mem_rx_rd_en)
    );

    fifo #(.WIDTH(FIFO_WIDTH), .DEPTH(FIFO_DEPTH)) tx_fifo (
        .clk(clk), .rst(rst),
        .wr_en(mem_tx_wr_en), .din(tx_din), .full(mem_tx_full),
        .empty(tb_tx_empty), .dout(tb_tx_dout), .rd_en(tb_tx_rd_en)
    );

    mem_controller #(.FIFO_WIDTH(FIFO_WIDTH)) mem_ctrl (
        .clk(clk), .rst(rst),
        .rx_fifo_empty(mem_rx_empty),
        .tx_fifo_full(mem_tx_full),
        .din(rx_dout), .rx_fifo_rd_en(mem_rx_rd_en),
        .tx_fifo_wr_en(mem_tx_wr_en), .dout(tx_din),
        .state_leds(LEDS)
    );

    logic [23:0] test_write [NUM_WRITES];
    logic [15:0] test_read [NUM_READS];
    logic [7:0] test_read_vals [NUM_READS];
    int tests_failed = 0;
    logic verified_write = 0;
    logic verified_read = 0;

    task write_to_rx_fifo(input [FIFO_WIDTH-1:0] write_data);
        begin
            #1;
            wait(tb_rx_full == 0);
            tb_rx_wr_en = (tb_rx_full) ? 1'b0 : 1'b1;
            tb_rx_din = write_data;
            @(posedge clk); #1;
            tb_rx_wr_en = 1'b0;
        end
    endtask

    task read_from_tx_fifo(output [FIFO_WIDTH-1:0] rd_data);
        begin
            #1;
            wait(tb_tx_empty == 0);
            tb_tx_rd_en = (tb_tx_empty) ? 1'b0 : 1'b1;
            @(posedge clk); #1;
            rd_data = tb_tx_dout;
            tb_tx_rd_en = 1'b0;
        end
    endtask

    task send_n_writes(input int n);
        for (int w = 0; w < n; w++) begin
            write_to_rx_fifo(test_write[w][7:0]);
            write_to_rx_fifo(test_write[w][15:8]);
            write_to_rx_fifo(test_write[w][23:16]);
            wait (verified_write == 1);
        end
    endtask

    task verify_n_writes(input int n);
        logic [7:0] v_addr, v_data;
        for (int w = 0; w < n; w++) begin
            verified_write = 0;
            v_addr = test_write[w][15:8];
            v_data = test_write[w][23:16];
            repeat (10) @(posedge clk);
            if (mem_ctrl.mem.mem[v_addr] == v_data)
                $display("PASSED! Addr: %d, Data: %d", v_addr, v_data);
            else begin
                $display("FAILED! Expected : %d Actual %d", v_data, mem_ctrl.mem.mem[v_addr]);
                tests_failed++;
            end
            verified_write = 1;
            #1;
        end
    endtask

    task send_n_reads(input int n);
        for (int w = 0; w < n; w++) begin
            write_to_rx_fifo(test_read[w][7:0]);
            write_to_rx_fifo(test_read[w][15:8]);
            wait (verified_read == 1);
        end
    endtask

    logic [FIFO_WIDTH-1 : 0] read_data;

    task verify_n_reads(input int n);
        for (int w = 0; w < n; w++) begin
            verified_read = 0;
            read_from_tx_fifo(read_data);
            if (read_data == test_read_vals[w])
                $display("PASSED! Expected : %d Actual %d", test_read_vals[w], read_data);
            else begin
                $display("FAILED! Expected : %d Actual %d", test_read_vals[w], read_data);
                tests_failed++;
            end
            @(posedge clk);
            verified_read = 1;
            #1;
        end
    endtask

    initial begin: TB
        for (int i = 0; i < NUM_WRITES; i++) begin
            test_write[i] = {CHAR0 + i, 8'(10 + i), 8'd49};
            test_read[i] = {test_write[i][15:8], 8'd48};
            test_read_vals[i] = test_write[i][23:16];
        end

        rst = 1'b1; repeat (5) @(posedge clk); rst = 1'b0; @(posedge clk);
        repeat (10) @(posedge clk);

        /* Concurrency Tests */
        fork
            begin send_n_writes(8); end
            begin verify_n_writes(8); end
        join

        fork
            begin send_n_reads(8); end
            begin verify_n_reads(8); end
        join

        /* Interruption Tests */
        write_to_rx_fifo(test_write[8][7:0]);
        repeat (5) @(posedge clk);
        write_to_rx_fifo(test_write[8][15:8]);
        repeat (5) @(posedge clk);
        write_to_rx_fifo(test_write[8][23:16]);
        repeat (10) @(posedge clk);

        if (tests_failed == 0) $display("\nAll tests PASSED!\n");
        else $display("\n%d tests FAILED.\n", tests_failed);

        $finish();
    end
endmodule