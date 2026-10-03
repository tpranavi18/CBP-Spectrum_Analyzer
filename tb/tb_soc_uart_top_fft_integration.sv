`timescale 1ns/1ps

// ============================================================================
// tb_soc_uart_top.sv
// Integration self-checking testbench for:
//
//      AXI TB Master -> AXI Interconnect -> UART + FFT Accelerator
//
// Expected integration map used by this TB:
//      UART registers : 0x4000_0000 - ...
//      FFT control    : 0x4000_5000
//          +0x0000 START/CONTROL
//          +0x0004 STATUS
//      FFT memory     : 0x4000_6000
//          1024 x 32-bit words, 4 KB
//
// IMPORTANT:
// The FFT memory window is expected to translate to the NEXHUS local memory
// address space beginning at 0x1000.
// ============================================================================

module tb_soc_uart_top;

    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 32;
    parameter STRB_WIDTH = 4;
    parameter ID_WIDTH   = 8;

    logic clk;
    logic rst;

    // ------------------------------------------------------------------------
    // AXI S00 master interface
    // ------------------------------------------------------------------------
    logic [ID_WIDTH-1:0]      s00_axi_awid;
    logic [ADDR_WIDTH-1:0]    s00_axi_awaddr;
    logic [7:0]               s00_axi_awlen;
    logic [2:0]               s00_axi_awsize;
    logic [1:0]               s00_axi_awburst;
    logic                     s00_axi_awlock;
    logic [3:0]               s00_axi_awcache;
    logic [2:0]               s00_axi_awprot;
    logic [3:0]               s00_axi_awqos;
    logic [0:0]               s00_axi_awuser;
    logic                     s00_axi_awvalid;
    wire                      s00_axi_awready;

    logic [DATA_WIDTH-1:0]    s00_axi_wdata;
    logic [STRB_WIDTH-1:0]    s00_axi_wstrb;
    logic                     s00_axi_wlast;
    logic [0:0]               s00_axi_wuser;
    logic                     s00_axi_wvalid;
    wire                      s00_axi_wready;

    wire [ID_WIDTH-1:0]       s00_axi_bid;
    wire [1:0]                s00_axi_bresp;
    wire [0:0]                s00_axi_buser;
    wire                      s00_axi_bvalid;
    logic                     s00_axi_bready;

    logic [ID_WIDTH-1:0]      s00_axi_arid;
    logic [ADDR_WIDTH-1:0]    s00_axi_araddr;
    logic [7:0]               s00_axi_arlen;
    logic [2:0]               s00_axi_arsize;
    logic [1:0]               s00_axi_arburst;
    logic                     s00_axi_arlock;
    logic [3:0]               s00_axi_arcache;
    logic [2:0]               s00_axi_arprot;
    logic [3:0]               s00_axi_arqos;
    logic [0:0]               s00_axi_aruser;
    logic                     s00_axi_arvalid;
    wire                      s00_axi_arready;

    wire [ID_WIDTH-1:0]       s00_axi_rid;
    wire [DATA_WIDTH-1:0]     s00_axi_rdata;
    wire [1:0]                s00_axi_rresp;
    wire                      s00_axi_rlast;
    wire [0:0]                s00_axi_ruser;
    wire                      s00_axi_rvalid;
    logic                     s00_axi_rready;

    // ------------------------------------------------------------------------
    // UART external pins
    // ------------------------------------------------------------------------
    logic uart_rx_i;
    wire  uart_tx_o;

    // ------------------------------------------------------------------------
    // Test bookkeeping
    // ------------------------------------------------------------------------
    integer total_tests;
    integer passed_tests;
    integer failed_tests;
    integer i;
    integer timeout_count;

    integer input_fd;
    integer ref_fd;
    integer scan_status;
    integer expected_count;
    integer input_count;

    localparam integer FFT_SIZE = 1024;

    reg [15:0] input_real;
    reg [15:0] input_imag;
    reg [31:0] ref_index;
    reg [15:0] ref_real;
    reg [15:0] ref_imag;

    reg [31:0] fft_input [0:1023];
    reg [31:0] fft_expected [0:1023];
    reg [31:0] fft_readback [0:1023];

    reg [31:0] rd_data;
    reg [31:0] expected_data;
    reg        success;

    integer fft_memory_write_failures;
    integer fft_memory_read_failures;
    integer fft_result_failures;

    // ------------------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------------------
    soc_uart_fft_top dut (
        .clk              (clk),
        .rst              (rst),

        .s00_axi_awid     (s00_axi_awid),
        .s00_axi_awaddr   (s00_axi_awaddr),
        .s00_axi_awlen    (s00_axi_awlen),
        .s00_axi_awsize   (s00_axi_awsize),
        .s00_axi_awburst  (s00_axi_awburst),
        .s00_axi_awlock   (s00_axi_awlock),
        .s00_axi_awcache  (s00_axi_awcache),
        .s00_axi_awprot   (s00_axi_awprot),
        .s00_axi_awqos    (s00_axi_awqos),
        .s00_axi_awuser   (s00_axi_awuser),
        .s00_axi_awvalid  (s00_axi_awvalid),
        .s00_axi_awready  (s00_axi_awready),

        .s00_axi_wdata    (s00_axi_wdata),
        .s00_axi_wstrb    (s00_axi_wstrb),
        .s00_axi_wlast    (s00_axi_wlast),
        .s00_axi_wuser    (s00_axi_wuser),
        .s00_axi_wvalid   (s00_axi_wvalid),
        .s00_axi_wready   (s00_axi_wready),

        .s00_axi_bid      (s00_axi_bid),
        .s00_axi_bresp    (s00_axi_bresp),
        .s00_axi_buser    (s00_axi_buser),
        .s00_axi_bvalid   (s00_axi_bvalid),
        .s00_axi_bready   (s00_axi_bready),

        .s00_axi_arid     (s00_axi_arid),
        .s00_axi_araddr   (s00_axi_araddr),
        .s00_axi_arlen    (s00_axi_arlen),
        .s00_axi_arsize   (s00_axi_arsize),
        .s00_axi_arburst  (s00_axi_arburst),
        .s00_axi_arlock   (s00_axi_arlock),
        .s00_axi_arcache  (s00_axi_arcache),
        .s00_axi_arprot   (s00_axi_arprot),
        .s00_axi_arqos    (s00_axi_arqos),
        .s00_axi_aruser   (s00_axi_aruser),
        .s00_axi_arvalid  (s00_axi_arvalid),
        .s00_axi_arready  (s00_axi_arready),

        .s00_axi_rid      (s00_axi_rid),
        .s00_axi_rdata    (s00_axi_rdata),
        .s00_axi_rresp    (s00_axi_rresp),
        .s00_axi_rlast    (s00_axi_rlast),
        .s00_axi_ruser    (s00_axi_ruser),
        .s00_axi_rvalid   (s00_axi_rvalid),
        .s00_axi_rready   (s00_axi_rready),

        .uart_rx_i        (uart_rx_i),
        .uart_tx_o        (uart_tx_o)
    );

    // =========================================================================
    // CLOCK
    // =========================================================================
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // =========================================================================
    // AXI WRITE
    //
    // AWVALID and WVALID are held until their actual handshakes occur.
    // BREADY remains asserted only while waiting for the write response.
    // =========================================================================
    task automatic axi_write(
        input [31:0] addr,
        input [31:0] data,
        input [3:0]  strb,
        input [7:0]  id,
        output       success
    );
        integer t;
        reg aw_done;
        reg w_done;
        reg b_done;
        begin
            success = 1'b0;
            aw_done = 1'b0;
            w_done  = 1'b0;
            b_done  = 1'b0;

            @(negedge clk);

            s00_axi_awid    = id;
            s00_axi_awaddr  = addr;
            s00_axi_awlen   = 8'd0;
            s00_axi_awsize  = 3'b010;
            s00_axi_awburst = 2'b01;
            s00_axi_awlock  = 1'b0;
            s00_axi_awcache = 4'b0000;
            s00_axi_awprot  = 3'b000;
            s00_axi_awqos   = 4'b0000;
            s00_axi_awuser  = 1'b0;
            s00_axi_awvalid = 1'b1;

            s00_axi_wdata   = data;
            s00_axi_wstrb   = strb;
            s00_axi_wlast   = 1'b1;
            s00_axi_wuser   = 1'b0;
            s00_axi_wvalid  = 1'b1;

            s00_axi_bready  = 1'b0;

            for (t = 0; t < 1000; t = t + 1) begin
                @(posedge clk);

                if (!aw_done && s00_axi_awvalid && s00_axi_awready)
                    aw_done = 1'b1;

                if (!w_done && s00_axi_wvalid && s00_axi_wready)
                    w_done = 1'b1;

                if (aw_done && w_done)
                    break;
            end

            if (!(aw_done && w_done)) begin
                $display("[FAIL] AXI WRITE TIMEOUT: ADDR=0x%08h", addr);
                @(negedge clk);
                s00_axi_awvalid = 1'b0;
                s00_axi_wvalid  = 1'b0;
                s00_axi_bready  = 1'b0;
            end
            else begin
                @(negedge clk);
                s00_axi_awvalid = 1'b0;
                s00_axi_wvalid  = 1'b0;
                s00_axi_bready  = 1'b1;

                for (t = 0; t < 1000; t = t + 1) begin
                    @(posedge clk);

                    if (s00_axi_bvalid && s00_axi_bready) begin
                        b_done = 1'b1;

                        if (s00_axi_bid !== id) begin
                            $display("[FAIL] WRITE BID mismatch: expected=0x%02h got=0x%02h",
                                     id, s00_axi_bid);
                        end

                        if (s00_axi_bresp !== 2'b00) begin
                            $display("[FAIL] WRITE BRESP: ADDR=0x%08h BRESP=%b",
                                     addr, s00_axi_bresp);
                        end
                        else begin
                            success = 1'b1;
                        end

                        break;
                    end
                end

                @(negedge clk);
                s00_axi_bready = 1'b0;

                if (!b_done)
                    $display("[FAIL] AXI WRITE RESPONSE TIMEOUT: ADDR=0x%08h", addr);
            end
        end
    endtask

    // =========================================================================
    // AXI READ
    // =========================================================================
    task automatic axi_read(
        input  [31:0] addr,
        input  [7:0]  id,
        output [31:0] data,
        output        success
    );
        integer t;
        reg ar_done;
        reg r_done;
        begin
            data    = 32'hXXXXXXXX;
            success = 1'b0;
            ar_done = 1'b0;
            r_done  = 1'b0;

            @(negedge clk);

            s00_axi_arid    = id;
            s00_axi_araddr  = addr;
            s00_axi_arlen   = 8'd0;
            s00_axi_arsize  = 3'b010;
            s00_axi_arburst = 2'b01;
            s00_axi_arlock  = 1'b0;
            s00_axi_arcache = 4'b0000;
            s00_axi_arprot  = 3'b000;
            s00_axi_arqos   = 4'b0000;
            s00_axi_aruser  = 1'b0;
            s00_axi_arvalid = 1'b1;
            s00_axi_rready  = 1'b0;

            for (t = 0; t < 1000; t = t + 1) begin
                @(posedge clk);

                if (!ar_done && s00_axi_arvalid && s00_axi_arready)
                    ar_done = 1'b1;

                if (ar_done)
                    break;
            end

            if (!ar_done) begin
                $display("[FAIL] AXI READ ADDRESS TIMEOUT: ADDR=0x%08h", addr);
                @(negedge clk);
                s00_axi_arvalid = 1'b0;
            end
            else begin
                @(negedge clk);
                s00_axi_arvalid = 1'b0;
                s00_axi_rready  = 1'b1;

                for (t = 0; t < 1000; t = t + 1) begin
                    @(posedge clk);

                    if (s00_axi_rvalid && s00_axi_rready) begin
                        r_done = 1'b1;
                        data   = s00_axi_rdata;

                        if (s00_axi_rid !== id)
                            $display("[FAIL] READ RID mismatch: expected=0x%02h got=0x%02h",
                                     id, s00_axi_rid);

                        if (s00_axi_rresp !== 2'b00) begin
                            $display("[FAIL] READ RRESP: ADDR=0x%08h RRESP=%b",
                                     addr, s00_axi_rresp);
                        end
                        else if (s00_axi_rlast !== 1'b1) begin
                            $display("[FAIL] READ RLAST not asserted: ADDR=0x%08h", addr);
                        end
                        else begin
                            success = 1'b1;
                        end

                        break;
                    end
                end

                @(negedge clk);
                s00_axi_rready = 1'b0;

                if (!r_done)
                    $display("[FAIL] AXI READ RESPONSE TIMEOUT: ADDR=0x%08h", addr);
            end
        end
    endtask

    // =========================================================================
    // INITIALIZE
    // =========================================================================
        reg [15:0] input_real;
    reg [15:0] input_imag;
    reg [31:0] ref_index;
    reg [15:0] ref_real;
    reg [15:0] ref_imag;
initial begin
        s00_axi_awid    = '0;
        s00_axi_awaddr  = '0;
        s00_axi_awlen   = '0;
        s00_axi_awsize  = 3'b010;
        s00_axi_awburst = 2'b01;
        s00_axi_awlock  = 1'b0;
        s00_axi_awcache = '0;
        s00_axi_awprot  = '0;
        s00_axi_awqos   = '0;
        s00_axi_awuser  = '0;
        s00_axi_awvalid = 1'b0;

        s00_axi_wdata   = '0;
        s00_axi_wstrb   = 4'b0000;
        s00_axi_wlast   = 1'b1;
        s00_axi_wuser   = '0;
        s00_axi_wvalid  = 1'b0;

        s00_axi_bready  = 1'b0;

        s00_axi_arid    = '0;
        s00_axi_araddr  = '0;
        s00_axi_arlen   = '0;
        s00_axi_arsize  = 3'b010;
        s00_axi_arburst = 2'b01;
        s00_axi_arlock  = 1'b0;
        s00_axi_arcache = '0;
        s00_axi_arprot  = '0;
        s00_axi_arqos   = '0;
        s00_axi_aruser  = '0;
        s00_axi_arvalid = 1'b0;

        s00_axi_rready  = 1'b0;

        uart_rx_i = 1'b1;

        total_tests = 0;
        passed_tests = 0;
        failed_tests = 0;

        fft_memory_write_failures = 0;
        fft_memory_read_failures  = 0;
        fft_result_failures       = 0;

        rst = 1'b1;

        repeat (5) @(posedge clk);
        rst = 1'b0;

        $display("");
        $display("======================================================================");
        $display("        RISC-V SPECTRUM ANALYZER SoC - IP INTEGRATION TB");
        $display("======================================================================");
        $display("UART base       : 0x4000_0000");
        $display("FFT CTRL base   : 0x4000_5000");
        $display("FFT MEMORY base : 0x4000_6000");
        $display("FFT size        : 1024 points");
        $display("======================================================================");
        $display("[RESET] DUT released from reset at time %0t", $time);
        $display("");

        // ====================================================================
        // TEST 1: UART reset/read path
        // ====================================================================
        total_tests = total_tests + 1;

        $display("---------------------------------------------------------------------");
        $display("TEST 1 : UART RESET READ");
        $display("---------------------------------------------------------------------");

        axi_read(32'h4000_0014, 8'h01, rd_data, success);

        if (success && rd_data === 32'h0000_0060) begin
            passed_tests = passed_tests + 1;
            $display("[PASS] UART LSR reset read = 0x%08h", rd_data);
        end
        else begin
            failed_tests = failed_tests + 1;
            $display("[FAIL] UART LSR reset read");
            $display("       Expected = 0x00000060");
            $display("       Received = 0x%08h", rd_data);
        end

        // ====================================================================
        // TEST 2: UART write path
        // ====================================================================
        total_tests = total_tests + 1;

        $display("");
        $display("---------------------------------------------------------------------");
        $display("TEST 2 : UART REGISTER WRITE");
        $display("---------------------------------------------------------------------");

        axi_write(32'h4000_000C, 32'h0000_0003, 4'b1111, 8'h02, success);

        if (success) begin
            passed_tests = passed_tests + 1;
            $display("[PASS] UART LCR write completed through AXI interconnect");
        end
        else begin
            failed_tests = failed_tests + 1;
            $display("[FAIL] UART LCR write");
        end

        // ====================================================================
        // TEST 3: Consecutive UART read after write
        // ====================================================================
        total_tests = total_tests + 1;

        $display("");
        $display("---------------------------------------------------------------------");
        $display("TEST 3 : UART CONSECUTIVE READ");
        $display("---------------------------------------------------------------------");

        axi_read(32'h4000_0014, 8'h03, rd_data, success);

        if (success) begin
            passed_tests = passed_tests + 1;
            $display("[PASS] UART read after write completed");
            $display("       LSR = 0x%08h", rd_data);
        end
        else begin
            failed_tests = failed_tests + 1;
            $display("[FAIL] UART consecutive read");
        end

        // ====================================================================
        // TEST 4: Load FFT input vector
        // ====================================================================
        // ====================================================================
        // TEST 4 : LOAD FFT INPUT VECTOR
        // Input file format: <REAL_HEX> <IMAG_HEX> per sample.
        // Pack each complex sample as {REAL[15:0], IMAG[15:0]}.
        // ====================================================================
        input_fd = $fopen("mixed_1024_input.txt", "r");
        if (input_fd == 0) begin
            $display("[FAIL] Could not open mixed_1024_input.txt");
            failed_tests = failed_tests + 1;
        end
        else begin
            input_count = 0;
            while (input_count < FFT_SIZE) begin
                scan_status = $fscanf(input_fd, "%h %h\n",
                                       input_real, input_imag);
                if (scan_status != 2)
                    break;

                fft_input[input_count] = {input_real, input_imag};
                input_count = input_count + 1;
            end
            $fclose(input_fd);

            $display("[INFO] Input samples loaded from file = %0d",
                     input_count);
            if (input_count == FFT_SIZE) begin
                $display("[PASS] 1024 FFT input samples loaded");
            end
            else begin
                $display("[FAIL] Expected 1024 FFT input samples, got %0d",
                         input_count);
                failed_tests = failed_tests + 1;
            end
        end

        $display("");
        $display("---------------------------------------------------------------------");
        $display("TEST 5 : FFT MEMORY WRITE - 1024 WORDS");
        $display("---------------------------------------------------------------------");

        fft_memory_write_failures = 0;

        for (i = 0; i < 1024; i = i + 1) begin
            axi_write(
                32'h4000_6000 + (i * 4),
                fft_input[i],
                4'b1111,
                8'h10,
                success
            );

            if (!success)
                fft_memory_write_failures = fft_memory_write_failures + 1;

            if ((i == 0) || (i == 255) || (i == 511) ||
                (i == 767) || (i == 1023))
                $display("[FFT MEM WRITE] word=%0d addr=0x%08h data=0x%08h %s",
                         i,
                         32'h4000_6000 + (i * 4),
                         fft_input[i],
                         success ? "PASS" : "FAIL");
        end

        if (fft_memory_write_failures == 0) begin
            passed_tests = passed_tests + 1;
            $display("[PASS] All 1024 FFT memory writes completed successfully");
        end
        else begin
            failed_tests = failed_tests + 1;
            $display("[FAIL] FFT memory write failures = %0d",
                     fft_memory_write_failures);
        end

        // ====================================================================
        // TEST 6: Read back representative input locations
        // ====================================================================
        total_tests = total_tests + 1;

        $display("");
        $display("---------------------------------------------------------------------");
        $display("TEST 6 : FFT MEMORY READBACK");
        $display("---------------------------------------------------------------------");

        fft_memory_read_failures = 0;

        for (i = 0; i < 1024; i = i + 1) begin
            axi_read(
                32'h4000_6000 + (i * 4),
                8'h11,
                rd_data,
                success
            );

            if (!success || rd_data !== fft_input[i]) begin
                fft_memory_read_failures = fft_memory_read_failures + 1;

                if (fft_memory_read_failures <= 10)
                    $display("[FAIL] FFT memory readback word=%0d addr=0x%08h expected=0x%08h got=0x%08h",
                             i,
                             32'h4000_6000 + (i * 4),
                             fft_input[i],
                             rd_data);
            end

            if ((i == 0) || (i == 255) || (i == 511) ||
                (i == 767) || (i == 1023))
                $display("[FFT MEM READ] word=%0d addr=0x%08h data=0x%08h %s",
                         i,
                         32'h4000_6000 + (i * 4),
                         rd_data,
                         (!success || rd_data !== fft_input[i]) ? "FAIL" : "PASS");
        end

        if (fft_memory_read_failures == 0) begin
            passed_tests = passed_tests + 1;
            $display("[PASS] All 1024 FFT memory words read back correctly");
        end
        else begin
            failed_tests = failed_tests + 1;
            $display("[FAIL] FFT memory readback failures = %0d",
                     fft_memory_read_failures);
        end

        // ====================================================================
        // TEST 7: Start FFT
        // ====================================================================
        total_tests = total_tests + 1;

        $display("");
        $display("---------------------------------------------------------------------");
        $display("TEST 7 : FFT START");
        $display("---------------------------------------------------------------------");

        axi_write(
            32'h4000_5000,
            32'h0000_0001,
            4'b1111,
            8'h20,
            success
        );

        if (success) begin
            passed_tests = passed_tests + 1;
            $display("[PASS] FFT START write accepted");
            $display("       CTRL @ 0x4000_5000 = 0x00000001");
        end
        else begin
            failed_tests = failed_tests + 1;
            $display("[FAIL] FFT START write");
        end

        // ====================================================================
        // TEST 8: Poll FFT status
        // ====================================================================
        total_tests = total_tests + 1;

        $display("");
        $display("---------------------------------------------------------------------");
        $display("TEST 8 : FFT STATUS / COMPLETION");
        $display("---------------------------------------------------------------------");

        begin : status_poll_block
            integer poll;
            reg done_seen;
            reg busy_seen;

            done_seen = 1'b0;
            busy_seen = 1'b0;

            for (poll = 0; poll < 5000; poll = poll + 1) begin
                axi_read(
                    32'h4000_5004,
                    8'h21,
                    rd_data,
                    success
                );

                if (!success) begin
                    $display("[FAIL] FFT STATUS read transaction failed");
                    break;
                end

                if (rd_data[1])
                    busy_seen = 1'b1;

                if (rd_data[0]) begin
                    done_seen = 1'b1;
                    $display("[FFT STATUS] DONE detected after %0d polls | STATUS=0x%08h",
                             poll + 1, rd_data);
                    break;
                end

                if ((poll < 5) || ((poll + 1) % 100 == 0))
                    $display("[FFT STATUS] poll=%0d STATUS=0x%08h BUSY=%0b DONE=%0b",
                             poll + 1, rd_data, rd_data[1], rd_data[0]);
            end

            if (done_seen) begin
                passed_tests = passed_tests + 1;
                $display("[PASS] FFT completed successfully");
                $display("       BUSY was observed = %0b", busy_seen);
            end
            else begin
                failed_tests = failed_tests + 1;
                $display("[FAIL] FFT completion timeout");
                $display("       Last STATUS = 0x%08h", rd_data);
            end
        end

        // ====================================================================
        // DEBUG: Inspect NEXHUS internal memory immediately after FFT DONE
        // This determines whether the X values appear inside the FFT memory
        // or only when the result is read back through the AXI M02 path.
        // ====================================================================
        $display("");
        $display("=====================================================================");
        $display("POST-FFT INTERNAL MEMORY DEBUG");
        $display("=====================================================================");
        $display("[INTERNAL MEM] mem[0]    = 0x%08h",
                 dut.u_fft_accel.u_fft_loadstore_wrapper.u_fft_top.u_stage_ctrl.u_sample_mem.u_mem.mem[0]);
        $display("[INTERNAL MEM] mem[1]    = 0x%08h",
                 dut.u_fft_accel.u_fft_loadstore_wrapper.u_fft_top.u_stage_ctrl.u_sample_mem.u_mem.mem[1]);
        $display("[INTERNAL MEM] mem[2]    = 0x%08h",
                 dut.u_fft_accel.u_fft_loadstore_wrapper.u_fft_top.u_stage_ctrl.u_sample_mem.u_mem.mem[2]);
        $display("[INTERNAL MEM] mem[511]  = 0x%08h",
                 dut.u_fft_accel.u_fft_loadstore_wrapper.u_fft_top.u_stage_ctrl.u_sample_mem.u_mem.mem[511]);
        $display("[INTERNAL MEM] mem[512]  = 0x%08h",
                 dut.u_fft_accel.u_fft_loadstore_wrapper.u_fft_top.u_stage_ctrl.u_sample_mem.u_mem.mem[512]);
        $display("[INTERNAL MEM] mem[1023] = 0x%08h",
                 dut.u_fft_accel.u_fft_loadstore_wrapper.u_fft_top.u_stage_ctrl.u_sample_mem.u_mem.mem[1023]);
        $display("=====================================================================");

        // ====================================================================
        // TEST 9: Load reference output
        // ====================================================================
        // ====================================================================
        // TEST 9 : LOAD FFT REFERENCE
        // Reference format: <INDEX> <REAL_HEX> <IMAG_HEX>.
        // Pack each expected bin as {REAL[15:0], IMAG[15:0]}.
        // ====================================================================
        ref_fd = $fopen("cmodel_fft_out_mixed_1024.txt", "r");
        if (ref_fd == 0) begin
            $display("[FAIL] Could not open cmodel_fft_out_mixed_1024.txt");
            failed_tests = failed_tests + 1;
        end
        else begin
            expected_count = 0;
            while (expected_count < FFT_SIZE) begin
                scan_status = $fscanf(ref_fd, "%d %h %h\n",
                                       ref_index, ref_real, ref_imag);
                if (scan_status != 3)
                    break;

                fft_expected[expected_count] = {ref_real, ref_imag};
                expected_count = expected_count + 1;
            end
            $fclose(ref_fd);

            $display("[INFO] Reference FFT words loaded = %0d",
                     expected_count);
            if (expected_count == FFT_SIZE) begin
                $display("[PASS] Reference contains all 1024 expected bins");
            end
            else begin
                $display("[FAIL] Expected 1024 reference bins, got %0d",
                         expected_count);
                failed_tests = failed_tests + 1;
            end
        end

        $display("");
        $display("---------------------------------------------------------------------");
        $display("TEST 10 : FFT RESULT CHECK - ALL 1024 BINS");
        $display("---------------------------------------------------------------------");

        fft_result_failures = 0;

        if (expected_count == 1024) begin
            for (i = 0; i < 1024; i = i + 1) begin
                axi_read(
                    32'h4000_6000 + (i * 4),
                    8'h22,
                    rd_data,
                    success
                );

                fft_readback[i] = rd_data;

                if (!success || rd_data !== fft_expected[i]) begin
                    fft_result_failures = fft_result_failures + 1;

                    if (fft_result_failures <= 20)
                        $display("[FFT MISMATCH] bin=%0d addr=0x%08h expected=0x%08h got=0x%08h",
                                 i,
                                 32'h4000_6000 + (i * 4),
                                 fft_expected[i],
                                 rd_data);
                end

                if ((i == 0) || (i == 1) || (i == 2) ||
                    (i == 511) || (i == 512) || (i == 1023))
                    $display("[FFT BIN] %0d : expected=0x%08h got=0x%08h %s",
                             i,
                             fft_expected[i],
                             rd_data,
                             (!success || rd_data !== fft_expected[i]) ? "FAIL" : "PASS");
            end
        end
        else begin
            fft_result_failures = 1024;
        end

        if (fft_result_failures == 0) begin
            passed_tests = passed_tests + 1;
            $display("");
            $display("[PASS] FFT RESULT CHECK: 1024 / 1024 bins match reference");
        end
        else begin
            failed_tests = failed_tests + 1;
            $display("");
            $display("[FAIL] FFT RESULT CHECK: %0d / 1024 bins mismatched",
                     fft_result_failures);
        end

        // ====================================================================
        // FINAL SUMMARY
        // ====================================================================
        $display("");
        $display("======================================================================");
        $display("                     FINAL TEST SUMMARY");
        $display("======================================================================");
        $display("UART reset/read       : %s", (passed_tests >= 1) ? "PASS" : "CHECK");
        $display("UART write            : completed");
        $display("UART consecutive read : completed");
        $display("FFT memory writes     : %s",
                 (fft_memory_write_failures == 0) ? "PASS" : "FAIL");
        $display("FFT memory readback   : %s",
                 (fft_memory_read_failures == 0) ? "PASS" : "FAIL");
        $display("FFT start             : completed");
        $display("FFT completion        : checked");
        $display("FFT result            : %0d / 1024 mismatches",
                 fft_result_failures);
        $display("---------------------------------------------------------------------");
        $display("PASS TESTS            : %0d", passed_tests);
        $display("FAIL TESTS            : %0d", failed_tests);
        $display("======================================================================");

        if (failed_tests == 0 &&
            fft_memory_write_failures == 0 &&
            fft_memory_read_failures == 0 &&
            fft_result_failures == 0) begin

            $display("");
            $display("######################################################################");
            $display("#                    INTEGRATION TEST : PASS                         #");
            $display("#  UART + AXI INTERCONNECT + FFT CONTROL + FFT MEMORY + FFT RESULT  #");
            $display("#                    ALL CHECKS PASSED                              #");
            $display("######################################################################");
        end
        else begin
            $display("");
            $display("######################################################################");
            $display("#                    INTEGRATION TEST : FAIL                         #");
            $display("#          Check the FAIL messages above for the first error.       #");
            $display("######################################################################");
        end

        $finish;
    end

endmodule
