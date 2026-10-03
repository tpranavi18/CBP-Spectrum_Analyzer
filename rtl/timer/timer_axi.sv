//
// General Purpose Timer AXI4-Lite Wrapper
//
// Description:
//   AXI4-Lite Interface wrapper for the General Timer.
//

module timer_axi (
    input logic aclk,
    input logic aresetn,

    // AXI4-Lite Write Address
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic [31:0] awaddr,
    input  logic [ 2:0] awprot,
    /* verilator lint_on UNUSEDSIGNAL */
    input  logic        awvalid,
    output logic        awready,

    // AXI4-Lite Write Data
    input  logic [31:0] wdata,
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic [ 3:0] wstrb,
    /* verilator lint_on UNUSEDSIGNAL */
    input  logic        wvalid,
    output logic        wready,

    // AXI4-Lite Write Response
    output logic [1:0] bresp,
    output logic       bvalid,
    input  logic       bready,

    // AXI4-Lite Read Address
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic [31:0] araddr,
    input  logic [ 2:0] arprot,
    /* verilator lint_on UNUSEDSIGNAL */
    input  logic        arvalid,
    output logic        arready,

    // AXI4-Lite Read Data
    output logic [31:0] rdata,
    output logic [ 1:0] rresp,
    output logic        rvalid,
    input  logic        rready,

    // External IO
    input  logic ext_meas_i,
    input  logic capture_i,
    output logic pwm_o,
    output logic trigger_o,

    // Interrupt
    output logic irq
);

  // Internal signals
  logic cs, we;
  logic [ 5:0] addr;
  /* verilator lint_off UNUSEDSIGNAL */
  logic [31:0] reg_rdata;
  logic [31:0] reg_wdata;
  /* verilator lint_on UNUSEDSIGNAL */

  /* verilator lint_off UNUSEDSIGNAL */
  logic
      en,
      mode,
      dir,
      pwm_en,
      ext_en,
      cap_en,
      pre_en,
      load_cmd,
      core_irq_pulse,
      capture_stb,
      core_intr;
  /* verilator lint_on UNUSEDSIGNAL */
  logic [15:0] pre_val;
  logic [31:0] load_val, cmp_val, current_val, capture_val;

  // AXI State signals
  // logic aw_en; // Removed unused signal
  // State Machine / Handshaking


  logic read_en;
  /* verilator lint_off UNUSEDSIGNAL */
  logic [31:0] axi_addr_32;
  /* verilator lint_on UNUSEDSIGNAL */


  // AXI4-Lite Slave Adapter
  /* verilator lint_off PINCONNECTEMPTY */
  axi4lite_slave_adapter #(
      .ADDR_WIDTH(32),
      .DATA_WIDTH(32)
  ) u_axi_adapter (
      .aclk         (aclk),
      .aresetn      (aresetn),
      .s_axi_awaddr (awaddr),
      .s_axi_awprot (awprot),
      .s_axi_awvalid(awvalid),
      .s_axi_awready(awready),
      .s_axi_wdata  (wdata),
      .s_axi_wstrb  (wstrb),
      .s_axi_wvalid (wvalid),
      .s_axi_wready (wready),
      .s_axi_bresp  (bresp),
      .s_axi_bvalid (bvalid),
      .s_axi_bready (bready),
      .s_axi_araddr (araddr),
      .s_axi_arprot (arprot),
      .s_axi_arvalid(arvalid),
      .s_axi_arready(arready),
      .s_axi_rdata  (rdata),        // Adapter output connected to port
      // Wait, adapter drives rdata port? Yes.
      // But I need to intercept it?
      // Adapter.s_axi_rdata = reg_rdata_input.
      // I feed rdata_q into reg_rdata_input.
      // So .s_axi_rdata(rdata) is correct.
      .s_axi_rresp  (rresp),
      .s_axi_rvalid (rvalid),
      .s_axi_rready (rready),
      .reg_addr     (axi_addr_32),
      .reg_wdata    (reg_wdata),
      .reg_rdata    (reg_rdata),
      .reg_we       (we),
      .reg_re       (read_en),
      .reg_be       ()
  );
  /* verilator lint_on PINCONNECTEMPTY */

  assign addr = axi_addr_32[5:0];
  assign cs   = we || read_en;



  // Assign interrupt
  assign irq  = core_intr;

  // Instantiate Registers
  timer_regs u_timer_regs (
      .clk        (aclk),
      .rst_n      (aresetn),
      .cs         (cs),
      .we         (we),
      .addr       (addr),
      .wdata      (reg_wdata),
      .rdata      (reg_rdata),
      .en         (en),
      .mode       (mode),
      .dir        (dir),
      .pwm_en     (pwm_en),
      .ext_en     (ext_en),
      .cap_en     (cap_en),
      .pre_en     (pre_en),
      .pre_val    (pre_val),
      .load_val   (load_val),
      .cmp_val    (cmp_val),
      .load_cmd   (load_cmd),
      .current_val(current_val),
      .capture_val(capture_val),
      .capture_stb(capture_stb),
      .core_irq   (core_irq_pulse),
      .intr_o     (core_intr)
  );

  // Instantiate Timer Core
  timer_core u_timer_core (
      .clk        (aclk),
      .rst_n      (aresetn),
      .en         (en),
      .mode       (mode),
      .dir        (dir),
      .pwm_en     (pwm_en),
      .ext_en     (ext_en),
      .pre_en     (pre_en),
      .pre_val    (pre_val),
      .load_val   (load_val),
      .cmp_val    (cmp_val),
      .load_cmd   (load_cmd),
      .ext_meas_i (ext_meas_i),
      .capture_i  (capture_i),
      .current_val(current_val),
      .capture_val(capture_val),
      .capture_stb(capture_stb),
      .pwm_o      (pwm_o),
      .trigger_o  (trigger_o),
      .irq        (core_irq_pulse)
  );

endmodule
