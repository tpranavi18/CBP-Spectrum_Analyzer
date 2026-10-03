`default_nettype none
module adc_controller
  import adc_pkg::*;
#(
  parameter integer ADC_RESOLUTION    = 12,
  parameter integer NUM_CHANNELS      = 1,
  parameter integer FIFO_DEPTH        = 32,
  parameter integer CLK_FREQ_HZ       = 50_000_000,
  parameter integer SAMPLE_RATE_HZ    = 250,
  parameter [31:0]  BASE_ADDR         = 32'h1000_0300,
  parameter integer ENABLE_FIFO       = 1,
  parameter integer ENABLE_INTERRUPTS = 1
)(
  input logic aclk,
  input logic aresetn,

  input logic [ADC_RESOLUTION-1:0] sample_in,
  input logic sample_valid,

  output logic irq_sample,
  output logic irq_overrun,

  input  logic [31:0] s_axi_awaddr,
  input  logic        s_axi_awvalid,
  output logic        s_axi_awready,
  input  logic [31:0] s_axi_wdata,
  input  logic [3:0]  s_axi_wstrb,
  input  logic        s_axi_wvalid,
  output logic        s_axi_wready,
  output logic [1:0]  s_axi_bresp,
  output logic        s_axi_bvalid,
  input  logic        s_axi_bready,

  input  logic [31:0] s_axi_araddr,
  input  logic        s_axi_arvalid,
  output logic        s_axi_arready,
  output logic [31:0] s_axi_rdata,
  output logic [1:0]  s_axi_rresp,
  output logic        s_axi_rvalid,
  input  logic        s_axi_rready
);
  initial begin
    if (NUM_CHANNELS != 1)
      $error("adc_controller: current external interface supports NUM_CHANNELS=1 only");
    if (ADC_RESOLUTION < 1 || ADC_RESOLUTION > 32)
      $error("adc_controller: ADC_RESOLUTION must be 1..32");
    if (FIFO_DEPTH < 2 || (FIFO_DEPTH & (FIFO_DEPTH-1)) != 0)
      $error("adc_controller: FIFO_DEPTH must be a power of 2 and >= 2");
  end

  logic        reg_wr_en, reg_rd_en;
  logic [31:0] reg_wr_addr, reg_wr_data, reg_rd_addr, reg_rd_data;
  logic [3:0]  reg_wr_strb;
  logic        reg_wr_slverr, reg_rd_slverr;

  logic r_enable, r_start;
  logic r_irq_sample_en, r_irq_overrun_en;
  logic reg_fifo_pop;

  logic acq_busy, acq_done;
  logic [ADC_RESOLUTION-1:0] acq_sample;

  logic fifo_wr_en, fifo_rd_en;
  logic [ADC_RESOLUTION-1:0] fifo_wr_data, fifo_rd_data;
  logic fifo_empty, fifo_full;
  logic fifo_rd_valid;

  logic [ADC_RESOLUTION-1:0] sample_data_reg;

  logic done_pulse, overrun_pulse, reqerr_pulse;
  logic irq_sample_int, irq_overrun_int;
  logic periodic_req;
  logic acq_start_pulse;

  // Convert absolute AXI address to register offset.
  // Register block validates the exact offset, so misaligned/invalid
  // addresses still receive SLVERR.
  wire [31:0] wr_offset = reg_wr_addr - BASE_ADDR;
  wire [31:0] rd_offset = reg_rd_addr - BASE_ADDR;

  assign fifo_rd_valid = !fifo_empty;
  assign fifo_rd_en    = reg_fifo_pop;

  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      sample_data_reg <= '0;
      fifo_wr_en      <= 1'b0;
      fifo_wr_data    <= '0;
      done_pulse      <= 1'b0;
      overrun_pulse   <= 1'b0;
      reqerr_pulse    <= 1'b0;
      acq_start_pulse <= 1'b0;
    end else begin
      // Default: clear all one-cycle pulses.
      fifo_wr_en      <= 1'b0;
      done_pulse      <= 1'b0;
      overrun_pulse   <= 1'b0;
      reqerr_pulse    <= 1'b0;
      acq_start_pulse <= 1'b0;

      // -------------------------------------------------------
      // Acquisition completion: update sample register + FIFO.
      // -------------------------------------------------------
      if (acq_done) begin
        sample_data_reg <= acq_sample;
        done_pulse      <= 1'b1;

        if (ENABLE_FIFO) begin
          if (!fifo_full) begin
            fifo_wr_en   <= 1'b1;
            fifo_wr_data <= acq_sample;
          end else begin
            // FIFO full: sample must be discarded.
            // Per spec: set OVERRUN *and* REQUEST_ERROR simultaneously.
            overrun_pulse <= 1'b1;
            reqerr_pulse  <= 1'b1;
          end
        end
      end

      // -------------------------------------------------------
      // Request arbitration: software START > periodic.
      // A request that cannot be accepted raises REQUEST_ERROR.
      // Note: if acq_done fires the same cycle as a new request,
      // the acquisition just completed so acq_busy goes low next
      // cycle; we let the new request proceed.
      // -------------------------------------------------------
      if (acq_busy && !acq_done) begin
        // Busy and not completing this cycle — reject new requests.
        if (r_start || periodic_req)
          reqerr_pulse <= 1'b1;
      end else if (!acq_busy || acq_done) begin
        // Free (or completing this cycle) — accept a new request.
        if (r_start) begin
          acq_start_pulse <= 1'b1;
          // Both start and periodic at once: periodic is lost → REQUEST_ERROR.
          if (periodic_req)
            reqerr_pulse <= 1'b1;
        end else if (periodic_req) begin
          acq_start_pulse <= 1'b1;
        end
      end
    end
  end

  assign irq_sample  = ENABLE_INTERRUPTS ? irq_sample_int  : 1'b0;
  assign irq_overrun = ENABLE_INTERRUPTS ? irq_overrun_int : 1'b0;

  adc_axi_lite_slave u_axil (
    .aclk(aclk), .aresetn(aresetn),
    .s_axi_awaddr(s_axi_awaddr), .s_axi_awvalid(s_axi_awvalid), .s_axi_awready(s_axi_awready),
    .s_axi_wdata(s_axi_wdata), .s_axi_wstrb(s_axi_wstrb), .s_axi_wvalid(s_axi_wvalid), .s_axi_wready(s_axi_wready),
    .s_axi_bresp(s_axi_bresp), .s_axi_bvalid(s_axi_bvalid), .s_axi_bready(s_axi_bready),
    .s_axi_araddr(s_axi_araddr), .s_axi_arvalid(s_axi_arvalid), .s_axi_arready(s_axi_arready),
    .s_axi_rdata(s_axi_rdata), .s_axi_rresp(s_axi_rresp), .s_axi_rvalid(s_axi_rvalid), .s_axi_rready(s_axi_rready),
    .reg_wr_en(reg_wr_en), .reg_wr_addr(reg_wr_addr), .reg_wr_data(reg_wr_data), .reg_wr_strb(reg_wr_strb),
    .reg_rd_en(reg_rd_en), .reg_rd_addr(reg_rd_addr), .reg_rd_data(reg_rd_data),
    .reg_wr_slverr(reg_wr_slverr), .reg_rd_slverr(reg_rd_slverr)
  );

  adc_registers #(.ADC_RESOLUTION(ADC_RESOLUTION)) u_regs (
    .clk(aclk), .rst_n(aresetn),
    .reg_wr_en(reg_wr_en), .reg_wr_addr(wr_offset), .reg_wr_data(reg_wr_data), .reg_wr_strb(reg_wr_strb),
    .reg_rd_en(reg_rd_en), .reg_rd_addr(rd_offset), .reg_rd_data(reg_rd_data),
    .reg_wr_slverr(reg_wr_slverr), .reg_rd_slverr(reg_rd_slverr),
    .i_busy(acq_busy), .i_fifo_empty(fifo_empty), .i_fifo_full(fifo_full),
    .i_sample_data(sample_data_reg),
    .i_fifo_rd_data_valid(fifo_rd_valid), .i_fifo_rd_data(fifo_rd_data),
    .i_done_pulse(done_pulse), .i_overrun_pulse(overrun_pulse), .i_reqerr_pulse(reqerr_pulse),
    .o_enable(r_enable), .o_start(r_start),
    .o_irq_sample_en(r_irq_sample_en), .o_irq_overrun_en(r_irq_overrun_en),
    .o_fifo_pop(reg_fifo_pop),
    .irq_sample(irq_sample_int), .irq_overrun(irq_overrun_int)
  );

  adc_sampling_scheduler #(
    .CLK_FREQ_HZ(CLK_FREQ_HZ),
    .SAMPLE_RATE_HZ(SAMPLE_RATE_HZ)
  ) u_sched (
    .clk(aclk), .rst_n(aresetn),
    .i_enable(r_enable), .i_acq_done(acq_done),
    .o_periodic_req(periodic_req)
  );

  adc_sample_acquisition #(.ADC_RESOLUTION(ADC_RESOLUTION)) u_acq (
    .clk(aclk), .rst_n(aresetn),
    .i_start(acq_start_pulse),
    .o_busy(acq_busy), .o_done(acq_done), .o_sample(acq_sample),
    .sample_in(sample_in), .sample_valid(sample_valid)
  );

  generate
    if (ENABLE_FIFO) begin : g_fifo
      adc_fifo #(.DATA_WIDTH(ADC_RESOLUTION), .DEPTH(FIFO_DEPTH)) u_fifo (
        .clk(aclk), .rst_n(aresetn),
        .wr_en(fifo_wr_en), .wr_data(fifo_wr_data),
        .rd_en(fifo_rd_en), .rd_data(fifo_rd_data),
        .clr(1'b0), .empty(fifo_empty), .full(fifo_full),
        .overflow()
      );
    end else begin : g_no_fifo
      assign fifo_empty = 1'b1;
      assign fifo_full  = 1'b0;
      assign fifo_rd_data = '0;
    end
  endgenerate
endmodule
`default_nettype wire
