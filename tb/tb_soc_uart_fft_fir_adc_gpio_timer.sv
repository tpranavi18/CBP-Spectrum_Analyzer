`timescale 1ns/1ps

// ============================================================================
// tb_soc_uart_fft_fir_integration.sv
// Integration self-checking testbench for:
//
//      AXI TB Master -> AXI Interconnect -> UART + FIR + FFT + ADC
//
// Expected integration map used by this TB:
//      UART registers : 0x4000_0000 - ...
//      FFT control    : 0x4000_5000
//          +0x0000 START/CONTROL
//          +0x0004 STATUS
//      FIR control    : 0x4000_7000
//      FFT memory     : 0x4000_6000
//          1024 x 32-bit words, 4 KB
//      FIR control    : 0x4000_7000
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
    // ADC external sample interface
    // ------------------------------------------------------------------------
    logic [11:0] adc_sample_in;
    logic        adc_sample_valid;
    wire         adc_irq_sample;
    wire         adc_irq_overrun;

    tri  [31:0]  gpio_io;
    wire         gpio_intr;
    logic        timer_ext_meas_i;
    logic        timer_capture_i;
    wire         timer_pwm_o;
    wire         timer_trigger_o;
    wire         timer_irq;

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

    reg [31:0] input_real;
    reg [31:0] input_imag;
    reg [31:0] ref_index;
    reg [31:0] ref_real;
    reg [31:0] ref_imag;

    reg [31:0] fft_input [0:1023];
    reg [31:0] fft_expected [0:1023];
    reg [31:0] fft_readback [0:1023];

    reg [31:0] rd_data;
    reg [31:0] expected_data;
    reg        success;

    integer fft_memory_write_failures;
    integer fft_memory_read_failures;
    integer fft_result_failures;

    integer fir_coeff_failures;
    integer fir_control_failures;
    integer fir_status_failures;

    integer adc_failures;
    reg     adc_done_ok;
    reg     adc_sample_ok;
    reg     adc_fifo_ok;
    reg     adc_irq_ok;

    reg fft_start_ok;
    reg fft_done_ok;
    reg fft_busy_seen;
    integer poll;

    reg test1_ok;
    reg test2_ok;
    reg test3_ok;
    reg test4_ok;
    reg test5_ok;
    reg test6_ok;
    reg test7_ok;
    reg test8_ok;
    reg test9_ok;
    reg test10_ok;
    reg test11_ok;
    reg test12_ok;
    integer gpio_failures;
    integer timer_failures;

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
        .uart_tx_o        (uart_tx_o),

        .adc_sample_in    (adc_sample_in),
        .adc_sample_valid (adc_sample_valid),
        .adc_irq_sample   (adc_irq_sample),
        .adc_irq_overrun  (adc_irq_overrun),
        .gpio_io          (gpio_io),
        .gpio_intr        (gpio_intr),
        .timer_ext_meas_i (timer_ext_meas_i),
        .timer_capture_i  (timer_capture_i),
        .timer_pwm_o      (timer_pwm_o),
        .timer_trigger_o  (timer_trigger_o),
        .timer_irq        (timer_irq)
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
    // INITIALIZE AND RUN TEST SEQUENCE
    // =========================================================================
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
        adc_sample_in = 12'h000;
        adc_sample_valid = 1'b0;
        timer_ext_meas_i = 1'b0;
        timer_capture_i  = 1'b0;

        total_tests = 0;
        passed_tests = 0;
        failed_tests = 0;

        fft_memory_write_failures = 0;
        fft_memory_read_failures  = 0;
        fft_result_failures       = 0;

        fft_start_ok  = 1'b0;
        fft_done_ok   = 1'b0;
        fft_busy_seen = 1'b0;

        test1_ok = 1'b0;
        test2_ok = 1'b0;
        test3_ok = 1'b0;
        test4_ok = 1'b0;
        test5_ok = 1'b0;
        test6_ok = 1'b0;
        test7_ok = 1'b0;
        test8_ok = 1'b0;
        test9_ok = 1'b0;
        test10_ok = 1'b0;
        test11_ok = 1'b0;
        test12_ok = 1'b0;
        gpio_failures = 0;
        timer_failures = 0;

        adc_failures = 0;
        adc_done_ok  = 1'b0;
        adc_sample_ok = 1'b0;
        adc_fifo_ok = 1'b0;
        adc_irq_ok = 1'b0;

        rst = 1'b1;

        repeat (5) @(posedge clk);
        rst = 1'b0;

        $display("");
        $display("======================================================================");
        $display("        RISC-V SPECTRUM ANALYZER SoC - IP INTEGRATION TB");
        $display("======================================================================");
        $display("UART base       : 0x4000_0000");
        $display("Timer base      : 0x4000_1000");
        $display("GPIO base       : 0x4000_2000");
        $display("ADC base        : 0x4000_3000");
        $display("FFT CTRL base   : 0x4000_5000");
        $display("FFT MEMORY base : 0x4000_6000");
        $display("FIR CTRL base   : 0x4000_7000");
        $display("ADC CTRL base   : 0x4000_3000");
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
            test1_ok = 1'b1;
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
            test2_ok = 1'b1;
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
            test3_ok = 1'b1;
            passed_tests = passed_tests + 1;
            $display("[PASS] UART read after write completed");
            $display("       LSR = 0x%08h", rd_data);
        end
        else begin
            failed_tests = failed_tests + 1;
            $display("[FAIL] UART consecutive read");
        end

        // ====================================================================
        // TEST 4: FIR AXI-Lite CONTROL PATH THROUGH AXI INTERCONNECT
        //
        // FIR control window:
        //   0x4000_7000 + local FIR register offset
        //
        // This test verifies:
        //   1. M03 address decode through the AXI interconnect
        //   2. AXI4-Lite write/read response path to fir_top
        //   3. FIR enable register
        //   4. FIR coefficient registers
        //   5. FIR coefficient readback
        //   6. FIR load command
        //   7. FIR FIFO status register
        //
        // The FIR AXI-Stream data path is intentionally not exercised here
        // because the current SoC top has no AXI-Stream source/sink.
        // ====================================================================

        total_tests = total_tests + 1;

        $display("");
        $display("======================================================================");
        $display("TEST 4 : FIR AXI-LITE CONTROL THROUGH AXI INTERCONNECT");
        $display("======================================================================");

        fir_coeff_failures  = 0;
        fir_control_failures = 0;
        fir_status_failures  = 0;

        // ------------------------------------------------------------
        // 4A. Read FIR control register after reset
        // Expected: enable = 0
        // ------------------------------------------------------------
        axi_read(
            32'h4000_7000,
            8'h30,
            rd_data,
            success
        );

        if (success && rd_data === 32'h0000_0000) begin
            $display("[PASS] FIR CONTROL RESET: 0x%08h", rd_data);
        end
        else begin
            fir_control_failures = fir_control_failures + 1;
            $display("[FAIL] FIR CONTROL RESET: expected=0x00000000 got=0x%08h",
                     rd_data);
        end

        // ------------------------------------------------------------
        // 4B. Program all 32 FIR coefficients.
        // Coefficient i = i+1.
        // ------------------------------------------------------------
        for (i = 0; i < 32; i = i + 1) begin
            axi_write(
                32'h4000_7010 + (i * 4),
                i + 1,
                4'h3,
                8'h31,
                success
            );

            if (!success) begin
                fir_coeff_failures = fir_coeff_failures + 1;
                if (fir_coeff_failures <= 4)
                    $display("[FAIL] FIR COEFF WRITE: index=%0d", i);
            end
        end

        // ------------------------------------------------------------
        // 4C. Read back all 32 coefficient registers.
        // ------------------------------------------------------------
        for (i = 0; i < 32; i = i + 1) begin
            axi_read(
                32'h4000_7010 + (i * 4),
                8'h32,
                rd_data,
                success
            );

            expected_data = i + 1;

            if (!success || rd_data !== expected_data) begin
                fir_coeff_failures = fir_coeff_failures + 1;
                if (fir_coeff_failures <= 10)
                    $display("[FAIL] FIR COEFF READBACK: index=%0d expected=0x%08h got=0x%08h",
                             i, expected_data, rd_data);
            end
        end

        if (fir_coeff_failures == 0) begin
            $display("[PASS] FIR COEFFICIENT PATH: 32 / 32 registers verified");
        end
        else begin
            $display("[FAIL] FIR COEFFICIENT PATH: %0d failures",
                     fir_coeff_failures);
        end

        // ------------------------------------------------------------
        // 4D. Load the programmed coefficients into the active bank.
        // ------------------------------------------------------------
        axi_write(
            32'h4000_7004,
            32'h0000_0001,
            4'hF,
            8'h33,
            success
        );

        if (success)
            $display("[PASS] FIR COEFFICIENT LOAD COMMAND");
        else begin
            fir_control_failures = fir_control_failures + 1;
            $display("[FAIL] FIR COEFFICIENT LOAD COMMAND");
        end

        // ------------------------------------------------------------
        // 4E. Read status before enabling FIR.
        // With no AXI-Stream input, input FIFO and output FIFO should
        // both be empty: status bits [3:0] = 4'b1010.
        // ------------------------------------------------------------
        axi_read(
            32'h4000_7008,
            8'h34,
            rd_data,
            success
        );

        if (success && rd_data[3:0] === 4'b1010) begin
            $display("[PASS] FIR FIFO STATUS AFTER RESET/LOAD: 0x%08h", rd_data);
        end
        else begin
            fir_status_failures = fir_status_failures + 1;
            $display("[FAIL] FIR FIFO STATUS: expected low nibble=0xA got=0x%08h",
                     rd_data);
        end

        // ------------------------------------------------------------
        // 4F. Enable FIR.
        // ------------------------------------------------------------
        axi_write(
            32'h4000_7000,
            32'h0000_0001,
            4'hF,
            8'h35,
            success
        );

        if (!success) begin
            fir_control_failures = fir_control_failures + 1;
            $display("[FAIL] FIR ENABLE WRITE");
        end

        // Read back enable register.
        axi_read(
            32'h4000_7000,
            8'h36,
            rd_data,
            success
        );

        if (success && rd_data === 32'h0000_0001) begin
            $display("[PASS] FIR ENABLE READBACK: 0x%08h", rd_data);
        end
        else begin
            fir_control_failures = fir_control_failures + 1;
            $display("[FAIL] FIR ENABLE READBACK: expected=0x00000001 got=0x%08h",
                     rd_data);
        end

        if (fir_coeff_failures == 0 &&
            fir_control_failures == 0 &&
            fir_status_failures == 0) begin
            test4_ok = 1'b1;
            passed_tests = passed_tests + 1;
            $display("");
            $display("[PASS] FIR AXI-LITE INTEGRATION: M03 -> FIR CONTROL VERIFIED");
        end
        else begin
            failed_tests = failed_tests + 1;
            $display("");
            $display("[FAIL] FIR AXI-LITE INTEGRATION");
        end

        // Disable FIR before continuing with the FFT test sequence.
        axi_write(
            32'h4000_7000,
            32'h0000_0000,
            4'hF,
            8'h37,
            success
        );

        // ====================================================================
        // TEST 5: LOAD FFT INPUT VECTOR
        // ====================================================================
        // Input file format: <REAL_HEX> <IMAG_HEX> per sample.
        // Pack each complex sample as {REAL[15:0], IMAG[15:0]}.
        // ====================================================================
        total_tests = total_tests + 1;

        $display("");
        $display("---------------------------------------------------------------------");
        $display("TEST 5 : LOAD FFT INPUT VECTOR");
        $display("---------------------------------------------------------------------");

        input_fd = $fopen("mixed_1024_input.txt", "r");
        input_count = 0;

        if (input_fd == 0) begin
            $display("[FAIL] Could not open mixed_1024_input.txt");
        end
        else begin
            while (input_count < FFT_SIZE) begin
                scan_status = $fscanf(input_fd, "%h %h\n",
                                       input_real, input_imag);
                if (scan_status != 2)
                    break;

                fft_input[input_count] = {input_real[15:0], input_imag[15:0]};
                input_count = input_count + 1;
            end
            $fclose(input_fd);
        end

        $display("[INFO] Input samples loaded from file = %0d",
                 input_count);
        if (input_count == FFT_SIZE) begin
            test5_ok = 1'b1;
            passed_tests = passed_tests + 1;
            $display("[PASS] 1024 FFT input samples loaded");
        end
        else begin
            failed_tests = failed_tests + 1;
            $display("[FAIL] Expected 1024 FFT input samples, got %0d",
                     input_count);
        end

        total_tests = total_tests + 1;

        $display("");
        $display("---------------------------------------------------------------------");
        $display("TEST 6 : FFT MEMORY WRITE - 1024 WORDS");
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
            test6_ok = 1'b1;
            passed_tests = passed_tests + 1;
            $display("[PASS] All 1024 FFT memory writes completed successfully");
        end
        else begin
            failed_tests = failed_tests + 1;
            $display("[FAIL] FFT memory write failures = %0d",
                     fft_memory_write_failures);
        end

        // ====================================================================
        // TEST 7: FFT memory readback
        // ====================================================================
        total_tests = total_tests + 1;

        $display("");
        $display("---------------------------------------------------------------------");
        $display("TEST 7 : FFT MEMORY READBACK");
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
            test7_ok = 1'b1;
            passed_tests = passed_tests + 1;
            $display("[PASS] All 1024 FFT memory words read back correctly");
        end
        else begin
            failed_tests = failed_tests + 1;
            $display("[FAIL] FFT memory readback failures = %0d",
                     fft_memory_read_failures);
        end

        // ====================================================================
        // TEST 8: START FFT AND WAIT FOR COMPLETION
        // ====================================================================
        total_tests = total_tests + 1;

        $display("");
        $display("---------------------------------------------------------------------");
        $display("TEST 8 : FFT START AND COMPLETION");
        $display("---------------------------------------------------------------------");

        fft_start_ok = 1'b0;
        fft_done_ok  = 1'b0;
        fft_busy_seen = 1'b0;

        // Start FFT through the AXI interconnect.
        axi_write(
            32'h4000_5000,
            32'h0000_0001,
            4'b1111,
            8'h20,
            success
        );

        if (success) begin
            fft_start_ok = 1'b1;
            $display("[PASS] FFT START write accepted");
            $display("       CTRL @ 0x4000_5000 = 0x00000001");
        end
        else begin
            $display("[FAIL] FFT START write");
        end

        // Poll FFT status until DONE is asserted.
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
                fft_busy_seen = 1'b1;

            if (rd_data[0]) begin
                fft_done_ok = 1'b1;
                $display("[FFT STATUS] DONE detected after %0d polls | STATUS=0x%08h",
                         poll + 1, rd_data);
                break;
            end

            if ((poll < 5) || ((poll + 1) % 100 == 0))
                $display("[FFT STATUS] poll=%0d STATUS=0x%08h BUSY=%0b DONE=%0b",
                         poll + 1, rd_data, rd_data[1], rd_data[0]);
        end

        if (fft_start_ok && fft_done_ok) begin
            test8_ok = 1'b1;
            passed_tests = passed_tests + 1;
            $display("[PASS] FFT start and completion verified");
            $display("       BUSY was observed = %0b", fft_busy_seen);
        end
        else begin
            failed_tests = failed_tests + 1;
            if (!fft_start_ok)
                $display("[FAIL] FFT start transaction");
            if (!fft_done_ok) begin
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
        // TEST 9: LOAD FFT REFERENCE AND CHECK ALL 1024 OUTPUT BINS
        // ====================================================================
        total_tests = total_tests + 1;

        $display("");
        $display("---------------------------------------------------------------------");
        $display("TEST 9 : FFT REFERENCE LOAD AND RESULT CHECK");
        $display("---------------------------------------------------------------------");

        // Reference file format: <INDEX> <REAL_HEX> <IMAG_HEX>.
        // The file stores 16-bit FFT real/imaginary values.  The temporary
        // variables are 32 bits so $fscanf does not truncate hexadecimal text.
        // Only bits [15:0] are packed into the 32-bit FFT word.
        ref_fd = $fopen("cmodel_fft_out_mixed_1024.txt", "r");
        expected_count = 0;

        if (ref_fd == 0) begin
            $display("[FAIL] Could not open cmodel_fft_out_mixed_1024.txt");
        end
        else begin
            while (expected_count < FFT_SIZE) begin
                scan_status = $fscanf(ref_fd, "%d %h %h\n",
                                       ref_index, ref_real, ref_imag);
                if (scan_status != 3)
                    break;

                fft_expected[expected_count] =
                    {ref_real[15:0], ref_imag[15:0]};
                expected_count = expected_count + 1;
            end
            $fclose(ref_fd);

            $display("[INFO] Reference FFT words loaded = %0d",
                     expected_count);
        end

        if (expected_count != FFT_SIZE) begin
            $display("[FAIL] Expected 1024 reference bins, got %0d",
                     expected_count);
        end
        else begin
            $display("[PASS] Reference contains all 1024 expected bins");
        end

        fft_result_failures = 0;

        if (expected_count == FFT_SIZE) begin
            for (i = 0; i < FFT_SIZE; i = i + 1) begin
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
            fft_result_failures = FFT_SIZE;
        end

        if (expected_count == FFT_SIZE && fft_result_failures == 0) begin
            test9_ok = 1'b1;
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
        // TEST 10: ADC AXI-LITE INTEGRATION THROUGH M04
        //
        // This test verifies only the ADC connection added to the existing
        // working UART + FFT + FIR SoC structure.  The ADC standalone RTL was
        // already verified separately; here we verify the memory-mapped path:
        //
        //   TB AXI master -> AXI interconnect M04 -> ADC AXI4-Lite
        //
        // Checks performed:
        //   1. ADC control/status reset state
        //   2. ADC IRQ-enable register through M04
        //   3. ADC software START through M04
        //   4. External sample_valid/sample_in capture
        //   5. DONE status and SAMPLE_DATA readback
        //   6. FIFO_DATA readback and FIFO-empty status
        //   7. Sticky sample IRQ and W1C clearing
        // ====================================================================
        total_tests = total_tests + 1;

        $display("");
        $display("======================================================================");
        $display("TEST 10 : ADC AXI-LITE INTEGRATION THROUGH M04");
        $display("======================================================================");

        adc_failures = 0;
        adc_done_ok = 1'b0;
        adc_sample_ok = 1'b0;
        adc_fifo_ok = 1'b0;
        adc_irq_ok = 1'b0;

        // ------------------------------------------------------------
        // 10A. Read ADC control/status after reset.
        // ------------------------------------------------------------
        axi_read(
            32'h4000_3000,
            8'h40,
            rd_data,
            success
        );

        if (success && rd_data === 32'h0000_0000) begin
            $display("[PASS] ADC CONTROL RESET: 0x%08h", rd_data);
        end
        else begin
            adc_failures = adc_failures + 1;
            $display("[FAIL] ADC CONTROL RESET: expected=0x00000000 got=0x%08h", rd_data);
        end

        axi_read(
            32'h4000_3004,
            8'h41,
            rd_data,
            success
        );

        if (success && rd_data[0] === 1'b0 && rd_data[2] === 1'b1) begin
            $display("[PASS] ADC STATUS RESET: 0x%08h | BUSY=0 FIFO_EMPTY=1", rd_data);
        end
        else begin
            adc_failures = adc_failures + 1;
            $display("[FAIL] ADC STATUS RESET: expected BUSY=0/FIFO_EMPTY=1 got=0x%08h", rd_data);
        end

        // ------------------------------------------------------------
        // 10B. Enable sample-completion interrupt.
        // ------------------------------------------------------------
        axi_write(
            32'h4000_3010,
            32'h0000_0001,
            4'hF,
            8'h42,
            success
        );

        if (success) begin
            axi_read(
                32'h4000_3010,
                8'h43,
                rd_data,
                success
            );
            if (success && rd_data === 32'h0000_0001) begin
                $display("[PASS] ADC IRQ ENABLE READBACK: 0x%08h", rd_data);
            end
            else begin
                adc_failures = adc_failures + 1;
                $display("[FAIL] ADC IRQ ENABLE READBACK: expected=0x00000001 got=0x%08h", rd_data);
            end
        end
        else begin
            adc_failures = adc_failures + 1;
            $display("[FAIL] ADC IRQ ENABLE WRITE");
        end

        // ------------------------------------------------------------
        // 10C. Enable ADC and issue a software START.
        // ------------------------------------------------------------
        axi_write(
            32'h4000_3000,
            32'h0000_0001,
            4'hF,
            8'h44,
            success
        );

        if (!success) begin
            adc_failures = adc_failures + 1;
            $display("[FAIL] ADC ENABLE WRITE");
        end

        axi_write(
            32'h4000_3000,
            32'h0000_0003,
            4'hF,
            8'h45,
            success
        );

        if (!success) begin
            adc_failures = adc_failures + 1;
            $display("[FAIL] ADC START WRITE");
        end
        else begin
            $display("[PASS] ADC ENABLE + START accepted through M04");
        end

        // Verify that START reached the ADC and the acquisition is
        // waiting for the external sample.
        axi_read(
            32'h4000_3004,
            8'h45,
            rd_data,
            success
        );

        if (success && rd_data[0] === 1'b1) begin
            $display("[PASS] ADC BUSY asserted after START: STATUS=0x%08h", rd_data);
        end
        else begin
            adc_failures = adc_failures + 1;
            $display("[FAIL] ADC BUSY not asserted after START: STATUS=0x%08h", rd_data);
        end

        // ------------------------------------------------------------
        // 10D. Present one external ADC sample.
        // The ADC acquisition block waits for sample_valid while busy.
        // ------------------------------------------------------------
        @(negedge clk);
        adc_sample_in    = 12'hABC;
        adc_sample_valid = 1'b1;

        @(negedge clk);
        adc_sample_valid = 1'b0;

        // Poll DONE.  The sample capture itself is handled by the supplied
        // ADC RTL; this TB only supplies the external sample interface.
        for (poll = 0; poll < 100; poll = poll + 1) begin
            axi_read(
                32'h4000_3004,
                8'h46,
                rd_data,
                success
            );

            if (!success) begin
                $display("[FAIL] ADC STATUS read transaction failed");
                adc_failures = adc_failures + 1;
                break;
            end

            if (rd_data[1]) begin
                adc_done_ok = 1'b1;
                $display("[PASS] ADC DONE detected after %0d polls | STATUS=0x%08h",
                         poll + 1, rd_data);
                break;
            end
        end

        if (!adc_done_ok) begin
            adc_failures = adc_failures + 1;
            $display("[FAIL] ADC DONE timeout; last STATUS=0x%08h", rd_data);
        end

        // ------------------------------------------------------------
        // 10E. Verify captured sample through SAMPLE_DATA.
        // ------------------------------------------------------------
        axi_read(
            32'h4000_3008,
            8'h47,
            rd_data,
            success
        );

        if (success && rd_data[11:0] === 12'hABC) begin
            adc_sample_ok = 1'b1;
            $display("[PASS] ADC SAMPLE_DATA READBACK: 0x%03h", rd_data[11:0]);
        end
        else begin
            adc_failures = adc_failures + 1;
            $display("[FAIL] ADC SAMPLE_DATA: expected=0xABC got=0x%08h", rd_data);
        end

        // ------------------------------------------------------------
        // 10F. Verify FIFO_DATA and FIFO empty transition.
        // ------------------------------------------------------------
        axi_read(
            32'h4000_300C,
            8'h48,
            rd_data,
            success
        );

        if (success && rd_data[11:0] === 12'hABC) begin
            adc_fifo_ok = 1'b1;
            $display("[PASS] ADC FIFO_DATA READBACK: 0x%03h", rd_data[11:0]);
        end
        else begin
            adc_failures = adc_failures + 1;
            $display("[FAIL] ADC FIFO_DATA: expected=0xABC got=0x%08h", rd_data);
        end

        axi_read(
            32'h4000_3004,
            8'h49,
            rd_data,
            success
        );

        if (!(success && rd_data[2] === 1'b1)) begin
            adc_failures = adc_failures + 1;
            $display("[FAIL] ADC FIFO EMPTY after FIFO_DATA read: STATUS=0x%08h", rd_data);
        end
        else begin
            $display("[PASS] ADC FIFO EMPTY after FIFO_DATA read");
        end

        // ------------------------------------------------------------
        // 10G. Verify sticky sample IRQ and clear DONE using W1C.
        // ------------------------------------------------------------
        if (adc_irq_sample === 1'b1) begin
            adc_irq_ok = 1'b1;
            $display("[PASS] ADC SAMPLE IRQ asserted");
        end
        else begin
            adc_failures = adc_failures + 1;
            $display("[FAIL] ADC SAMPLE IRQ not asserted");
        end

        axi_write(
            32'h4000_3004,
            32'h0000_0002,
            4'hF,
            8'h4A,
            success
        );

        if (!success) begin
            adc_failures = adc_failures + 1;
            $display("[FAIL] ADC DONE W1C WRITE");
        end

        axi_read(
            32'h4000_3004,
            8'h4B,
            rd_data,
            success
        );

        if (success && rd_data[1] === 1'b0 && adc_irq_sample === 1'b0) begin
            $display("[PASS] ADC DONE W1C + IRQ CLEAR");
        end
        else begin
            adc_failures = adc_failures + 1;
            $display("[FAIL] ADC DONE W1C/IRQ CLEAR: STATUS=0x%08h IRQ=%0b",
                     rd_data, adc_irq_sample);
        end

        // Leave ADC disabled after the integration test.
        axi_write(
            32'h4000_3000,
            32'h0000_0000,
            4'hF,
            8'h4C,
            success
        );
        axi_write(
            32'h4000_3010,
            32'h0000_0000,
            4'hF,
            8'h4D,
            success
        );

        if (adc_failures == 0) begin
            test10_ok = 1'b1;
            passed_tests = passed_tests + 1;
            $display("");
            $display("[PASS] ADC AXI-LITE INTEGRATION: M04 -> ADC CONTROL/DATA/FIFO/IRQ VERIFIED");
        end
        else begin
            failed_tests = failed_tests + 1;
            $display("");
            $display("[FAIL] ADC AXI-LITE INTEGRATION: %0d failures", adc_failures);
        end

        // ====================================================================
        // TEST 11: GPIO AXI4-LITE THROUGH M05
        // Register map offsets: DATA_I=0x00, DATA_O=0x04, DIR=0x08,
        // SET_O=0x20, CLR_O=0x24, TGL_O=0x28.
        // ====================================================================
        total_tests = total_tests + 1;
        gpio_failures = 0;
        $display("");
        $display("---------------------------------------------------------------------");
        $display("TEST 11 : GPIO AXI-LITE REGISTER AND OUTPUT TEST THROUGH M05");
        $display("---------------------------------------------------------------------");

        axi_write(32'h4000_2008, 32'h0000_000F, 4'hF, 8'h51, success);
        if (!success) gpio_failures = gpio_failures + 1;
        axi_write(32'h4000_2004, 32'h0000_000A, 4'hF, 8'h52, success);
        if (!success) gpio_failures = gpio_failures + 1;
        axi_read(32'h4000_2008, 8'h53, rd_data, success);
        if (!success || rd_data !== 32'h0000_000F) begin
            $display("[FAIL] GPIO DIR readback expected 0000000F got %08h", rd_data);
            gpio_failures = gpio_failures + 1;
        end
        axi_read(32'h4000_2004, 8'h54, rd_data, success);
        if (!success || rd_data !== 32'h0000_000A) begin
            $display("[FAIL] GPIO DATA_O expected 0000000A got %08h", rd_data);
            gpio_failures = gpio_failures + 1;
        end
        axi_write(32'h4000_2020, 32'h0000_0005, 4'hF, 8'h55, success);
        if (!success) gpio_failures = gpio_failures + 1;
        axi_read(32'h4000_2004, 8'h56, rd_data, success);
        if (!success || rd_data !== 32'h0000_000F) begin
            $display("[FAIL] GPIO SET_O expected 0000000F got %08h", rd_data);
            gpio_failures = gpio_failures + 1;
        end
        axi_write(32'h4000_2024, 32'h0000_0003, 4'hF, 8'h57, success);
        if (!success) gpio_failures = gpio_failures + 1;
        axi_read(32'h4000_2004, 8'h58, rd_data, success);
        if (!success || rd_data !== 32'h0000_000C) begin
            $display("[FAIL] GPIO CLR_O expected 0000000C got %08h", rd_data);
            gpio_failures = gpio_failures + 1;
        end
        axi_write(32'h4000_2028, 32'h0000_000F, 4'hF, 8'h59, success);
        if (!success) gpio_failures = gpio_failures + 1;
        axi_read(32'h4000_2004, 8'h5A, rd_data, success);
        if (!success || rd_data !== 32'h0000_0003) begin
            $display("[FAIL] GPIO TGL_O expected 00000003 got %08h", rd_data);
            gpio_failures = gpio_failures + 1;
        end
        repeat (2) @(posedge clk);
        if (gpio_io[3:0] !== 4'h3) begin
            $display("[FAIL] GPIO physical pins expected 3 got %h", gpio_io[3:0]);
            gpio_failures = gpio_failures + 1;
        end
        if (gpio_failures == 0) begin
            test11_ok = 1'b1;
            passed_tests = passed_tests + 1;
            $display("[PASS] GPIO DIR/DATA_O/SET/CLR/TGL and pin outputs verified");
        end else begin
            failed_tests = failed_tests + 1;
            $display("[FAIL] GPIO integration: %0d failure(s)", gpio_failures);
        end

        // ====================================================================
        // TEST 12: TIMER AXI4-LITE THROUGH M06
        // Timer register map: CTRL=0x00, LOAD=0x04, VAL=0x08,
        // PRE=0x0C, INT_EN=0x10, INT_STS=0x14.
        // ====================================================================
        total_tests = total_tests + 1;
        timer_failures = 0;
        $display("");
        $display("---------------------------------------------------------------------");
        $display("TEST 12 : TIMER AXI-LITE REGISTER AND INTERRUPT TEST THROUGH M06");
        $display("---------------------------------------------------------------------");

        // Stop timer, clear sticky interrupt, configure a short down-count.
        axi_write(32'h4000_1000, 32'h0000_0000, 4'hF, 8'h61, success);
        if (!success) timer_failures = timer_failures + 1;
        axi_write(32'h4000_1014, 32'h0000_0003, 4'hF, 8'h62, success);
        if (!success) timer_failures = timer_failures + 1;
        axi_write(32'h4000_1004, 32'h0000_000A, 4'hF, 8'h63, success);
        if (!success) timer_failures = timer_failures + 1;
        axi_write(32'h4000_1010, 32'h0000_0001, 4'hF, 8'h64, success);
        if (!success) timer_failures = timer_failures + 1;
        axi_read(32'h4000_1004, 8'h65, rd_data, success);
        if (!success || rd_data !== 32'h0000_000A) begin
            $display("[FAIL] TIMER LOAD readback expected 0000000A got %08h", rd_data);
            timer_failures = timer_failures + 1;
        end
        axi_read(32'h4000_1010, 8'h66, rd_data, success);
        if (!success || rd_data !== 32'h0000_0001) begin
            $display("[FAIL] TIMER INT_EN expected 00000001 got %08h", rd_data);
            timer_failures = timer_failures + 1;
        end
        // Enable one-shot down counter; LOAD write already initialized counter.
        axi_write(32'h4000_1000, 32'h0000_0001, 4'hF, 8'h67, success);
        if (!success) timer_failures = timer_failures + 1;
        repeat (24) @(posedge clk);
        axi_read(32'h4000_1014, 8'h68, rd_data, success);
        if (!success || rd_data[0] !== 1'b1 || timer_irq !== 1'b1) begin
            $display("[FAIL] TIMER expiry IRQ/status not asserted: status=%08h irq=%b", rd_data, timer_irq);
            timer_failures = timer_failures + 1;
        end else begin
            $display("[PASS] TIMER expiry status and IRQ asserted: status=%08h", rd_data);
        end
        // Clear the sticky expiry bit (write-one-to-clear).
        axi_write(32'h4000_1014, 32'h0000_0001, 4'hF, 8'h69, success);
        if (!success) timer_failures = timer_failures + 1;
        axi_read(32'h4000_1014, 8'h6A, rd_data, success);
        if (!success || rd_data[0] !== 1'b0) begin
            $display("[FAIL] TIMER interrupt status did not clear: %08h", rd_data);
            timer_failures = timer_failures + 1;
        end
        if (timer_failures == 0) begin
            test12_ok = 1'b1;
            passed_tests = passed_tests + 1;
            $display("[PASS] TIMER LOAD/INT_EN/expiry IRQ/W1C verified");
        end else begin
            failed_tests = failed_tests + 1;
            $display("[FAIL] TIMER integration: %0d failure(s)", timer_failures);
        end

        // ====================================================================
        // FINAL SUMMARY
        // ====================================================================
        $display("");
        $display("======================================================================");
        $display("                     FINAL TEST SUMMARY");
        $display("======================================================================");
        $display("TEST 1  - UART reset/read        : %s", test1_ok ? "PASS" : "FAIL");
        $display("TEST 2  - UART register write    : %s", test2_ok ? "PASS" : "FAIL");
        $display("TEST 3  - UART consecutive read  : %s", test3_ok ? "PASS" : "FAIL");
        $display("TEST 4  - FIR AXI-Lite control   : %s", test4_ok ? "PASS" : "FAIL");
        $display("TEST 5  - FFT input file load    : %s", test5_ok ? "PASS" : "FAIL");
        $display("TEST 6  - FFT memory writes      : %s", test6_ok ? "PASS" : "FAIL");
        $display("TEST 7  - FFT memory readback    : %s", test7_ok ? "PASS" : "FAIL");
        $display("TEST 8  - FFT start/completion   : %s", test8_ok ? "PASS" : "FAIL");
        $display("TEST 9  - FFT result check       : %s", test9_ok ? "PASS" : "FAIL");
        $display("TEST 10 - ADC AXI-Lite integration: %s", test10_ok ? "PASS" : "FAIL");
        $display("TEST 11 - GPIO AXI-Lite integration: %s", test11_ok ? "PASS" : "FAIL");
        $display("TEST 12 - Timer AXI-Lite integration: %s", test12_ok ? "PASS" : "FAIL");
        $display("---------------------------------------------------------------------");
        $display("TOTAL TEST CASES       : %0d", total_tests);
        $display("PASS TESTS             : %0d", passed_tests);
        $display("FAIL TESTS             : %0d", failed_tests);
        $display("======================================================================");

        if (failed_tests == 0 &&
            total_tests == 12 &&
            passed_tests == 12 &&
            test1_ok && test2_ok && test3_ok && test4_ok &&
            test5_ok && test6_ok && test7_ok && test8_ok &&
            test9_ok && test10_ok && test11_ok && test12_ok) begin

            $display("");
            $display("######################################################################");
            $display("#                    INTEGRATION TEST : PASS                         #");
            $display("# UART + AXI INTERCONNECT + FIR + FFT + ADC + GPIO + TIMER          #");
            $display("#                    ALL 12 TEST CASES PASSED                       #");
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
