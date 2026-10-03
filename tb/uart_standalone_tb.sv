//`timescale 1ns/1ps

module uart_standalone_tb;

  localparam integer DATA_WIDTH = 32;
  localparam integer ADDR_WIDTH = 5;
  localparam integer ID_WIDTH   = 12;
  localparam integer RESP_WIDTH = 2;

  localparam [ADDR_WIDTH-1:0] ADDR_RBR      = 5'h00;
  localparam [ADDR_WIDTH-1:0] ADDR_THR      = 5'h00;
  localparam [ADDR_WIDTH-1:0] ADDR_IER      = 5'h04;
  localparam [ADDR_WIDTH-1:0] ADDR_BAUD_DIV = 5'h08;
  localparam [ADDR_WIDTH-1:0] ADDR_LCR      = 5'h0C;
  localparam [ADDR_WIDTH-1:0] ADDR_LSR      = 5'h14;

  localparam integer BAUD_DIV       = 4;
  localparam integer CLK_HALF_NS    = 5;
  localparam integer TX_BIT_TIME_NS = (BAUD_DIV + 1) * 10;
  // The supplied receiver samples after BAUD_DIV clock cycles.
  localparam integer RX_BIT_TIME_NS = BAUD_DIV * 10;

  reg fixed_clk_i;
  wire axi_aclk_i;
  reg axi_aresetn_i;

  reg  [ID_WIDTH-1:0]   axi_arid_i;
  reg  [ADDR_WIDTH-1:0] axi_araddr_i;
  reg                  axi_arvalid_i;
  wire                 axi_arready_o;
  wire [ID_WIDTH-1:0]  axi_rid_o;
  wire [DATA_WIDTH-1:0] axi_rdata_o;
  wire [RESP_WIDTH-1:0] axi_rresp_o;
  wire                 axi_rvalid_o;
  reg                  axi_rready_i;

  reg  [ID_WIDTH-1:0]   axi_awid_i;
  reg  [ADDR_WIDTH-1:0] axi_awaddr_i;
  reg                  axi_awvalid_i;
  wire                 axi_awready_o;
  reg  [DATA_WIDTH-1:0] axi_wdata_i;
  reg  [DATA_WIDTH/8-1:0] axi_wstrb_i;
  reg                  axi_wvalid_i;
  wire                 axi_wready_o;
  wire [ID_WIDTH-1:0]   axi_bid_o;
  wire [RESP_WIDTH-1:0] axi_bresp_o;
  wire                 axi_bvalid_o;
  reg                  axi_bready_i;

  reg  uart_rx_drive;
  reg  rx_loopback;
  wire uart_rx_i;
  wire uart_tx_o;
  wire read_interrupt_o;

  assign axi_aclk_i = fixed_clk_i;
  assign uart_rx_i  = rx_loopback ? uart_tx_o : uart_rx_drive;

  axi_uart_top dut (
    .fixed_clk_i      (fixed_clk_i),
    .axi_aclk_i       (axi_aclk_i),
    .axi_aresetn_i    (axi_aresetn_i),
    .axi_arid_i       (axi_arid_i),
    .axi_araddr_i     (axi_araddr_i),
    .axi_arvalid_i    (axi_arvalid_i),
    .axi_arready_o    (axi_arready_o),
    .axi_rid_o        (axi_rid_o),
    .axi_rdata_o      (axi_rdata_o),
    .axi_rresp_o      (axi_rresp_o),
    .axi_rvalid_o     (axi_rvalid_o),
    .axi_rready_i     (axi_rready_i),
    .axi_awid_i       (axi_awid_i),
    .axi_awaddr_i     (axi_awaddr_i),
    .axi_awvalid_i    (axi_awvalid_i),
    .axi_awready_o    (axi_awready_o),
    .axi_wdata_i      (axi_wdata_i),
    .axi_wstrb_i      (axi_wstrb_i),
    .axi_wvalid_i     (axi_wvalid_i),
    .axi_wready_o     (axi_wready_o),
    .axi_bid_o        (axi_bid_o),
    .axi_bresp_o      (axi_bresp_o),
    .axi_bvalid_o     (axi_bvalid_o),
    .axi_bready_i     (axi_bready_i),
    .read_interrupt_o (read_interrupt_o),
    .uart_rx_i        (uart_rx_i),
    .uart_tx_o        (uart_tx_o)
  );

  always #(CLK_HALF_NS) fixed_clk_i = ~fixed_clk_i;

  initial begin
    fixed_clk_i    = 1'b0;
    axi_aresetn_i  = 1'b0;
    axi_arid_i     = '0;
    axi_araddr_i   = '0;
    axi_arvalid_i  = 1'b0;
    axi_rready_i   = 1'b1;
    axi_awid_i     = '0;
    axi_awaddr_i   = '0;
    axi_awvalid_i  = 1'b0;
    axi_wdata_i    = '0;
    axi_wstrb_i    = 4'b1111;
    axi_wvalid_i   = 1'b0;
    axi_bready_i   = 1'b1;
    uart_rx_drive  = 1'b1;
    rx_loopback    = 1'b0;

    repeat (8) @(posedge fixed_clk_i);
    axi_aresetn_i = 1'b1;
    repeat (8) @(posedge fixed_clk_i);

    $display("============================================================");
    $display("UART STANDALONE TESTBENCH START");
    $display("============================================================");

    test_register_reads;
    configure_uart;
    test_tx_frame(8'hA5);
    test_rx_loopback(8'h3C);

    $display("============================================================");
    $display("UART STANDALONE TESTBENCH PASS");
    $display("============================================================");
    #100;
    $finish;
  end

  // Safety watchdog only. A correctly operating testbench should finish first.
  initial begin
    #10_000_000;
    $display("[ERROR] TESTBENCH WATCHDOG TIMEOUT");
    $finish;
  end

  initial begin
    $dumpfile("uart_standalone.vcd");
    $dumpvars(0, uart_standalone_tb);
  end

  // Keep both write valid signals asserted until the slave response is visible.
  // This is required by the supplied RTL because BVALID is gated by AWVALID/WVALID.
  task automatic axi_write(
    input [ADDR_WIDTH-1:0] addr,
    input [DATA_WIDTH-1:0] data
  );
    integer guard;
    reg accepted;
    begin
      @(negedge fixed_clk_i);
      axi_awid_i    = 12'h001;
      axi_awaddr_i  = addr;
      axi_awvalid_i = 1'b1;
      axi_wdata_i   = data;
      axi_wstrb_i   = 4'b1111;
      axi_wvalid_i  = 1'b1;
      accepted      = 1'b0;
      guard         = 0;

      while (!accepted && guard < 1000) begin
        @(posedge fixed_clk_i);
        if (axi_awready_o && axi_wready_o)
          accepted = 1'b1;
        guard = guard + 1;
      end

      if (!accepted) begin
        $display("[ERROR] AXI WRITE ACCEPT TIMEOUT: addr=0x%02h", addr);
        $finish;
      end

      guard = 0;
      while (!axi_bvalid_o && guard < 1000) begin
        @(posedge fixed_clk_i);
        guard = guard + 1;
      end

      if (!axi_bvalid_o) begin
        $display("[ERROR] AXI WRITE RESPONSE TIMEOUT: addr=0x%02h", addr);
        $finish;
      end

      $display("[AXI WRITE HANDSHAKE] Address = 0x%02h Data = 0x%08h", addr, data);
      $display("[AXI WRITE RESPONSE ] Address = 0x%02h Data = 0x%08h BRESP = %b", addr, data, axi_bresp_o);

      @(negedge fixed_clk_i);
      axi_awvalid_i = 1'b0;
      axi_wvalid_i  = 1'b0;
    end
  endtask

  // Keep ARVALID asserted until RVALID is observed. The supplied RTL gates
  // RVALID with ARVALID, so deasserting ARVALID immediately after ARREADY
  // can hide the response and make the testbench wait forever.
  task automatic axi_read(
    input  [ADDR_WIDTH-1:0] addr,
    output [DATA_WIDTH-1:0] data
  );
    integer guard;
    reg accepted;
    begin
      @(negedge fixed_clk_i);
      axi_arid_i    = 12'h002;
      axi_araddr_i  = addr;
      axi_arvalid_i = 1'b1;
      accepted      = 1'b0;
      guard         = 0;

      while (!accepted && guard < 1000) begin
        @(posedge fixed_clk_i);
        if (axi_arready_o)
          accepted = 1'b1;
        guard = guard + 1;
      end

      if (!accepted) begin
        $display("[ERROR] AXI READ ACCEPT TIMEOUT: addr=0x%02h", addr);
        $finish;
      end

      guard = 0;
      while (!axi_rvalid_o && guard < 1000) begin
        @(posedge fixed_clk_i);
        guard = guard + 1;
      end

      if (!axi_rvalid_o) begin
        $display("[ERROR] AXI READ RESPONSE TIMEOUT: addr=0x%02h", addr);
        $finish;
      end

      data = axi_rdata_o;
      $display("[AXI READ HANDSHAKE] Address = 0x%02h", addr);
      $display("[AXI READ RESPONSE ] Address = 0x%02h Data = 0x%08h RRESP = %b", addr, data, axi_rresp_o);

      @(negedge fixed_clk_i);
      axi_arvalid_i = 1'b0;
    end
  endtask

  task automatic test_register_reads;
    reg [31:0] read_data;
    begin
      $display("");
      $display("[TEST] Reading initial LSR register");
      axi_read(ADDR_LSR, read_data);
      $display("[LSR] Initial value = 0x%08h", read_data);
      $display("[LSR] DATA_READY = %b", read_data[0]);
      $display("[LSR] THRE       = %b", read_data[5]);
      $display("[LSR] TEMT       = %b", read_data[6]);

      if (read_data[6] !== 1'b1 || read_data[5] !== 1'b1) begin
        $display("[ERROR] Initial LSR expected TEMT=1 and THRE=1");
        $finish;
      end
      $display("[PASS] Initial LSR read completed");
    end
  endtask

  task automatic configure_uart;
    begin
      $display("");
      $display("[TEST] Configuring UART");
      axi_write(ADDR_LCR, 32'h0000_0080);
      axi_write(ADDR_BAUD_DIV, BAUD_DIV);
      axi_write(ADDR_LCR, 32'h0000_0003);
      axi_write(ADDR_IER, 32'h0000_0001);
      $display("[PASS] UART configured: divisor=%0d, format=8N1", BAUD_DIV);
    end
  endtask

  task automatic test_tx_frame(input [7:0] expected_data);
    reg [9:0] expected_frame;
    integer i;
    begin
      $display("");
      $display("[TEST] UART TX frame test: data = 0x%02h", expected_data);
      expected_frame = {1'b1, expected_data, 1'b0};

      axi_write(ADDR_THR, {24'h0, expected_data});
      @(negedge uart_tx_o);

      // Check near the middle of the start bit, then each following bit.
      #(TX_BIT_TIME_NS/2);
      for (i = 0; i < 10; i = i + 1) begin
        if (uart_tx_o !== expected_frame[i]) begin
          $display("[ERROR] TX frame mismatch at bit %0d: expected=%b actual=%b", i, expected_frame[i], uart_tx_o);
          $finish;
        end
        $display("[TX BIT] bit=%0d value=%b", i, uart_tx_o);
        #(TX_BIT_TIME_NS);
      end

      $display("[PASS] TX frame verified for data 0x%02h", expected_data);
    end
  endtask

  task automatic test_rx_loopback(input [7:0] expected_data);
    reg [31:0] lsr_data;
    reg [31:0] rx_data;
    integer timeout_count;
    integer i;
    begin
      $display("");
      $display("[TEST] UART RX standalone serial frame test: data = 0x%02h", expected_data);

      rx_loopback   = 1'b0;
      uart_rx_drive = 1'b1;
      #(RX_BIT_TIME_NS * 2);

      $display("[RX DRIVER] Sending UART frame for data = 0x%02h", expected_data);

      uart_rx_drive = 1'b0;
      $display("[RX DRIVER] START BIT = 0");
      #(RX_BIT_TIME_NS);

      for (i = 0; i < 8; i = i + 1) begin
        uart_rx_drive = expected_data[i];
        $display("[RX DRIVER] DATA BIT %0d = %b", i, expected_data[i]);
        #(RX_BIT_TIME_NS);
      end

      uart_rx_drive = 1'b1;
      $display("[RX DRIVER] STOP BIT = 1");
      #(RX_BIT_TIME_NS);
      uart_rx_drive = 1'b1;
      $display("[RX DRIVER] Frame transmission completed");

      timeout_count = 0;
      lsr_data      = 32'h0;
      while (timeout_count < 200) begin
        axi_read(ADDR_LSR, lsr_data);
        $display("[RX POLL] Count = %0d LSR = 0x%08h DATA_READY = %b", timeout_count, lsr_data, lsr_data[0]);
        if (lsr_data[0] === 1'b1)
          break;
        timeout_count = timeout_count + 1;
      end

      if (lsr_data[0] !== 1'b1) begin
        $display("[ERROR] RX DATA_READY TIMEOUT");
        $display("Last LSR value = 0x%08h", lsr_data);
        $finish;
      end

      $display("[PASS] RX DATA_READY asserted");
      axi_read(ADDR_RBR, rx_data);
      $display("[RX DATA] Expected = 0x%02h Received = 0x%02h", expected_data, rx_data[7:0]);

      if (rx_data[7:0] !== expected_data) begin
        $display("[ERROR] RX data mismatch");
        $display("Expected = 0x%02h Actual = 0x%02h", expected_data, rx_data[7:0]);
        $finish;
      end

      $display("[PASS] RX standalone frame verified for data 0x%02h", expected_data);
      rx_loopback = 1'b0;
    end
  endtask

initial begin
$fsdbDumpfile("dump.fsdb");
$fsdbDumpvars("+all");
$fsdbDumpSVA;
$fsdbDumpMDA;
end

endmodule
