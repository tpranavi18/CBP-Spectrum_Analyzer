// ============================================================================
// File: veerall_top.sv
// Project: CBP-Spectrum_Analyzer
//
// Description:
//   Overall Combined SoC Top Module.
//   Integrates:
//     DUT 1: RISC-V Processor Subsystem
//            - VeeR EL2 Core Wrapper (veer_wrapper)
//            - IFU 64-bit to 32-bit AXI4 Adapter (axi_64to32_adapter)
//            - LSU 64-bit to 32-bit AXI4 Adapter (axi_64to32_adapter)
//     DUT 2: AXI+IP Peripheral Subsystem (veerall_axi_ips_top)
//            - 3x18 AXI4 Shared Interconnect
//            - IMEM (64 KB) & DMEM (64 KB)
//            - Peripherals: UART, GPIO, Timer, FIR, ADC, FFT Control & Memory
//            - Dummy Slaves (DECERR Responders for Reserved Spaces)
//     Interconnect Bus Mapping:
//            - S00: CPU IFU Master
//            - S01: CPU LSU Master
//            - S02: Top-level Testbench / Verification Master BFM
//     Interrupt Routing:
//            - extintsrc_req[1] : UART IRQ
//            - extintsrc_req[2] : GPIO IRQ
//            - extintsrc_req[3] : Timer IRQ
//            - extintsrc_req[4] : ADC Sample IRQ
//            - extintsrc_req[5] : ADC Overrun IRQ
//            - extintsrc_req[8:6]: Tied to 3'b000
// ============================================================================

`timescale 1ns/1ps
`default_nettype none

`include "common_defines.vh"

module veerall_top #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter STRB_WIDTH = 4,
    parameter ID_WIDTH   = 8
)(
    input  wire                     clk,
    input  wire                     rst_n,      // Active-low system reset

    // ========================================================================
    // Physical External I/O Interfaces
    // ========================================================================
    // UART
    input  wire                     uart_rx_i,
    output wire                     uart_tx_o,

    // GPIO bidirectional pins
    inout  wire [31:0]              gpio_io,

    // Timer external pins
    input  wire                     timer_ext_meas_i,
    input  wire                     timer_capture_i,
    output wire                     timer_pwm_o,
    output wire                     timer_trigger_o,

    // ADC external sample interface
    input  wire [11:0]              adc_sample_in,
    input  wire                     adc_sample_valid,

    // FIR streaming interface (for sample delivery & external filtering)
    input  wire                     fir_s_axis_tvalid,
    output wire                     fir_s_axis_tready,
    input  wire [15:0]              fir_s_axis_tdata,
    output wire                     fir_m_axis_tvalid,
    input  wire                     fir_m_axis_tready,
    output wire [39:0]              fir_m_axis_tdata,

    // External interrupt outputs (for visibility and testbench monitoring)
    output wire                     uart_irq,
    output wire                     gpio_irq,
    output wire                     timer_irq,
    output wire                     adc_irq_sample,
    output wire                     adc_irq_overrun,

    // ========================================================================
    // Verification / Testbench Master AXI Port (Interconnect S02)
    // Allows direct testbench transactions to verify all peripherals & memories
    // ========================================================================
    input  wire [ID_WIDTH-1:0]      tb_axi_awid,
    input  wire [ADDR_WIDTH-1:0]    tb_axi_awaddr,
    input  wire [7:0]               tb_axi_awlen,
    input  wire [2:0]               tb_axi_awsize,
    input  wire [1:0]               tb_axi_awburst,
    input  wire                     tb_axi_awlock,
    input  wire [3:0]               tb_axi_awcache,
    input  wire [2:0]               tb_axi_awprot,
    input  wire [3:0]               tb_axi_awqos,
    input  wire [3:0]               tb_axi_awregion,
    input  wire                     tb_axi_awvalid,
    output wire                     tb_axi_awready,

    input  wire [DATA_WIDTH-1:0]    tb_axi_wdata,
    input  wire [STRB_WIDTH-1:0]    tb_axi_wstrb,
    input  wire                     tb_axi_wlast,
    input  wire                     tb_axi_wvalid,
    output wire                     tb_axi_wready,

    output wire [ID_WIDTH-1:0]      tb_axi_bid,
    output wire [1:0]               tb_axi_bresp,
    output wire                     tb_axi_bvalid,
    input  wire                     tb_axi_bready,

    input  wire [ID_WIDTH-1:0]      tb_axi_arid,
    input  wire [ADDR_WIDTH-1:0]    tb_axi_araddr,
    input  wire [7:0]               tb_axi_arlen,
    input  wire [2:0]               tb_axi_arsize,
    input  wire [1:0]               tb_axi_arburst,
    input  wire                     tb_axi_arlock,
    input  wire [3:0]               tb_axi_arcache,
    input  wire [2:0]               tb_axi_arprot,
    input  wire [3:0]               tb_axi_arqos,
    input  wire [3:0]               tb_axi_arregion,
    input  wire                     tb_axi_arvalid,
    output wire                     tb_axi_arready,

    output wire [ID_WIDTH-1:0]      tb_axi_rid,
    output wire [DATA_WIDTH-1:0]    tb_axi_rdata,
    output wire [1:0]               tb_axi_rresp,
    output wire                     tb_axi_rlast,
    output wire                     tb_axi_rvalid,
    input  wire                     tb_axi_rready
);

    // Reset synchronization
    wire rst   = ~rst_n;
    wire rst_l = rst_n;

    // ========================================================================
    // 64-bit AXI Interfaces between VeeR Core and Adapters
    // ========================================================================
    wire        ifu64_awvalid, ifu64_awready, ifu64_wvalid, ifu64_wready;
    wire [2:0]  ifu64_awid;   wire [31:0] ifu64_awaddr;
    wire [7:0]  ifu64_awlen;  wire [2:0]  ifu64_awsize;  wire [1:0] ifu64_awburst;
    wire        ifu64_awlock; wire [3:0]  ifu64_awcache; wire [2:0] ifu64_awprot;
    wire [3:0]  ifu64_awqos;  wire [3:0]  ifu64_awregion;
    wire [63:0] ifu64_wdata;  wire [7:0]  ifu64_wstrb;   wire ifu64_wlast;
    wire        ifu64_bvalid, ifu64_bready; wire [1:0] ifu64_bresp; wire [2:0] ifu64_bid;
    wire        ifu64_arvalid, ifu64_arready;
    wire [2:0]  ifu64_arid;   wire [31:0] ifu64_araddr;
    wire [7:0]  ifu64_arlen;  wire [2:0]  ifu64_arsize;  wire [1:0] ifu64_arburst;
    wire        ifu64_arlock; wire [3:0]  ifu64_arcache; wire [2:0] ifu64_arprot;
    wire [3:0]  ifu64_arqos;  wire [3:0]  ifu64_arregion;
    wire        ifu64_rvalid, ifu64_rready; wire [2:0] ifu64_rid;
    wire [63:0] ifu64_rdata;  wire [1:0]  ifu64_rresp;   wire ifu64_rlast;

    wire        lsu64_awvalid, lsu64_awready, lsu64_wvalid, lsu64_wready;
    wire [2:0]  lsu64_awid;   wire [31:0] lsu64_awaddr;
    wire [7:0]  lsu64_awlen;  wire [2:0]  lsu64_awsize;  wire [1:0] lsu64_awburst;
    wire        lsu64_awlock; wire [3:0]  lsu64_awcache; wire [2:0] lsu64_awprot;
    wire [3:0]  lsu64_awqos;  wire [3:0]  lsu64_awregion;
    wire [63:0] lsu64_wdata;  wire [7:0]  lsu64_wstrb;   wire lsu64_wlast;
    wire        lsu64_bvalid, lsu64_bready; wire [1:0] lsu64_bresp; wire [2:0] lsu64_bid;
    wire        lsu64_arvalid, lsu64_arready;
    wire [2:0]  lsu64_arid;   wire [31:0] lsu64_araddr;
    wire [7:0]  lsu64_arlen;  wire [2:0]  lsu64_arsize;  wire [1:0] lsu64_arburst;
    wire        lsu64_arlock; wire [3:0]  lsu64_arcache; wire [2:0] lsu64_arprot;
    wire [3:0]  lsu64_arqos;  wire [3:0]  lsu64_arregion;
    wire        lsu64_rvalid, lsu64_rready; wire [2:0] lsu64_rid;
    wire [63:0] lsu64_rdata;  wire [1:0]  lsu64_rresp;   wire lsu64_rlast;

    // ========================================================================
    // 32-bit AXI Interfaces between Adapters and Interconnect (S00 & S01)
    // ========================================================================
    wire [ID_WIDTH-1:0]   s00_axi_awid;
    wire [ADDR_WIDTH-1:0] s00_axi_awaddr;
    wire [7:0]            s00_axi_awlen;
    wire [2:0]            s00_axi_awsize;
    wire [1:0]            s00_axi_awburst;
    wire                  s00_axi_awlock;
    wire [3:0]            s00_axi_awcache;
    wire [2:0]            s00_axi_awprot;
    wire [3:0]            s00_axi_awqos;
    wire [3:0]            s00_axi_awregion;
    wire                  s00_axi_awvalid;
    wire                  s00_axi_awready;
    wire [DATA_WIDTH-1:0] s00_axi_wdata;
    wire [STRB_WIDTH-1:0] s00_axi_wstrb;
    wire                  s00_axi_wlast;
    wire                  s00_axi_wvalid;
    wire                  s00_axi_wready;
    wire [ID_WIDTH-1:0]   s00_axi_bid;
    wire [1:0]            s00_axi_bresp;
    wire                  s00_axi_bvalid;
    wire                  s00_axi_bready;
    wire [ID_WIDTH-1:0]   s00_axi_arid;
    wire [ADDR_WIDTH-1:0] s00_axi_araddr;
    wire [7:0]            s00_axi_arlen;
    wire [2:0]            s00_axi_arsize;
    wire [1:0]            s00_axi_arburst;
    wire                  s00_axi_arlock;
    wire [3:0]            s00_axi_arcache;
    wire [2:0]            s00_axi_arprot;
    wire [3:0]            s00_axi_arqos;
    wire [3:0]            s00_axi_arregion;
    wire                  s00_axi_arvalid;
    wire                  s00_axi_arready;
    wire [ID_WIDTH-1:0]   s00_axi_rid;
    wire [DATA_WIDTH-1:0] s00_axi_rdata;
    wire [1:0]            s00_axi_rresp;
    wire                  s00_axi_rlast;
    wire                  s00_axi_rvalid;
    wire                  s00_axi_rready;

    wire [ID_WIDTH-1:0]   s01_axi_awid;
    wire [ADDR_WIDTH-1:0] s01_axi_awaddr;
    wire [7:0]            s01_axi_awlen;
    wire [2:0]            s01_axi_awsize;
    wire [1:0]            s01_axi_awburst;
    wire                  s01_axi_awlock;
    wire [3:0]            s01_axi_awcache;
    wire [2:0]            s01_axi_awprot;
    wire [3:0]            s01_axi_awqos;
    wire [3:0]            s01_axi_awregion;
    wire                  s01_axi_awvalid;
    wire                  s01_axi_awready;
    wire [DATA_WIDTH-1:0] s01_axi_wdata;
    wire [STRB_WIDTH-1:0] s01_axi_wstrb;
    wire                  s01_axi_wlast;
    wire                  s01_axi_wvalid;
    wire                  s01_axi_wready;
    wire [ID_WIDTH-1:0]   s01_axi_bid;
    wire [1:0]            s01_axi_bresp;
    wire                  s01_axi_bvalid;
    wire                  s01_axi_bready;
    wire [ID_WIDTH-1:0]   s01_axi_arid;
    wire [ADDR_WIDTH-1:0] s01_axi_araddr;
    wire [7:0]            s01_axi_arlen;
    wire [2:0]            s01_axi_arsize;
    wire [1:0]            s01_axi_arburst;
    wire                  s01_axi_arlock;
    wire [3:0]            s01_axi_arcache;
    wire [2:0]            s01_axi_arprot;
    wire [3:0]            s01_axi_arqos;
    wire [3:0]            s01_axi_arregion;
    wire                  s01_axi_arvalid;
    wire                  s01_axi_arready;
    wire [ID_WIDTH-1:0]   s01_axi_rid;
    wire [DATA_WIDTH-1:0] s01_axi_rdata;
    wire [1:0]            s01_axi_rresp;
    wire                  s01_axi_rlast;
    wire                  s01_axi_rvalid;
    wire                  s01_axi_rready;

    // ========================================================================
    // DUT 1: RISC-V Processor Subsystem
    // ========================================================================
    veer_wrapper u_cpu_core (
        .clk             (clk),
        .rst_l           (rst_l),

        // IFU 64-bit
        .ifu_axi_awvalid (ifu64_awvalid),
        .ifu_axi_awready (ifu64_awready),
        .ifu_axi_awid    (ifu64_awid),
        .ifu_axi_awaddr  (ifu64_awaddr),
        .ifu_axi_awregion(ifu64_awregion),
        .ifu_axi_awlen   (ifu64_awlen),
        .ifu_axi_awsize  (ifu64_awsize),
        .ifu_axi_awburst (ifu64_awburst),
        .ifu_axi_awlock  (ifu64_awlock),
        .ifu_axi_awcache (ifu64_awcache),
        .ifu_axi_awprot  (ifu64_awprot),
        .ifu_axi_awqos   (ifu64_awqos),
        .ifu_axi_wvalid  (ifu64_wvalid),
        .ifu_axi_wready  (ifu64_wready),
        .ifu_axi_wdata   (ifu64_wdata),
        .ifu_axi_wstrb   (ifu64_wstrb),
        .ifu_axi_wlast   (ifu64_wlast),
        .ifu_axi_bvalid  (ifu64_bvalid),
        .ifu_axi_bready  (ifu64_bready),
        .ifu_axi_bresp   (ifu64_bresp),
        .ifu_axi_bid     (ifu64_bid),
        .ifu_axi_arvalid (ifu64_arvalid),
        .ifu_axi_arready (ifu64_arready),
        .ifu_axi_arid    (ifu64_arid),
        .ifu_axi_araddr  (ifu64_araddr),
        .ifu_axi_arregion(ifu64_arregion),
        .ifu_axi_arlen   (ifu64_arlen),
        .ifu_axi_arsize  (ifu64_arsize),
        .ifu_axi_arburst (ifu64_arburst),
        .ifu_axi_arlock  (ifu64_arlock),
        .ifu_axi_arcache (ifu64_arcache),
        .ifu_axi_arprot  (ifu64_arprot),
        .ifu_axi_arqos   (ifu64_arqos),
        .ifu_axi_rvalid  (ifu64_rvalid),
        .ifu_axi_rready  (ifu64_rready),
        .ifu_axi_rid     (ifu64_rid),
        .ifu_axi_rdata   (ifu64_rdata),
        .ifu_axi_rresp   (ifu64_rresp),
        .ifu_axi_rlast   (ifu64_rlast),

        // LSU 64-bit
        .lsu_axi_awvalid (lsu64_awvalid),
        .lsu_axi_awready (lsu64_awready),
        .lsu_axi_awid    (lsu64_awid),
        .lsu_axi_awaddr  (lsu64_awaddr),
        .lsu_axi_awregion(lsu64_awregion),
        .lsu_axi_awlen   (lsu64_awlen),
        .lsu_axi_awsize  (lsu64_awsize),
        .lsu_axi_awburst (lsu64_awburst),
        .lsu_axi_awlock  (lsu64_awlock),
        .lsu_axi_awcache (lsu64_awcache),
        .lsu_axi_awprot  (lsu64_awprot),
        .lsu_axi_awqos   (lsu64_awqos),
        .lsu_axi_wvalid  (lsu64_wvalid),
        .lsu_axi_wready  (lsu64_wready),
        .lsu_axi_wdata   (lsu64_wdata),
        .lsu_axi_wstrb   (lsu64_wstrb),
        .lsu_axi_wlast   (lsu64_wlast),
        .lsu_axi_bvalid  (lsu64_bvalid),
        .lsu_axi_bready  (lsu64_bready),
        .lsu_axi_bresp   (lsu64_bresp),
        .lsu_axi_bid     (lsu64_bid),
        .lsu_axi_arvalid (lsu64_arvalid),
        .lsu_axi_arready (lsu64_arready),
        .lsu_axi_arid    (lsu64_arid),
        .lsu_axi_araddr  (lsu64_araddr),
        .lsu_axi_arregion(lsu64_arregion),
        .lsu_axi_arlen   (lsu64_arlen),
        .lsu_axi_arsize  (lsu64_arsize),
        .lsu_axi_arburst (lsu64_arburst),
        .lsu_axi_arlock  (lsu64_arlock),
        .lsu_axi_arcache (lsu64_arcache),
        .lsu_axi_arprot  (lsu64_arprot),
        .lsu_axi_arqos   (lsu64_arqos),
        .lsu_axi_rvalid  (lsu64_rvalid),
        .lsu_axi_rready  (lsu64_rready),
        .lsu_axi_rid     (lsu64_rid),
        .lsu_axi_rdata   (lsu64_rdata),
        .lsu_axi_rresp   (lsu64_rresp),
        .lsu_axi_rlast   (lsu64_rlast),

        // Interrupts
        .timer_int       (1'b0),
        .soft_int        (1'b0),
        .extintsrc_req   ({3'b000, adc_irq_overrun, adc_irq_sample, timer_irq, gpio_irq, uart_irq})
    );

    // IFU 64-bit -> 32-bit Adapter
    axi_64to32_adapter #(
        .M_ID_WIDTH (3),
        .S_ID_WIDTH (ID_WIDTH)
    ) u_ifu_adapter (
        .clk            (clk),
        .rst_l          (rst_l),

        // 64-bit slave
        .m_axi_awvalid  (ifu64_awvalid),
        .m_axi_awready  (ifu64_awready),
        .m_axi_awid     (ifu64_awid),
        .m_axi_awaddr   (ifu64_awaddr),
        .m_axi_awlen    (ifu64_awlen),
        .m_axi_awsize   (ifu64_awsize),
        .m_axi_awburst  (ifu64_awburst),
        .m_axi_awlock   (ifu64_awlock),
        .m_axi_awcache  (ifu64_awcache),
        .m_axi_awprot   (ifu64_awprot),
        .m_axi_awqos    (ifu64_awqos),
        .m_axi_awregion (ifu64_awregion),
        .m_axi_wvalid   (ifu64_wvalid),
        .m_axi_wready   (ifu64_wready),
        .m_axi_wdata    (ifu64_wdata),
        .m_axi_wstrb    (ifu64_wstrb),
        .m_axi_wlast    (ifu64_wlast),
        .m_axi_bvalid   (ifu64_bvalid),
        .m_axi_bready   (ifu64_bready),
        .m_axi_bid      (ifu64_bid),
        .m_axi_bresp    (ifu64_bresp),
        .m_axi_arvalid  (ifu64_arvalid),
        .m_axi_arready  (ifu64_arready),
        .m_axi_arid     (ifu64_arid),
        .m_axi_araddr   (ifu64_araddr),
        .m_axi_arlen    (ifu64_arlen),
        .m_axi_arsize   (ifu64_arsize),
        .m_axi_arburst  (ifu64_arburst),
        .m_axi_arlock   (ifu64_arlock),
        .m_axi_arcache  (ifu64_arcache),
        .m_axi_arprot   (ifu64_arprot),
        .m_axi_arqos    (ifu64_arqos),
        .m_axi_arregion (ifu64_arregion),
        .m_axi_rvalid   (ifu64_rvalid),
        .m_axi_rready   (ifu64_rready),
        .m_axi_rid      (ifu64_rid),
        .m_axi_rdata    (ifu64_rdata),
        .m_axi_rresp    (ifu64_rresp),
        .m_axi_rlast    (ifu64_rlast),

        // 32-bit master -> Interconnect S00
        .s_axi_awvalid  (s00_axi_awvalid),
        .s_axi_awready  (s00_axi_awready),
        .s_axi_awid     (s00_axi_awid),
        .s_axi_awaddr   (s00_axi_awaddr),
        .s_axi_awlen    (s00_axi_awlen),
        .s_axi_awsize   (s00_axi_awsize),
        .s_axi_awburst  (s00_axi_awburst),
        .s_axi_awlock   (s00_axi_awlock),
        .s_axi_awcache  (s00_axi_awcache),
        .s_axi_awprot   (s00_axi_awprot),
        .s_axi_awqos    (s00_axi_awqos),
        .s_axi_awregion (s00_axi_awregion),
        .s_axi_wvalid   (s00_axi_wvalid),
        .s_axi_wready   (s00_axi_wready),
        .s_axi_wdata    (s00_axi_wdata),
        .s_axi_wstrb    (s00_axi_wstrb),
        .s_axi_wlast    (s00_axi_wlast),
        .s_axi_bvalid   (s00_axi_bvalid),
        .s_axi_bready   (s00_axi_bready),
        .s_axi_bid      (s00_axi_bid),
        .s_axi_bresp    (s00_axi_bresp),
        .s_axi_arvalid  (s00_axi_arvalid),
        .s_axi_arready  (s00_axi_arready),
        .s_axi_arid     (s00_axi_arid),
        .s_axi_araddr   (s00_axi_araddr),
        .s_axi_arlen    (s00_axi_arlen),
        .s_axi_arsize   (s00_axi_arsize),
        .s_axi_arburst  (s00_axi_arburst),
        .s_axi_arlock   (s00_axi_arlock),
        .s_axi_arcache  (s00_axi_arcache),
        .s_axi_arprot   (s00_axi_arprot),
        .s_axi_arqos    (s00_axi_arqos),
        .s_axi_arregion (s00_axi_arregion),
        .s_axi_rvalid   (s00_axi_rvalid),
        .s_axi_rready   (s00_axi_rready),
        .s_axi_rid      (s00_axi_rid),
        .s_axi_rdata    (s00_axi_rdata),
        .s_axi_rresp    (s00_axi_rresp),
        .s_axi_rlast    (s00_axi_rlast)
    );

    // LSU 64-bit -> 32-bit Adapter
    axi_64to32_adapter #(
        .M_ID_WIDTH (3),
        .S_ID_WIDTH (ID_WIDTH)
    ) u_lsu_adapter (
        .clk            (clk),
        .rst_l          (rst_l),

        // 64-bit slave
        .m_axi_awvalid  (lsu64_awvalid),
        .m_axi_awready  (lsu64_awready),
        .m_axi_awid     (lsu64_awid),
        .m_axi_awaddr   (lsu64_awaddr),
        .m_axi_awlen    (lsu64_awlen),
        .m_axi_awsize   (lsu64_awsize),
        .m_axi_awburst  (lsu64_awburst),
        .m_axi_awlock   (lsu64_awlock),
        .m_axi_awcache  (lsu64_awcache),
        .m_axi_awprot   (lsu64_awprot),
        .m_axi_awqos    (lsu64_awqos),
        .m_axi_awregion (lsu64_awregion),
        .m_axi_wvalid   (lsu64_wvalid),
        .m_axi_wready   (lsu64_wready),
        .m_axi_wdata    (lsu64_wdata),
        .m_axi_wstrb    (lsu64_wstrb),
        .m_axi_wlast    (lsu64_wlast),
        .m_axi_bvalid   (lsu64_bvalid),
        .m_axi_bready   (lsu64_bready),
        .m_axi_bid      (lsu64_bid),
        .m_axi_bresp    (lsu64_bresp),
        .m_axi_arvalid  (lsu64_arvalid),
        .m_axi_arready  (lsu64_arready),
        .m_axi_arid     (lsu64_arid),
        .m_axi_araddr   (lsu64_araddr),
        .m_axi_arlen    (lsu64_arlen),
        .m_axi_arsize   (lsu64_arsize),
        .m_axi_arburst  (lsu64_arburst),
        .m_axi_arlock   (lsu64_arlock),
        .m_axi_arcache  (lsu64_arcache),
        .m_axi_arprot   (lsu64_arprot),
        .m_axi_arqos    (lsu64_arqos),
        .m_axi_arregion (lsu64_arregion),
        .m_axi_rvalid   (lsu64_rvalid),
        .m_axi_rready   (lsu64_rready),
        .m_axi_rid      (lsu64_rid),
        .m_axi_rdata    (lsu64_rdata),
        .m_axi_rresp    (lsu64_rresp),
        .m_axi_rlast    (lsu64_rlast),

        // 32-bit master -> Interconnect S01
        .s_axi_awvalid  (s01_axi_awvalid),
        .s_axi_awready  (s01_axi_awready),
        .s_axi_awid     (s01_axi_awid),
        .s_axi_awaddr   (s01_axi_awaddr),
        .s_axi_awlen    (s01_axi_awlen),
        .s_axi_awsize   (s01_axi_awsize),
        .s_axi_awburst  (s01_axi_awburst),
        .s_axi_awlock   (s01_axi_awlock),
        .s_axi_awcache  (s01_axi_awcache),
        .s_axi_awprot   (s01_axi_awprot),
        .s_axi_awqos    (s01_axi_awqos),
        .s_axi_awregion (s01_axi_awregion),
        .s_axi_wvalid   (s01_axi_wvalid),
        .s_axi_wready   (s01_axi_wready),
        .s_axi_wdata    (s01_axi_wdata),
        .s_axi_wstrb    (s01_axi_wstrb),
        .s_axi_wlast    (s01_axi_wlast),
        .s_axi_bvalid   (s01_axi_bvalid),
        .s_axi_bready   (s01_axi_bready),
        .s_axi_bid      (s01_axi_bid),
        .s_axi_bresp    (s01_axi_bresp),
        .s_axi_arvalid  (s01_axi_arvalid),
        .s_axi_arready  (s01_axi_arready),
        .s_axi_arid     (s01_axi_arid),
        .s_axi_araddr   (s01_axi_araddr),
        .s_axi_arlen    (s01_axi_arlen),
        .s_axi_arsize   (s01_axi_arsize),
        .s_axi_arburst  (s01_axi_arburst),
        .s_axi_arlock   (s01_axi_arlock),
        .s_axi_arcache  (s01_axi_arcache),
        .s_axi_arprot   (s01_axi_arprot),
        .s_axi_arqos    (s01_axi_arqos),
        .s_axi_arregion (s01_axi_arregion),
        .s_axi_rvalid   (s01_axi_rvalid),
        .s_axi_rready   (s01_axi_rready),
        .s_axi_rid      (s01_axi_rid),
        .s_axi_rdata    (s01_axi_rdata),
        .s_axi_rresp    (s01_axi_rresp),
        .s_axi_rlast    (s01_axi_rlast)
    );

    // ========================================================================
    // DUT 2: AXI+IP Peripheral Subsystem
    // ========================================================================
    veerall_axi_ips_top #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH),
        .STRB_WIDTH (STRB_WIDTH),
        .ID_WIDTH   (ID_WIDTH)
    ) u_periph_subsys (
        .clk              (clk),
        .rst              (rst),

        // S00 from CPU IFU
        .s00_axi_awid     (s00_axi_awid),
        .s00_axi_awaddr   (s00_axi_awaddr),
        .s00_axi_awlen    (s00_axi_awlen),
        .s00_axi_awsize   (s00_axi_awsize),
        .s00_axi_awburst  (s00_axi_awburst),
        .s00_axi_awlock   (s00_axi_awlock),
        .s00_axi_awcache  (s00_axi_awcache),
        .s00_axi_awprot   (s00_axi_awprot),
        .s00_axi_awqos    (s00_axi_awqos),
        .s00_axi_awregion (s00_axi_awregion),
        .s00_axi_awvalid  (s00_axi_awvalid),
        .s00_axi_awready  (s00_axi_awready),
        .s00_axi_wdata    (s00_axi_wdata),
        .s00_axi_wstrb    (s00_axi_wstrb),
        .s00_axi_wlast    (s00_axi_wlast),
        .s00_axi_wvalid   (s00_axi_wvalid),
        .s00_axi_wready   (s00_axi_wready),
        .s00_axi_bid      (s00_axi_bid),
        .s00_axi_bresp    (s00_axi_bresp),
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
        .s00_axi_arregion (s00_axi_arregion),
        .s00_axi_arvalid  (s00_axi_arvalid),
        .s00_axi_arready  (s00_axi_arready),
        .s00_axi_rid      (s00_axi_rid),
        .s00_axi_rdata    (s00_axi_rdata),
        .s00_axi_rresp    (s00_axi_rresp),
        .s00_axi_rlast    (s00_axi_rlast),
        .s00_axi_rvalid   (s00_axi_rvalid),
        .s00_axi_rready   (s00_axi_rready),

        // S01 from CPU LSU
        .s01_axi_awid     (s01_axi_awid),
        .s01_axi_awaddr   (s01_axi_awaddr),
        .s01_axi_awlen    (s01_axi_awlen),
        .s01_axi_awsize   (s01_axi_awsize),
        .s01_axi_awburst  (s01_axi_awburst),
        .s01_axi_awlock   (s01_axi_awlock),
        .s01_axi_awcache  (s01_axi_awcache),
        .s01_axi_awprot   (s01_axi_awprot),
        .s01_axi_awqos    (s01_axi_awqos),
        .s01_axi_awregion (s01_axi_awregion),
        .s01_axi_awvalid  (s01_axi_awvalid),
        .s01_axi_awready  (s01_axi_awready),
        .s01_axi_wdata    (s01_axi_wdata),
        .s01_axi_wstrb    (s01_axi_wstrb),
        .s01_axi_wlast    (s01_axi_wlast),
        .s01_axi_wvalid   (s01_axi_wvalid),
        .s01_axi_wready   (s01_axi_wready),
        .s01_axi_bid      (s01_axi_bid),
        .s01_axi_bresp    (s01_axi_bresp),
        .s01_axi_bvalid   (s01_axi_bvalid),
        .s01_axi_bready   (s01_axi_bready),
        .s01_axi_arid     (s01_axi_arid),
        .s01_axi_araddr   (s01_axi_araddr),
        .s01_axi_arlen    (s01_axi_arlen),
        .s01_axi_arsize   (s01_axi_arsize),
        .s01_axi_arburst  (s01_axi_arburst),
        .s01_axi_arlock   (s01_axi_arlock),
        .s01_axi_arcache  (s01_axi_arcache),
        .s01_axi_arprot   (s01_axi_arprot),
        .s01_axi_arqos    (s01_axi_arqos),
        .s01_axi_arregion (s01_axi_arregion),
        .s01_axi_arvalid  (s01_axi_arvalid),
        .s01_axi_arready  (s01_axi_arready),
        .s01_axi_rid      (s01_axi_rid),
        .s01_axi_rdata    (s01_axi_rdata),
        .s01_axi_rresp    (s01_axi_rresp),
        .s01_axi_rlast    (s01_axi_rlast),
        .s01_axi_rvalid   (s01_axi_rvalid),
        .s01_axi_rready   (s01_axi_rready),

        // S02 from Top-Level Testbench
        .s02_axi_awid     (tb_axi_awid),
        .s02_axi_awaddr   (tb_axi_awaddr),
        .s02_axi_awlen    (tb_axi_awlen),
        .s02_axi_awsize   (tb_axi_awsize),
        .s02_axi_awburst  (tb_axi_awburst),
        .s02_axi_awlock   (tb_axi_awlock),
        .s02_axi_awcache  (tb_axi_awcache),
        .s02_axi_awprot   (tb_axi_awprot),
        .s02_axi_awqos    (tb_axi_awqos),
        .s02_axi_awregion (tb_axi_awregion),
        .s02_axi_awvalid  (tb_axi_awvalid),
        .s02_axi_awready  (tb_axi_awready),
        .s02_axi_wdata    (tb_axi_wdata),
        .s02_axi_wstrb    (tb_axi_wstrb),
        .s02_axi_wlast    (tb_axi_wlast),
        .s02_axi_wvalid   (tb_axi_wvalid),
        .s02_axi_wready   (tb_axi_wready),
        .s02_axi_bid      (tb_axi_bid),
        .s02_axi_bresp    (tb_axi_bresp),
        .s02_axi_bvalid   (tb_axi_bvalid),
        .s02_axi_bready   (tb_axi_bready),
        .s02_axi_arid     (tb_axi_arid),
        .s02_axi_araddr   (tb_axi_araddr),
        .s02_axi_arlen    (tb_axi_arlen),
        .s02_axi_arsize   (tb_axi_arsize),
        .s02_axi_arburst  (tb_axi_arburst),
        .s02_axi_arlock   (tb_axi_arlock),
        .s02_axi_arcache  (tb_axi_arcache),
        .s02_axi_arprot   (tb_axi_arprot),
        .s02_axi_arqos    (tb_axi_arqos),
        .s02_axi_arregion (tb_axi_arregion),
        .s02_axi_arvalid  (tb_axi_arvalid),
        .s02_axi_arready  (tb_axi_arready),
        .s02_axi_rid      (tb_axi_rid),
        .s02_axi_rdata    (tb_axi_rdata),
        .s02_axi_rresp    (tb_axi_rresp),
        .s02_axi_rlast    (tb_axi_rlast),
        .s02_axi_rvalid   (tb_axi_rvalid),
        .s02_axi_rready   (tb_axi_rready),

        // Peripherals external I/O
        .uart_rx_i        (uart_rx_i),
        .uart_tx_o        (uart_tx_o),
        .gpio_io          (gpio_io),
        .timer_ext_meas_i (timer_ext_meas_i),
        .timer_capture_i  (timer_capture_i),
        .timer_pwm_o      (timer_pwm_o),
        .timer_trigger_o  (timer_trigger_o),
        .adc_sample_in    (adc_sample_in),
        .adc_sample_valid (adc_sample_valid),
        .fir_s_axis_tvalid(fir_s_axis_tvalid),
        .fir_s_axis_tready(fir_s_axis_tready),
        .fir_s_axis_tdata (fir_s_axis_tdata),
        .fir_m_axis_tvalid(fir_m_axis_tvalid),
        .fir_m_axis_tready(fir_m_axis_tready),
        .fir_m_axis_tdata (fir_m_axis_tdata),

        // Interrupts
        .uart_irq         (uart_irq),
        .gpio_irq         (gpio_irq),
        .timer_irq        (timer_irq),
        .adc_irq_sample   (adc_irq_sample),
        .adc_irq_overrun  (adc_irq_overrun)
    );

endmodule

`default_nettype wire
