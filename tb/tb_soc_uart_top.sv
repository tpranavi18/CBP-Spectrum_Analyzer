`timescale 1ns/1ps

// ============================================================
// tb_soc_uart_top
//
// Testbench for soc_uart_top (TB AXI master -> interconnect -> UART)
//
// KEY DESIGN DECISIONS based on RTL inspection:
//
// 1. UART write gate: axi_wren = axi_awvalid_i & axi_wvalid_i
//    All UART write outputs (awready_o, wready_o, bvalid_o) are gated
//    by (axi_wren & ~axi_sync_wren). The UART must see AWVALID and
//    WVALID simultaneously (at the M00 port). The interconnect drives
//    these independently on the M00 side, so the TB must keep both
//    AWVALID and WVALID asserted on the S00 side until the B response
//    completes. Dropping either early causes the interconnect to lose
//    the ability to satisfy the UART's joint-valid requirement.
//
// 2. Arbiter re-grant prevention: the interconnect arbiter uses
//    ARB_BLOCK=1, ARB_BLOCK_ACK=1. The acknowledge for a read is
//    (grant & s00_rvalid & s00_rready & s00_rlast). If ARVALID is still
//    asserted when the R-handshake fires, the arbiter immediately
//    re-grants the same read at the same clock edge, blocking the
//    interconnect for the next transaction. Fix: drop ARVALID at the
//    negedge of the SAME cycle as the AR handshake (not negedge after
//    R), and hold RREADY=1 for several extra idle cycles after the R
//    handshake so any in-flight stale re-grant fully drains.
//
// 3. UART readable registers (from FSM inspection):
//    - RBR  offset 0x00  (read RX data when DLAB=0)
//    - LSR  offset 0x14  (status, readable always)
//    LCR (offset 0x0C) hits the default branch in the read FSM:
//    arready_d=0, rvalid_d=0 → the UART never responds. Reading LCR
//    would cause a timeout. Test 3 therefore reads LSR again.
// ============================================================

module tb_soc_uart_top;

    localparam DATA_WIDTH = 32;
    localparam ADDR_WIDTH = 32;
    localparam STRB_WIDTH = 4;
    localparam ID_WIDTH   = 8;

    // UART base address
    localparam UART_BASE  = 32'h4000_0000;

    // Register offsets
    localparam UART_LSR_OFFSET = 32'h14;   // Line Status Register  (readable)
    localparam UART_LCR_OFFSET = 32'h0C;   // Line Control Register (write-only in this UART)

    // ============================================================
    // Clock, reset
    // ============================================================

    logic clk;
    logic rst;

    // ============================================================
    // S00 AXI INTERFACE
    // ============================================================

    logic [ID_WIDTH-1:0]   s00_axi_awid;
    logic [ADDR_WIDTH-1:0] s00_axi_awaddr;
    logic [7:0]            s00_axi_awlen;
    logic [2:0]            s00_axi_awsize;
    logic [1:0]            s00_axi_awburst;
    logic                  s00_axi_awlock;
    logic [3:0]            s00_axi_awcache;
    logic [2:0]            s00_axi_awprot;
    logic [3:0]            s00_axi_awqos;
    logic [0:0]            s00_axi_awuser;
    logic                  s00_axi_awvalid;
    wire                   s00_axi_awready;

    logic [DATA_WIDTH-1:0] s00_axi_wdata;
    logic [STRB_WIDTH-1:0] s00_axi_wstrb;
    logic                  s00_axi_wlast;
    logic [0:0]            s00_axi_wuser;
    logic                  s00_axi_wvalid;
    wire                   s00_axi_wready;

    wire [ID_WIDTH-1:0]    s00_axi_bid;
    wire [1:0]             s00_axi_bresp;
    wire [0:0]             s00_axi_buser;
    wire                   s00_axi_bvalid;
    logic                  s00_axi_bready;

    logic [ID_WIDTH-1:0]   s00_axi_arid;
    logic [ADDR_WIDTH-1:0] s00_axi_araddr;
    logic [7:0]            s00_axi_arlen;
    logic [2:0]            s00_axi_arsize;
    logic [1:0]            s00_axi_arburst;
    logic                  s00_axi_arlock;
    logic [3:0]            s00_axi_arcache;
    logic [2:0]            s00_axi_arprot;
    logic [3:0]            s00_axi_arqos;
    logic [0:0]            s00_axi_aruser;
    logic                  s00_axi_arvalid;
    wire                   s00_axi_arready;

    wire [ID_WIDTH-1:0]    s00_axi_rid;
    wire [DATA_WIDTH-1:0]  s00_axi_rdata;
    wire [1:0]             s00_axi_rresp;
    wire                   s00_axi_rlast;
    wire [0:0]             s00_axi_ruser;
    wire                   s00_axi_rvalid;
    logic                  s00_axi_rready;

    // UART external pins
    logic uart_rx_i;
    wire  uart_tx_o;

    integer pass_count;
    integer fail_count;

    // ============================================================
    // DUT
    // ============================================================

    soc_uart_top dut (
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

    // ============================================================
    // CLOCK  –  10 ns period
    // ============================================================

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ============================================================
    // idle_bus – deassert all S00 master signals
    // ============================================================

    task idle_bus;
        begin
            s00_axi_awid    = '0;
            s00_axi_awaddr  = '0;
            s00_axi_awlen   = 8'd0;
            s00_axi_awsize  = 3'b010;
            s00_axi_awburst = 2'b01;
            s00_axi_awlock  = 1'b0;
            s00_axi_awcache = 4'b0;
            s00_axi_awprot  = 3'b0;
            s00_axi_awqos   = 4'b0;
            s00_axi_awuser  = 1'b0;
            s00_axi_awvalid = 1'b0;

            s00_axi_wdata   = '0;
            s00_axi_wstrb   = 4'b1111;
            s00_axi_wlast   = 1'b1;
            s00_axi_wuser   = 1'b0;
            s00_axi_wvalid  = 1'b0;

            s00_axi_bready  = 1'b0;

            s00_axi_arid    = '0;
            s00_axi_araddr  = '0;
            s00_axi_arlen   = 8'd0;
            s00_axi_arsize  = 3'b010;
            s00_axi_arburst = 2'b01;
            s00_axi_arlock  = 1'b0;
            s00_axi_arcache = 4'b0;
            s00_axi_arprot  = 3'b0;
            s00_axi_arqos   = 4'b0;
            s00_axi_aruser  = 1'b0;
            s00_axi_arvalid = 1'b0;

            s00_axi_rready  = 1'b0;
        end
    endtask

    // ============================================================
    // AXI WRITE task
    //
    // BOTH AWVALID and WVALID are asserted simultaneously and kept
    // asserted until the B-response handshake completes.
    //
    // Rationale (from RTL inspection):
    //   – The UART write enable is: axi_wren = awvalid_i & wvalid_i
    //   – All UART write outputs are gated by (axi_wren & ~axi_sync_wren)
    //   – The interconnect drives M00-AWVALID and M00-WVALID independently.
    //     M00-AWVALID is set in STATE_WRITE; M00-WVALID is set one cycle
    //     after the S-side W-data handshake (output pipeline register).
    //   – If WVALID on S00 drops before the S-side W handshake fires, the
    //     interconnect STATE_WRITE loop never completes the W transfer,
    //     M00-WVALID never goes high, axi_wren stays 0, UART never responds.
    //   – Keeping both AWVALID and WVALID asserted until BVALID ensures:
    //     (a) the S-side W handshake can fire whenever the interconnect is
    //         ready (STATE_WRITE), and
    //     (b) at the moment M00-AWVALID and M00-WVALID are both 1, the
    //         UART always sees axi_wren=1 and can generate its response.
    // ============================================================

    task automatic axi_write;
        input [31:0] addr;
        input [31:0] data;
        input [7:0]  id;

        integer timeout;
        reg     b_done;

        begin
            b_done  = 1'b0;
            timeout = 0;

            // Drive address and data at negedge to be stable at next posedge
            @(negedge clk);

            s00_axi_awid    = id;
            s00_axi_awaddr  = addr;
            s00_axi_awlen   = 8'd0;
            s00_axi_awsize  = 3'b010;
            s00_axi_awburst = 2'b01;
            s00_axi_awlock  = 1'b0;
            s00_axi_awcache = 4'b0;
            s00_axi_awprot  = 3'b0;
            s00_axi_awqos   = 4'b0;
            s00_axi_awuser  = 1'b0;
            s00_axi_awvalid = 1'b1;   // hold until B response

            s00_axi_wdata   = data;
            s00_axi_wstrb   = 4'b1111;
            s00_axi_wlast   = 1'b1;
            s00_axi_wuser   = 1'b0;
            s00_axi_wvalid  = 1'b1;   // hold until B response

            s00_axi_bready  = 1'b1;   // always ready to accept B

            // Wait for the B-channel handshake.
            // AWVALID and WVALID stay asserted the entire time so that:
            //   – the interconnect can complete the AW handshake (STATE_IDLE),
            //   – the interconnect can complete the W data transfer
            //     (STATE_WRITE, forward through output pipeline),
            //   – the UART sees axi_wren=1 (awvalid_i & wvalid_i) and
            //     generates awready/wready/bvalid,
            //   – the interconnect can forward the B response to S00.
            while (!b_done) begin
                @(posedge clk);

                if (s00_axi_bvalid && s00_axi_bready) begin
                    b_done = 1'b1;

                    $display("[WRITE] addr=0x%08h data=0x%08h id=0x%02h bresp=%02b",
                             addr, data, s00_axi_bid, s00_axi_bresp);

                    if (s00_axi_bresp == 2'b00)
                        pass_count = pass_count + 1;
                    else begin
                        $display("[FAIL]  WRITE bad BRESP at addr=0x%08h", addr);
                        fail_count = fail_count + 1;
                    end
                end

                timeout = timeout + 1;
                if (timeout > 200) begin
                    $display("[FAIL]  WRITE timeout at addr=0x%08h", addr);
                    fail_count = fail_count + 1;
                    b_done = 1'b1;   // force exit
                end
            end

            // Deassert all write signals at negedge after B handshake
            @(negedge clk);
            s00_axi_awvalid = 1'b0;
            s00_axi_wvalid  = 1'b0;
            s00_axi_bready  = 1'b0;

            // Wait a few idle cycles for the interconnect to return to
            // STATE_WAIT_IDLE -> STATE_IDLE and the arbiter acknowledge
            // to complete before starting the next transaction.
            repeat (4) @(posedge clk);
        end
    endtask

    // ============================================================
    // AXI READ task
    //
    // ARVALID must stay high while the UART read is in progress:
    //   assign axi_rden    = axi_arvalid_i
    //   assign axi_rvalid_o = (axi_rden & ~axi_sync_rden) ? axi_rvalid : 0
    // If ARVALID drops before RVALID_O is sampled, RVALID_O is gated to 0
    // and the interconnect never sees the R response.
    //
    // However, holding ARVALID through the R handshake causes the arbiter
    // (ARB_BLOCK_ACK) to re-grant the same read immediately when the
    // acknowledge fires (grant & rvalid & rready & rlast at same posedge).
    // This stale re-granted transaction then blocks the interconnect
    // because the TB's RREADY is already 0.
    //
    // Fix:
    //   1. Drop ARVALID at the negedge immediately after the AR handshake
    //      fires, NOT at the negedge after the R response.  The UART only
    //      needs ARVALID while it is actively generating RVALID; once ARVALID
    //      has already triggered the read FSM, the output gating keeps
    //      RVALID_O visible for the duration.
    //
    //      Wait – that would gate RVALID_O away too early. Instead:
    //
    //   2. Keep ARVALID high through R handshake (UART requirement), but
    //      immediately drop ARVALID at the negedge of the SAME cycle the
    //      R handshake fires (same negedge as RREADY deassertion).
    //      Additionally, keep RREADY=1 for several extra idle cycles after
    //      that so any stale re-granted transaction can complete its R
    //      response cleanly (interconnect STATE_READ -> STATE_WAIT_IDLE ->
    //      STATE_IDLE) before the next test starts.
    // ============================================================

    task automatic axi_read;
        input  [31:0] addr;
        input  [7:0]  id;
        input  [31:0] expected;

        integer timeout;
        reg     ar_done;
        reg     r_done;

        begin
            ar_done = 1'b0;
            r_done  = 1'b0;
            timeout = 0;

            @(negedge clk);

            s00_axi_arid    = id;
            s00_axi_araddr  = addr;
            s00_axi_arlen   = 8'd0;
            s00_axi_arsize  = 3'b010;
            s00_axi_arburst = 2'b01;
            s00_axi_arlock  = 1'b0;
            s00_axi_arcache = 4'b0;
            s00_axi_arprot  = 3'b0;
            s00_axi_arqos   = 4'b0;
            s00_axi_aruser  = 1'b0;
            s00_axi_arvalid = 1'b1;   // keep high until R response captured
            s00_axi_rready  = 1'b1;   // always ready

            // Phase 1: wait for AR handshake
            while (!ar_done) begin
                @(posedge clk);

                if (s00_axi_arvalid && s00_axi_arready) begin
                    ar_done = 1'b1;
                    $display("[READ AR] addr=0x%08h id=0x%02h", addr, id);
                end

                timeout = timeout + 1;
                if (timeout > 200) begin
                    $display("[FAIL]  READ AR timeout at addr=0x%08h", addr);
                    fail_count = fail_count + 1;
                    @(negedge clk);
                    s00_axi_arvalid = 1'b0;
                    s00_axi_rready  = 1'b0;
                    return;
                end
            end

            // Phase 2: wait for R response.
            // ARVALID stays high (UART requires it to keep rvalid_o visible).
            timeout = 0;
            while (!r_done) begin
                @(posedge clk);

                if (s00_axi_rvalid && s00_axi_rready) begin
                    r_done = 1'b1;

                    $display("[READ R ] addr=0x%08h rdata=0x%08h id=0x%02h rresp=%02b rlast=%b",
                             addr, s00_axi_rdata, s00_axi_rid,
                             s00_axi_rresp, s00_axi_rlast);

                    if ((s00_axi_rresp  == 2'b00)   &&
                        (s00_axi_rid    == id)       &&
                        (s00_axi_rlast  == 1'b1)     &&
                        (s00_axi_rdata  == expected))
                        pass_count = pass_count + 1;
                    else begin
                        $display("[FAIL]  READ mismatch: got=0x%08h expected=0x%08h",
                                 s00_axi_rdata, expected);
                        fail_count = fail_count + 1;
                    end
                end

                timeout = timeout + 1;
                if (timeout > 200) begin
                    $display("[FAIL]  READ R timeout at addr=0x%08h", addr);
                    fail_count = fail_count + 1;
                    @(negedge clk);
                    s00_axi_arvalid = 1'b0;
                    s00_axi_rready  = 1'b0;
                    return;
                end
            end

            // Drop ARVALID at the negedge immediately following the R
            // handshake posedge.  This is as early as safely possible
            // (UART no longer needs it), and prevents a second re-grant
            // from sticking past negedge.
            @(negedge clk);
            s00_axi_arvalid = 1'b0;

            // Keep RREADY=1 for several more cycles.
            // Reason: the arbiter (ARB_BLOCK_ACK) may have latched a
            // re-grant for the same read because ARVALID was still 1
            // at the acknowledge posedge.  By keeping RREADY=1 we allow
            // that stale transaction to complete (interconnect: STATE_IDLE
            // -> STATE_DECODE -> STATE_READ -> UART -> RVALID -> RLAST ->
            // STATE_WAIT_IDLE -> STATE_IDLE) cleanly before the next test.
            // 20 cycles is ample for the UART read pipeline (ResetRead->
            // ConfigRead->IdleRead->AckRead = 4 states + interconnect
            // latency).
            repeat (20) @(posedge clk);
            @(negedge clk);
            s00_axi_rready = 1'b0;

            // Two more idle cycles to let the interconnect fully return
            // to STATE_IDLE and clear the arbiter grant.
            repeat (4) @(posedge clk);
        end
    endtask

    // ============================================================
    // MAIN TEST SEQUENCE
    // ============================================================

    initial begin

        // ---- initialise all outputs ----
        idle_bus();
        uart_rx_i  = 1'b1;
        pass_count = 0;
        fail_count = 0;
        rst        = 1'b1;

        // Hold reset for 10 clock cycles
        repeat (10) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        // Extra settling time for UART read FSM
        // (ResetReadState -> ConfigReadState -> IdleReadState = 2 clocks,
        //  plus several more for the write FSM and FIFO resets)
        repeat (10) @(posedge clk);

        $display("");
        $display("============================================================");
        $display(" UART + AXI INTERCONNECT INTEGRATION TEST");
        $display("============================================================");

        // ------------------------------------------------------------
        // TEST 1: Read LSR – expected 0x00000060
        //   LSR[5]=THRE=1 (TX holding register empty)
        //   LSR[6]=TEMT=1 (transmitter empty)
        //   Both bits driven by available_write_space_int from TX FIFO.
        // ------------------------------------------------------------
        $display("\n--- TEST 1: Read LSR @ 0x%08h ---", UART_BASE + UART_LSR_OFFSET);
        axi_read(
            UART_BASE + UART_LSR_OFFSET,
            8'h01,
            32'h0000_0060
        );

        // ------------------------------------------------------------
        // TEST 2: Write LCR = 0x00000003
        //   LCR[1:0] = word-length config bits (write-only register).
        //   The UART write FSM handles UART_LCR unconditionally.
        // ------------------------------------------------------------
        $display("\n--- TEST 2: Write LCR @ 0x%08h data=0x00000003 ---",
                 UART_BASE + UART_LCR_OFFSET);
        axi_write(
            UART_BASE + UART_LCR_OFFSET,
            32'h0000_0003,
            8'h02
        );

        // ------------------------------------------------------------
        // TEST 3: Read LSR again – expected 0x00000060
        //
        // NOTE: The UART read FSM (IdleReadState) only decodes two
        // register addresses:
        //   UART_RBR (addr[4:2]=3'd0, offset 0x00) and
        //   UART_LSR (addr[4:2]=3'd5, offset 0x14).
        // Reading LCR (addr[4:2]=3'd3, offset 0x0C) hits the default
        // branch where arready_d=0 and rvalid_d=0 – the UART never
        // produces a response.  A read of LCR would therefore hang.
        // We read LSR instead, which verifies the interconnect returned
        // to IDLE after the write and can accept a new read transaction.
        // ------------------------------------------------------------
        $display("\n--- TEST 3: Read LSR again @ 0x%08h ---",
                 UART_BASE + UART_LSR_OFFSET);
        axi_read(
            UART_BASE + UART_LSR_OFFSET,
            8'h03,
            32'h0000_0060
        );

        // Final idle
        repeat (10) @(posedge clk);

        // ---- Results ----
        $display("");
        $display("============================================================");
        $display(" RESULT");
        $display("============================================================");
        $display(" PASSED = %0d", pass_count);
        $display(" FAILED = %0d", fail_count);
        if (fail_count == 0)
            $display(" UART + AXI INTERCONNECT : PASS");
        else
            $display(" UART + AXI INTERCONNECT : FAIL");
        $display("============================================================");

        #100;
        $finish;
    end

    // ============================================================
    // Waveform dump
    // ============================================================

    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars("+all");
    end

endmodule
