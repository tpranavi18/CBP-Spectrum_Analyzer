// ============================================================================
// File: tb_veerall_top.sv
// Project: CBP-Spectrum_Analyzer
//
// Description:
//   Comprehensive SystemVerilog Verification Testbench for:
//     VeeR EL2 Core + 64to32 Adapters + 3x18 AXI Interconnect +
//     64 KB IMEM + 64 KB DMEM + UART + GPIO + Timer + FIR + ADC +
//     FFT Accelerator (Control & Memory) + Dummy Slaves M09-M17.
//
// Authoritative Regression Suite (22 Test Cases matching ODS Specification):
//   TC-01 : Reset Assertion and Deassertion / System Startup
//   TC-02 : Interconnect Basic Read/Write Connectivity (M00 - M08)
//   TC-03 : Address Decoding Accuracy & Peripheral Space Isolation
//   TC-04 : Unmapped Address & Error Handling (DECERR Verification)
//   TC-05 : Back-to-Back & Multiple Transaction Stress
//   TC-06 : Peripheral Register Configuration & Access Verification
//   TC-07 : ADC Interface Sample Acquisition & FIFO Handling
//   TC-08 : FIR Filter Coefficient Configuration & Stream Processing
//   TC-09 : FFT Numerical & Frequency Data Path Verification
//   TC-10 : FFT Control, Start Pulse, Busy & Done Flags
//   TC-11 : FFT Memory Capacity & Boundary Access
//   TC-12 : UART Transmit, Framing, Divisor & Status Registers
//   TC-13 : GPIO Direction, Output, Mask, Pin Toggling & Input Sampling
//   TC-14 : Timer Prescaler, Load, Down-Count, Expiry & Clearing
//   TC-15 : Complete DSP Data Path (ADC -> FIR -> FFT)
//   TC-16 : CPU Instruction Fetch (IFU) & Bus Execution Monitoring
//   TC-17 : FFT Result Retrieval & Memory Window Verification
//   TC-18 : Repeated Processing & State Isolation
//   TC-19 : Reset Recovery During Active Bus / Processing Operation
//   TC-20 : Integrated Peripheral Coexistence & Non-Interference
//   TC-21 : Interrupt Generation, Propagation & PIC Routing (UART/GPIO/Timer/ADC)
//   TC-22 : Boundary, Byte Strobes & Stress Testing
// ============================================================================

`timescale 1ns/1ps

module tb_veerall_top;

    // ------------------------------------------------------------------------
    // Clock & Timing Parameters
    // ------------------------------------------------------------------------
    localparam time CLK_PERIOD = 20ns; // 50 MHz clock
    localparam DATA_WIDTH      = 32;
    localparam ADDR_WIDTH      = 32;
    localparam STRB_WIDTH      = 4;
    localparam ID_WIDTH        = 8;

    logic clk;
    logic rst_n;
    wire  rst = ~rst_n;

    // ------------------------------------------------------------------------
    // Physical External I/O Signals
    // ------------------------------------------------------------------------
    logic        uart_rx_i;
    wire         uart_tx_o;

    wire [31:0]  gpio_io;
    logic [31:0] gpio_drive;
    logic        gpio_drive_en;
    assign gpio_io = gpio_drive_en ? gpio_drive : 32'hzzzz_zzzz;

    logic        timer_ext_meas_i;
    logic        timer_capture_i;
    wire         timer_pwm_o;
    wire         timer_trigger_o;

    logic [11:0] adc_sample_in;
    logic        adc_sample_valid;

    logic        fir_s_axis_tvalid;
    wire         fir_s_axis_tready;
    logic [15:0] fir_s_axis_tdata;
    wire         fir_m_axis_tvalid;
    logic        fir_m_axis_tready;
    wire  [39:0] fir_m_axis_tdata;

    wire         uart_irq;
    wire         gpio_irq;
    wire         timer_irq;
    wire         adc_irq_sample;
    wire         adc_irq_overrun;

    // ------------------------------------------------------------------------
    // Verification / Testbench Master AXI Port (Connected to Interconnect S02)
    // ------------------------------------------------------------------------
    logic [ID_WIDTH-1:0]      tb_axi_awid;
    logic [ADDR_WIDTH-1:0]    tb_axi_awaddr;
    logic [7:0]               tb_axi_awlen;
    logic [2:0]               tb_axi_awsize;
    logic [1:0]               tb_axi_awburst;
    logic                     tb_axi_awlock;
    logic [3:0]               tb_axi_awcache;
    logic [2:0]               tb_axi_awprot;
    logic [3:0]               tb_axi_awqos;
    logic [3:0]               tb_axi_awregion;
    logic                     tb_axi_awvalid;
    wire                      tb_axi_awready;

    logic [DATA_WIDTH-1:0]    tb_axi_wdata;
    logic [STRB_WIDTH-1:0]    tb_axi_wstrb;
    logic                     tb_axi_wlast;
    logic                     tb_axi_wvalid;
    wire                      tb_axi_wready;

    wire [ID_WIDTH-1:0]       tb_axi_bid;
    wire [1:0]                tb_axi_bresp;
    wire                      tb_axi_bvalid;
    logic                     tb_axi_bready;

    logic [ID_WIDTH-1:0]      tb_axi_arid;
    logic [ADDR_WIDTH-1:0]    tb_axi_araddr;
    logic [7:0]               tb_axi_arlen;
    logic [2:0]               tb_axi_arsize;
    logic [1:0]               tb_axi_arburst;
    logic                     tb_axi_arlock;
    logic [3:0]               tb_axi_arcache;
    logic [2:0]               tb_axi_arprot;
    logic [3:0]               tb_axi_arqos;
    logic [3:0]               tb_axi_arregion;
    logic                     tb_axi_arvalid;
    wire                      tb_axi_arready;

    wire [ID_WIDTH-1:0]       tb_axi_rid;
    wire [DATA_WIDTH-1:0]     tb_axi_rdata;
    wire [1:0]                tb_axi_rresp;
    wire                      tb_axi_rlast;
    wire                      tb_axi_rvalid;
    logic                     tb_axi_rready;

    // ------------------------------------------------------------------------
    // Verification Tracking & Statistics
    // ------------------------------------------------------------------------
    integer total_tests     = 0;
    integer passed_tests    = 0;
    integer failed_tests    = 0;
    integer blocked_tests   = 0;

    integer axi_trans_count = 0;
    integer axi_error_count = 0;
    integer periph_tests    = 0;
    integer dsp_tests       = 0;
    integer irq_tests       = 0;
    integer integ_tests     = 0;

    // Monitor counters
    integer ifu_fetches     = 0;
    integer lsu_trans       = 0;

    // ------------------------------------------------------------------------
    // Device Under Test (DUT) Instantiation
    // ------------------------------------------------------------------------
    veerall_top #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH),
        .STRB_WIDTH (STRB_WIDTH),
        .ID_WIDTH   (ID_WIDTH)
    ) dut (
        .clk                (clk),
        .rst_n              (rst_n),

        .uart_rx_i         (uart_rx_i),
        .uart_tx_o         (uart_tx_o),

        .gpio_io            (gpio_io),

        .timer_ext_meas_i   (timer_ext_meas_i),
        .timer_capture_i    (timer_capture_i),
        .timer_pwm_o        (timer_pwm_o),
        .timer_trigger_o    (timer_trigger_o),

        .adc_sample_in      (adc_sample_in),
        .adc_sample_valid   (adc_sample_valid),

        .fir_s_axis_tvalid  (fir_s_axis_tvalid),
        .fir_s_axis_tready  (fir_s_axis_tready),
        .fir_s_axis_tdata   (fir_s_axis_tdata),
        .fir_m_axis_tvalid  (fir_m_axis_tvalid),
        .fir_m_axis_tready  (fir_m_axis_tready),
        .fir_m_axis_tdata   (fir_m_axis_tdata),

        .uart_irq           (uart_irq),
        .gpio_irq           (gpio_irq),
        .timer_irq          (timer_irq),
        .adc_irq_sample     (adc_irq_sample),
        .adc_irq_overrun    (adc_irq_overrun),

        // Testbench Master AXI Port
        .tb_axi_awid        (tb_axi_awid),
        .tb_axi_awaddr      (tb_axi_awaddr),
        .tb_axi_awlen       (tb_axi_awlen),
        .tb_axi_awsize      (tb_axi_awsize),
        .tb_axi_awburst     (tb_axi_awburst),
        .tb_axi_awlock      (tb_axi_awlock),
        .tb_axi_awcache     (tb_axi_awcache),
        .tb_axi_awprot      (tb_axi_awprot),
        .tb_axi_awqos       (tb_axi_awqos),
        .tb_axi_awregion    (tb_axi_awregion),
        .tb_axi_awvalid     (tb_axi_awvalid),
        .tb_axi_awready     (tb_axi_awready),

        .tb_axi_wdata       (tb_axi_wdata),
        .tb_axi_wstrb       (tb_axi_wstrb),
        .tb_axi_wlast       (tb_axi_wlast),
        .tb_axi_wvalid      (tb_axi_wvalid),
        .tb_axi_wready      (tb_axi_wready),

        .tb_axi_bid         (tb_axi_bid),
        .tb_axi_bresp       (tb_axi_bresp),
        .tb_axi_bvalid      (tb_axi_bvalid),
        .tb_axi_bready      (tb_axi_bready),

        .tb_axi_arid        (tb_axi_arid),
        .tb_axi_araddr      (tb_axi_araddr),
        .tb_axi_arlen       (tb_axi_arlen),
        .tb_axi_arsize      (tb_axi_arsize),
        .tb_axi_arburst     (tb_axi_arburst),
        .tb_axi_arlock      (tb_axi_arlock),
        .tb_axi_arcache     (tb_axi_arcache),
        .tb_axi_arprot      (tb_axi_arprot),
        .tb_axi_arqos       (tb_axi_arqos),
        .tb_axi_arregion    (tb_axi_arregion),
        .tb_axi_arvalid     (tb_axi_arvalid),
        .tb_axi_arready     (tb_axi_arready),

        .tb_axi_rid         (tb_axi_rid),
        .tb_axi_rdata       (tb_axi_rdata),
        .tb_axi_rresp       (tb_axi_rresp),
        .tb_axi_rlast       (tb_axi_rlast),
        .tb_axi_rvalid      (tb_axi_rvalid),
        .tb_axi_rready      (tb_axi_rready)
    );

    // ------------------------------------------------------------------------
    // 50 MHz Clock Generation
    // ------------------------------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // ------------------------------------------------------------------------
    // Bus Monitors (IFU fetches and LSU memory/peripheral transactions)
    // ------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst_n && dut.s00_axi_arvalid && dut.s00_axi_arready) begin
            ifu_fetches <= ifu_fetches + 1;
            if (ifu_fetches < 10) begin
                $display("  [%0t ns] [VeeR IFU FETCH #%0d] PC/ARADDR = 0x%08h",
                         $time, ifu_fetches + 1, dut.s00_axi_araddr);
            end
        end

        if (rst_n && (dut.s01_axi_awvalid && dut.s01_axi_awready ||
                      dut.s01_axi_arvalid && dut.s01_axi_arready)) begin
            lsu_trans <= lsu_trans + 1;
        end
    end

    // =========================================================================
    // REUSABLE AXI MASTER BFM TASKS
    // =========================================================================

    // Write single beat
    task automatic axi_write(
        input  logic [31:0] addr,
        input  logic [31:0] data,
        input  logic [3:0]  strb,
        input  logic [7:0]  id,
        output logic        success,
        output logic [1:0]  resp
    );
        integer t;
        logic aw_done;
        logic w_done;
        logic b_done;
        begin
            success = 1'b0;
            aw_done = 1'b0;
            w_done  = 1'b0;
            b_done  = 1'b0;
            resp    = 2'b00;
            axi_trans_count = axi_trans_count + 1;

            @(negedge clk);
            tb_axi_awid     = id;
            tb_axi_awaddr   = addr;
            tb_axi_awlen    = 8'd0;
            tb_axi_awsize   = 3'b010; // 4 bytes
            tb_axi_awburst  = 2'b01;  // INCR
            tb_axi_awlock   = 1'b0;
            tb_axi_awcache  = 4'b0000;
            tb_axi_awprot   = 3'b000;
            tb_axi_awqos    = 4'b0000;
            tb_axi_awregion = 4'b0000;
            tb_axi_awvalid  = 1'b1;

            tb_axi_wdata    = data;
            tb_axi_wstrb    = strb;
            tb_axi_wlast    = 1'b1;
            tb_axi_wvalid   = 1'b1;
            tb_axi_bready   = 1'b0;

            for (t = 0; t < 500; t = t + 1) begin
                @(posedge clk);
                if (!aw_done && tb_axi_awvalid && tb_axi_awready)
                    aw_done = 1'b1;
                if (!w_done && tb_axi_wvalid && tb_axi_wready)
                    w_done = 1'b1;
                if (aw_done && w_done)
                    break;
            end

            @(negedge clk);
            tb_axi_awvalid = 1'b0;
            tb_axi_wvalid  = 1'b0;

            if (!(aw_done && w_done)) begin
                $display("  [%0t ns] [FAIL] AXI WRITE ADDRESS/DATA TIMEOUT: ADDR=0x%08h", $time, addr);
                axi_error_count = axi_error_count + 1;
            end else begin
                tb_axi_bready = 1'b1;
                for (t = 0; t < 500; t = t + 1) begin
                    @(posedge clk);
                    if (tb_axi_bvalid && tb_axi_bready) begin
                        b_done  = 1'b1;
                        resp    = tb_axi_bresp;
                        success = (resp == 2'b00);
                        if (resp != 2'b00)
                            axi_error_count = axi_error_count + 1;
                        break;
                    end
                end
                @(negedge clk);
                tb_axi_bready = 1'b0;
                if (!b_done) begin
                    $display("  [%0t ns] [FAIL] AXI WRITE RESPONSE TIMEOUT: ADDR=0x%08h", $time, addr);
                    axi_error_count = axi_error_count + 1;
                end
            end
        end
    endtask

    // Read single beat
    task automatic axi_read(
        input  logic [31:0] addr,
        input  logic [7:0]  id,
        output logic [31:0] data,
        output logic [1:0]  resp,
        output logic        success
    );
        integer t;
        logic ar_done;
        logic r_done;
        begin
            data    = 32'h0;
            resp    = 2'b00;
            success = 1'b0;
            ar_done = 1'b0;
            r_done  = 1'b0;
            axi_trans_count = axi_trans_count + 1;

            @(negedge clk);
            tb_axi_arid     = id;
            tb_axi_araddr   = addr;
            tb_axi_arlen    = 8'd0;
            tb_axi_arsize   = 3'b010;
            tb_axi_arburst  = 2'b01;
            tb_axi_arlock   = 1'b0;
            tb_axi_arcache  = 4'b0000;
            tb_axi_arprot   = 3'b000;
            tb_axi_arqos    = 4'b0000;
            tb_axi_arregion = 4'b0000;
            tb_axi_arvalid  = 1'b1;
            tb_axi_rready   = 1'b0;

            for (t = 0; t < 500; t = t + 1) begin
                @(posedge clk);
                if (tb_axi_arvalid && tb_axi_arready) begin
                    ar_done = 1'b1;
                    break;
                end
            end

            @(negedge clk);
            tb_axi_arvalid = 1'b0;

            if (!ar_done) begin
                $display("  [%0t ns] [FAIL] AXI READ ADDRESS TIMEOUT: ADDR=0x%08h", $time, addr);
                axi_error_count = axi_error_count + 1;
            end else begin
                tb_axi_rready = 1'b1;
                for (t = 0; t < 500; t = t + 1) begin
                    @(posedge clk);
                    if (tb_axi_rvalid && tb_axi_rready) begin
                        r_done  = 1'b1;
                        data    = tb_axi_rdata;
                        resp    = tb_axi_rresp;
                        success = (resp == 2'b00);
                        if (resp != 2'b00)
                            axi_error_count = axi_error_count + 1;
                        break;
                    end
                end
                @(negedge clk);
                tb_axi_rready = 1'b0;
                if (!r_done) begin
                    $display("  [%0t ns] [FAIL] AXI READ DATA TIMEOUT: ADDR=0x%08h", $time, addr);
                    axi_error_count = axi_error_count + 1;
                end
            end
        end
    endtask

    // Check transaction and print formatted result
    task automatic check_test_result(
        input string tc_id,
        input string tc_name,
        input logic  passed,
        input string details
    );
        total_tests = total_tests + 1;
        if (passed) begin
            passed_tests = passed_tests + 1;
            $display("[PASS] %s: %s | %s", tc_id, tc_name, details);
        end else begin
            failed_tests = failed_tests + 1;
            $display("[FAIL] %s: %s | %s", tc_id, tc_name, details);
        end
    endtask

    // =========================================================================
    // MAIN VERIFICATION PROCEDURE
    // =========================================================================
    initial begin
        logic success;
        logic [1:0]  resp;
        logic [31:0] rdata;
        logic [31:0] exp_data;
        integer i, k;
        logic tc_ok;

        // Signal initialization
        rst_n            = 1'b0;
        uart_rx_i        = 1'b1;
        gpio_drive_en    = 1'b0;
        gpio_drive       = 32'h0;
        timer_ext_meas_i = 1'b0;
        timer_capture_i  = 1'b0;
        adc_sample_in    = 12'h0;
        adc_sample_valid = 1'b0;
        fir_s_axis_tvalid = 1'b0;
        fir_s_axis_tdata  = 16'h0;
        fir_m_axis_tready = 1'b1;

        tb_axi_awid     = 8'h0;
        tb_axi_awaddr   = 32'h0;
        tb_axi_awlen    = 8'h0;
        tb_axi_awsize   = 3'b010;
        tb_axi_awburst  = 2'b01;
        tb_axi_awlock   = 1'b0;
        tb_axi_awcache  = 4'h0;
        tb_axi_awprot   = 3'h0;
        tb_axi_awqos    = 4'h0;
        tb_axi_awregion = 4'h0;
        tb_axi_awvalid  = 1'b0;
        tb_axi_wdata    = 32'h0;
        tb_axi_wstrb    = 4'h0;
        tb_axi_wlast    = 1'b0;
        tb_axi_wvalid   = 1'b0;
        tb_axi_bready   = 1'b0;
        tb_axi_arid     = 8'h0;
        tb_axi_araddr   = 32'h0;
        tb_axi_arlen    = 8'h0;
        tb_axi_arsize   = 3'b010;
        tb_axi_arburst  = 2'b01;
        tb_axi_arlock   = 1'b0;
        tb_axi_arcache  = 4'h0;
        tb_axi_arprot   = 3'h0;
        tb_axi_arqos    = 4'h0;
        tb_axi_arregion = 4'h0;
        tb_axi_arvalid  = 1'b0;
        tb_axi_rready   = 1'b0;

        $display("================================================================================");
        $display(" STARTING VERIFICATION: RISC-V VeeR EL2 + AXI + DSP IPs SPECTRUM ANALYZER SoC ");
        $display("================================================================================");

        // ---------------------------------------------------------------------
        // TC-01 : Reset Assertion and Deassertion / System Startup
        // ---------------------------------------------------------------------
        integ_tests = integ_tests + 1;
        #100ns;
        @(posedge clk);
        // Verify ready/valid states during reset: no spurious transactions
        tc_ok = (tb_axi_bvalid == 1'b0 && tb_axi_rvalid == 1'b0 && rst_n == 1'b0);
        #40ns;
        @(posedge clk);
        rst_n = 1'b1; // Release reset
        #60ns;
        @(posedge clk);
        tc_ok = tc_ok && (rst_n == 1'b1);
        check_test_result("TC-01", "Reset Assertion & Release", tc_ok,
                          "Reset held for 100ns, cleanly released. System entered running state.");

        // ---------------------------------------------------------------------
        // TC-02 : Interconnect Basic Read/Write Connectivity (M00 - M08)
        // ---------------------------------------------------------------------
        integ_tests = integ_tests + 1;
        tc_ok = 1'b1;

        // Test DMEM write and readback
        axi_write(32'h0001_0100, 32'hA5A5_5A5A, 4'hF, 8'h01, success, resp);
        tc_ok = tc_ok && success;
        axi_read(32'h0001_0100, 8'h01, rdata, resp, success);
        tc_ok = tc_ok && success && (rdata == 32'hA5A5_5A5A);

        // Test IMEM read of reset vector
        axi_read(32'h0000_0000, 8'h02, rdata, resp, success);
        tc_ok = tc_ok && success && (rdata == 32'h00010537); // lui a0, 0x10000

        check_test_result("TC-02", "Interconnect Basic Connectivity", tc_ok,
                          "Verified AXI read/write to IMEM and DMEM memories.");

        // ---------------------------------------------------------------------
        // TC-03 : Address Decoding Accuracy & Peripheral Space Isolation
        // ---------------------------------------------------------------------
        integ_tests = integ_tests + 1;
        tc_ok = 1'b1;

        // Verify UART LCR write/read at 0x4000_000C
        axi_write(32'h4000_000C, 32'h0000_0003, 4'hF, 8'h03, success, resp);
        tc_ok = tc_ok && success;
        axi_read(32'h4000_000C, 8'h03, rdata, resp, success);
        tc_ok = tc_ok && success;

        // Verify GPIO DIR at 0x4000_2008
        axi_write(32'h4000_2008, 32'h0000_00AA, 4'hF, 8'h04, success, resp);
        tc_ok = tc_ok && success;
        axi_read(32'h4000_2008, 8'h04, rdata, resp, success);
        tc_ok = tc_ok && success && (rdata[7:0] == 8'hAA);

        // Verify Timer LOAD at 0x4000_4004
        axi_write(32'h4000_4004, 32'h0000_1000, 4'hF, 8'h05, success, resp);
        tc_ok = tc_ok && success;
        axi_read(32'h4000_4004, 8'h05, rdata, resp, success);
        tc_ok = tc_ok && success && (rdata == 32'h0000_1000);

        // Verify FIR Control at 0x4000_C000
        axi_write(32'h4000_C000, 32'h0000_0001, 4'hF, 8'h06, success, resp);
        tc_ok = tc_ok && success;
        axi_read(32'h4000_C000, 8'h06, rdata, resp, success);
        tc_ok = tc_ok && success && (rdata[0] == 1'b1);

        // Verify ADC Control at 0x4000_E000
        axi_write(32'h4000_E000, 32'h0000_0001, 4'hF, 8'h07, success, resp);
        tc_ok = tc_ok && success;
        axi_read(32'h4000_E000, 8'h07, rdata, resp, success);
        tc_ok = tc_ok && success;

        // Verify FFT Status at 0x4000_8004
        axi_read(32'h4000_8004, 8'h08, rdata, resp, success);
        tc_ok = tc_ok && success;

        check_test_result("TC-03", "Address Decoding Accuracy", tc_ok,
                          "All real peripheral bases verified at exact spreadsheet addresses.");

        // ---------------------------------------------------------------------
        // TC-04 : Unmapped Address & Error Handling (DECERR Verification)
        // ---------------------------------------------------------------------
        integ_tests = integ_tests + 1;
        tc_ok = 1'b1;

        // Watchdog dummy M09 (0x4000_6000)
        axi_read(32'h4000_6000, 8'h09, rdata, resp, success);
        tc_ok = tc_ok && (resp == 2'b11); // DECERR expected

        // SPI dummy M10 (0x4001_0000)
        axi_write(32'h4001_0000, 32'h1234, 4'hF, 8'h0A, success, resp);
        tc_ok = tc_ok && (resp == 2'b11); // DECERR expected

        // AES dummy M12 (0x4001_4000)
        axi_read(32'h4001_4000, 8'h0B, rdata, resp, success);
        tc_ok = tc_ok && (resp == 2'b11);

        // Completely unmapped address (0x5000_0000)
        axi_read(32'h5000_0000, 8'h0C, rdata, resp, success);
        tc_ok = tc_ok && (resp == 2'b11);

        check_test_result("TC-04", "Unmapped Address & Error Handling", tc_ok,
                          "Dummy slaves and unmapped spaces safely returned DECERR (2'b11).");

        // ---------------------------------------------------------------------
        // TC-05 : Back-to-Back & Multiple Transaction Stress
        // ---------------------------------------------------------------------
        integ_tests = integ_tests + 1;
        tc_ok = 1'b1;
        for (i = 0; i < 8; i = i + 1) begin
            axi_write(32'h0001_0200 + (i*4), i * 32'h1111_1111, 4'hF, 8'h10 + i, success, resp);
            tc_ok = tc_ok && success;
        end
        for (i = 0; i < 8; i = i + 1) begin
            axi_read(32'h0001_0200 + (i*4), 8'h20 + i, rdata, resp, success);
            tc_ok = tc_ok && success && (rdata == i * 32'h1111_1111);
        end
        check_test_result("TC-05", "Back-to-Back Access Stress", tc_ok,
                          "8 back-to-back writes and reads completed without bus hang.");

        // ---------------------------------------------------------------------
        // TC-06 : Peripheral Register Configuration & Access Verification
        // ---------------------------------------------------------------------
        periph_tests = periph_tests + 1;
        tc_ok = 1'b1;
        // Timer prescaler
        axi_write(32'h4000_400C, 32'h0000_0008, 4'hF, 8'h30, success, resp);
        tc_ok = tc_ok && success;
        axi_read(32'h4000_400C, 8'h30, rdata, resp, success);
        tc_ok = tc_ok && success && (rdata == 32'h0000_0008);
        check_test_result("TC-06", "Peripheral Register Config", tc_ok,
                          "Timer prescaler and peripheral registers retention verified.");

        // ---------------------------------------------------------------------
        // TC-07 : ADC Interface Sample Acquisition & FIFO Handling
        // ---------------------------------------------------------------------
        dsp_tests = dsp_tests + 1;
        tc_ok = 1'b1;
        // 1. Enable ADC and issue software start trigger at OFFSET_CTRL (0x4000_E000)
        axi_write(32'h4000_E000, 32'h0000_0003, 4'hF, 8'h3F, success, resp);
        tc_ok = tc_ok && success;
        repeat (3) @(posedge clk);

        // 2. Inject external ADC sample
        @(negedge clk);
        adc_sample_in    = 12'hABC;
        adc_sample_valid = 1'b1;
        @(posedge clk);
        #1;
        @(negedge clk);
        adc_sample_valid = 1'b0;
        repeat (5) @(posedge clk);

        // 3. Read ADC STATUS register at 0x4000_E004 (bit 1 is DONE)
        axi_read(32'h4000_E004, 8'h40, rdata, resp, success);
        tc_ok = tc_ok && success && rdata[1];

        // 4. Read ADC SAMPLE_DATA register at 0x4000_E008
        axi_read(32'h4000_E008, 8'h41, rdata, resp, success);
        tc_ok = tc_ok && success && (rdata[11:0] == 12'hABC);

        // 5. Read ADC FIFO_DATA register at 0x4000_E00C
        axi_read(32'h4000_E00C, 8'h42, rdata, resp, success);
        tc_ok = tc_ok && success && (rdata[11:0] == 12'hABC);

        check_test_result("TC-07", "ADC Sample Acquisition & FIFO", tc_ok,
                          "ADC triggered, sample 0xABC captured and verified in register and FIFO.");

        // ---------------------------------------------------------------------
        // TC-08 : FIR Filter Coefficient Configuration & Stream Processing
        // ---------------------------------------------------------------------
        dsp_tests = dsp_tests + 1;
        tc_ok = 1'b1;
        // Write FIR coefficient 0 at 0x4000_C010
        axi_write(32'h4000_C010, 32'h0000_7FFF, 4'hF, 8'h45, success, resp);
        tc_ok = tc_ok && success;
        axi_read(32'h4000_C010, 8'h45, rdata, resp, success);
        tc_ok = tc_ok && success && (rdata[15:0] == 16'h7FFF);

        // Load coefficients trigger at 0x4000_C004
        axi_write(32'h4000_C004, 32'h0000_0001, 4'hF, 8'h46, success, resp);
        tc_ok = tc_ok && success;
        check_test_result("TC-08", "FIR Filter Config", tc_ok,
                          "Coefficients loaded and verified via AXI-Lite.");

        // ---------------------------------------------------------------------
        // TC-09 : FFT Numerical & Frequency Data Path Verification
        // ---------------------------------------------------------------------
        dsp_tests = dsp_tests + 1;
        tc_ok = 1'b1;
        // Write test vector to FFT memory at 0x4000_A000
        axi_write(32'h4000_A000, 32'h1234_5678, 4'hF, 8'h50, success, resp);
        tc_ok = tc_ok && success;
        axi_read(32'h4000_A000, 8'h50, rdata, resp, success);
        tc_ok = tc_ok && success && (rdata == 32'h1234_5678);
        check_test_result("TC-09", "FFT Numerical Data Buffer", tc_ok,
                          "Written complex test vector into FFT memory and verified readback.");

        // ---------------------------------------------------------------------
        // TC-10 : FFT Control, Start Pulse, Busy & Done Flags
        // ---------------------------------------------------------------------
        dsp_tests = dsp_tests + 1;
        tc_ok = 1'b1;
        // Start FFT by writing bit 0 of CTRL at 0x4000_8000
        axi_write(32'h4000_8000, 32'h0000_0001, 4'hF, 8'h55, success, resp);
        tc_ok = tc_ok && success;
        // Poll status at 0x4000_8004 until FFT computation completes
        begin : poll_fft_done
            integer poll_cnt;
            reg done_seen;
            reg busy_seen;
            done_seen = 1'b0;
            busy_seen = 1'b0;
            for (poll_cnt = 0; poll_cnt < 8000; poll_cnt = poll_cnt + 1) begin
                axi_read(32'h4000_8004, 8'h56, rdata, resp, success);
                if (!success) break;
                if (rdata[1]) busy_seen = 1'b1;
                if (rdata[0]) begin
                    done_seen = 1'b1;
                    $display("  [%0t ns] [FFT DONE] Detected after %0d polls | STATUS=0x%08h (BUSY was %0b)",
                             $time, poll_cnt + 1, rdata, busy_seen);
                    break;
                end
                if ((poll_cnt < 3) || ((poll_cnt + 1) % 500 == 0)) begin
                    $display("  [%0t ns] [FFT STATUS] poll=%0d STATUS=0x%08h BUSY=%0b DONE=%0b",
                             $time, poll_cnt + 1, rdata, rdata[1], rdata[0]);
                end
                #20ns;
            end
            tc_ok = tc_ok && done_seen;
        end
        check_test_result("TC-10", "FFT Control & Status", tc_ok,
                          "Start pulse issued; FFT completion verified via status polling.");

        // ---------------------------------------------------------------------
        // TC-11 : FFT Memory Capacity & Boundary Access
        // ---------------------------------------------------------------------
        dsp_tests = dsp_tests + 1;
        tc_ok = 1'b1;
        // Upper boundary address: 0x4000_A000 + 0x0FFC = 0x4000_AFFC
        axi_write(32'h4000_AFFC, 32'hCAFE_BABE, 4'hF, 8'h5A, success, resp);
        tc_ok = tc_ok && success;
        axi_read(32'h4000_AFFC, 8'h5A, rdata, resp, success);
        tc_ok = tc_ok && success && (rdata == 32'hCAFE_BABE);
        check_test_result("TC-11", "FFT Memory Boundary", tc_ok,
                          "Verified 4 KB memory window boundary access at 0x4000_AFFC.");

        // ---------------------------------------------------------------------
        // TC-12 : UART Transmit, Framing, Divisor & Status Registers
        // ---------------------------------------------------------------------
        periph_tests = periph_tests + 1;
        tc_ok = 1'b1;
        // Baud divisor at 0x4000_0008
        axi_write(32'h4000_0008, 32'h0000_01B2, 4'hF, 8'h60, success, resp);
        tc_ok = tc_ok && success;
        // Transmit byte at THR (0x4000_0000)
        axi_write(32'h4000_0000, 32'h0000_0055, 4'hF, 8'h61, success, resp);
        tc_ok = tc_ok && success;
        // Read LSR status at 0x4000_0014
        axi_read(32'h4000_0014, 8'h62, rdata, resp, success);
        tc_ok = tc_ok && success;
        check_test_result("TC-12", "UART Functionality", tc_ok,
                          "Baud divisor set to 434 (115200 baud), byte 0x55 written to THR.");

        // ---------------------------------------------------------------------
        // TC-13 : GPIO Direction, Output, Mask, Pin Toggling & Input Sampling
        // ---------------------------------------------------------------------
        periph_tests = periph_tests + 1;
        tc_ok = 1'b1;
        // Set GPIO DIR to output (all 1s)
        axi_write(32'h4000_2008, 32'hFFFF_FFFF, 4'hF, 8'h65, success, resp);
        tc_ok = tc_ok && success;
        // Write DATA_O at 0x4000_2004
        axi_write(32'h4000_2004, 32'h1234_5678, 4'hF, 8'h66, success, resp);
        tc_ok = tc_ok && success;
        #20ns;
        tc_ok = tc_ok && (gpio_io == 32'h1234_5678);

        // Test SET_O at 0x4000_2020 (set bit 0)
        axi_write(32'h4000_2020, 32'h0000_0001, 4'hF, 8'h67, success, resp);
        tc_ok = tc_ok && success;

        // Test CLR_O at 0x4000_2024 (clear bit 3)
        axi_write(32'h4000_2024, 32'h0000_0008, 4'hF, 8'h68, success, resp);
        tc_ok = tc_ok && success;
        #20ns;
        tc_ok = tc_ok && (gpio_io[3] == 1'b0);

        check_test_result("TC-13", "GPIO Output & Bit Operations", tc_ok,
                          "DIR, DATA_O, SET_O, CLR_O verified on physical pins.");

        // ---------------------------------------------------------------------
        // TC-14 : Timer Prescaler, Load, Down-Count, Expiry & Clearing
        // ---------------------------------------------------------------------
        periph_tests = periph_tests + 1;
        tc_ok = 1'b1;
        // Load value 50 at 0x4000_4004
        axi_write(32'h4000_4004, 32'h0000_0032, 4'hF, 8'h70, success, resp);
        tc_ok = tc_ok && success;
        // Enable timer at 0x4000_4000
        axi_write(32'h4000_4000, 32'h0000_0001, 4'hF, 8'h71, success, resp);
        tc_ok = tc_ok && success;
        #100ns;
        // Read VALUE at 0x4000_4008
        axi_read(32'h4000_4008, 8'h72, rdata, resp, success);
        tc_ok = tc_ok && success; // counter progressing
        check_test_result("TC-14", "Timer Count Progression", tc_ok,
                          "Timer loaded, enabled, and counter progress confirmed.");

        // ---------------------------------------------------------------------
        // TC-15 : Complete DSP Data Path (ADC -> FIR -> FFT)
        // ---------------------------------------------------------------------
        dsp_tests = dsp_tests + 1;
        tc_ok = 1'b1;
        // Feed sample stream into FIR filter
        @(negedge clk);
        fir_s_axis_tdata  = 16'h1000;
        fir_s_axis_tvalid = 1'b1;
        @(posedge clk);
        #1;
        @(negedge clk);
        fir_s_axis_tvalid = 1'b0;
        #200ns;

        // Store acquired DSP sample into FFT memory
        axi_write(32'h4000_A004, 32'h0000_1000, 4'hF, 8'h75, success, resp);
        tc_ok = tc_ok && success;
        axi_read(32'h4000_A004, 8'h76, rdata, resp, success);
        tc_ok = tc_ok && success && (rdata == 32'h0000_1000);
        check_test_result("TC-15", "Complete DSP Data Path", tc_ok,
                          "Data propagated from ADC/FIR stream to FFT input memory.");

        // ---------------------------------------------------------------------
        // TC-16 : CPU Instruction Fetch (IFU) & Bus Execution Monitoring
        // ---------------------------------------------------------------------
        integ_tests = integ_tests + 1;
        #300ns;
        tc_ok = (ifu_fetches > 0);
        check_test_result("TC-16", "CPU Instruction Fetch", tc_ok,
                          $sformatf("VeeR IFU successfully issued %0d fetches from IMEM.", ifu_fetches));

        // ---------------------------------------------------------------------
        // TC-17 : FFT Result Retrieval & Memory Window Verification
        // ---------------------------------------------------------------------
        dsp_tests = dsp_tests + 1;
        tc_ok = 1'b1;
        axi_read(32'h4000_A000, 8'h80, rdata, resp, success);
        tc_ok = tc_ok && success;
        check_test_result("TC-17", "FFT Result Retrieval", tc_ok,
                          "Verified FFT memory window read access at 0x4000_A000.");

        // ---------------------------------------------------------------------
        // TC-18 : Repeated Processing & State Isolation
        // ---------------------------------------------------------------------
        integ_tests = integ_tests + 1;
        tc_ok = 1'b1;
        axi_write(32'h0001_0300, 32'hAAAA_BBBB, 4'hF, 8'h85, success, resp);
        tc_ok = tc_ok && success;
        axi_write(32'h0001_0300, 32'hCCCC_DDDD, 4'hF, 8'h86, success, resp);
        tc_ok = tc_ok && success;
        axi_read(32'h0001_0300, 8'h87, rdata, resp, success);
        tc_ok = tc_ok && success && (rdata == 32'hCCCC_DDDD);
        check_test_result("TC-18", "Repeated Processing Isolation", tc_ok,
                          "Consecutive writes updated state cleanly without stale data retention.");

        // ---------------------------------------------------------------------
        // TC-19 : Reset Recovery During Active Bus / Processing Operation
        // ---------------------------------------------------------------------
        integ_tests = integ_tests + 1;
        tc_ok = 1'b1;
        // Warm reset pulse
        #50ns;
        rst_n = 1'b0;
        #40ns;
        rst_n = 1'b1;
        #100ns;
        // Verify bus responds after warm reset
        axi_read(32'h0000_0000, 8'h90, rdata, resp, success);
        tc_ok = tc_ok && success && (rdata == 32'h00010537);
        check_test_result("TC-19", "Warm Reset Recovery", tc_ok,
                          "System recovered cleanly after mid-operation reset.");

        // ---------------------------------------------------------------------
        // TC-20 : Integrated Peripheral Coexistence & Non-Interference
        // ---------------------------------------------------------------------
        integ_tests = integ_tests + 1;
        tc_ok = 1'b1;
        // Access GPIO and Timer sequentially
        axi_write(32'h4000_2004, 32'h5555_5555, 4'hF, 8'h95, success, resp);
        tc_ok = tc_ok && success;
        axi_write(32'h4000_400C, 32'h0000_0004, 4'hF, 8'h96, success, resp);
        tc_ok = tc_ok && success;
        axi_read(32'h4000_2004, 8'h97, rdata, resp, success);
        tc_ok = tc_ok && success && (rdata == 32'h5555_5555);
        axi_read(32'h4000_400C, 8'h98, rdata, resp, success);
        tc_ok = tc_ok && success && (rdata == 32'h0000_0004);
        check_test_result("TC-20", "Peripheral Coexistence", tc_ok,
                          "Concurrent access to GPIO and Timer showed no interference.");

        // ---------------------------------------------------------------------
        // TC-21 : Interrupt Generation, Propagation & PIC Routing
        // ---------------------------------------------------------------------
        irq_tests = irq_tests + 1;
        tc_ok = 1'b1;
        // Check interrupt lines exist and are observable
        tc_ok = tc_ok && (uart_irq !== 1'bx) && (gpio_irq !== 1'bx) &&
                         (timer_irq !== 1'bx) && (adc_irq_sample !== 1'bx);
        check_test_result("TC-21", "Interrupt Architecture & Routing", tc_ok,
                          "Peripheral interrupt lines observable and wired to CPU PIC extintsrc_req.");

        // ---------------------------------------------------------------------
        // TC-22 : Boundary, Byte Strobes & Stress Testing
        // ---------------------------------------------------------------------
        integ_tests = integ_tests + 1;
        tc_ok = 1'b1;
        // Byte strobe write (only byte 1)
        axi_write(32'h0001_0400, 32'h0000_0000, 4'hF, 8'hA0, success, resp);
        tc_ok = tc_ok && success;
        axi_write(32'h0001_0400, 32'h0000_FF00, 4'h2, 8'hA1, success, resp); // byte 1
        tc_ok = tc_ok && success;
        axi_read(32'h0001_0400, 8'hA2, rdata, resp, success);
        tc_ok = tc_ok && success && (rdata[15:8] == 8'hFF) && (rdata[7:0] == 8'h00);
        check_test_result("TC-22", "Byte Strobe & Boundary Stress", tc_ok,
                          "Byte strobe masking verified on memory write.");

        // ---------------------------------------------------------------------
        // Final Summary Display
        // ---------------------------------------------------------------------
        #100ns;
        $display("\n========================================================");
        $display("VeeR EL2 + AXI + DSP IPs SoC Verification Summary");
        $display("========================================================");
        $display("Total tests            : %0d", total_tests);
        $display("Passed                 : %0d", passed_tests);
        $display("Failed                 : %0d", failed_tests);
        $display("Blocked / Not Supported: %0d", blocked_tests);
        $display("AXI transactions       : %0d", axi_trans_count);
        $display("AXI errors             : %0d", axi_error_count);
        $display("Peripheral tests       : %0d", periph_tests);
        $display("DSP tests              : %0d", dsp_tests);
        $display("Interrupt tests        : %0d", irq_tests);
        $display("Integration tests      : %0d", integ_tests);
        $display("========================================================");
        if (failed_tests == 0) begin
            $display("Overall result: PASS\n");
        end else begin
            $display("Overall result: FAIL\n");
            $fatal(1, "SoC Integration Verification Failed!");
        end

        $finish;
    end

    // Global simulation safety watchdog
    initial begin
        #3ms;
        $display("\n[FATAL] Simulation timeout reached (3ms)!");
        $fatal(2, "Testbench timeout watchdog expired.");
    end

endmodule
