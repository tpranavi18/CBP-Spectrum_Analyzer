// ============================================================================
// File: veerall_axi_ips_top.sv
// Project: CBP-Spectrum_Analyzer
//
// Description:
//   Updated AXI+IP Peripheral Subsystem Top Module.
//   Instantiates:
//     - 3-Master x 18-Slave AXI4 Interconnect (axi_interconnect_wrap_3x18)
//     - Real Spectrum Analyzer Peripherals:
//         M00: UART                 (0x4000_0000 - 0x4000_0FFF) 4 KB
//         M01: GPIO                 (0x4000_2000 - 0x4000_2FFF) 4 KB
//         M02: TIMER                (0x4000_4000 - 0x4000_4FFF) 4 KB
//         M03: FIR Filter           (0x4000_C000 - 0x4000_CFFF) 4 KB
//         M04: ADC Interface        (0x4000_E000 - 0x4000_EFFF) 4 KB
//         M05: FFT Control          (0x4000_8000 - 0x4000_8FFF) 4 KB
//         M06: FFT Memory Window    (0x4000_A000 - 0x4000_AFFF) 4 KB
//         M07: IMEM (64 KB)         (0x0000_0000 - 0x0000_FFFF) 64 KB
//         M08: DMEM (64 KB)         (0x0001_0000 - 0x0001_FFFF) 64 KB
//     - Dummy Slaves (DECERR Responders for Reserved / Proposed Regions):
//         M09: Watchdog             (0x4000_6000 - 0x4000_6FFF) 4 KB
//         M10: SPI                  (0x4001_0000 - 0x4001_0FFF) 4 KB
//         M11: QRS                  (0x4001_2000 - 0x4001_2FFF) 4 KB
//         M12: AES-128              (0x4001_4000 - 0x4001_4FFF) 4 KB
//         M13: Interrupt Aggregator (0x4001_6000 - 0x4001_6FFF) 4 KB
//         M14: PWM                  (0x4001_8000 - 0x4001_8FFF) 4 KB
//         M15: I2C                  (0x4001_A000 - 0x4001_AFFF) 4 KB
//         M16: DMA                  (0x4001_C000 - 0x4001_CFFF) 4 KB
//         M17: Reserved / Future    (0x4001_E000 - 0x4001_EFFF) 4 KB
//
//   Master Ports:
//     S00: VeeR IFU Master (via axi_64to32_adapter)
//     S01: VeeR LSU Master (via axi_64to32_adapter)
//     S02: Testbench Master BFM (Direct 32-bit AXI Access)
// ============================================================================

`timescale 1ns/1ps
`default_nettype none

module veerall_axi_ips_top #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter STRB_WIDTH = 4,
    parameter ID_WIDTH   = 8
)(
    input  wire                     clk,
    input  wire                     rst,

    // ========================================================================
    // S00 AXI Interface (CPU IFU via 64-to-32 adapter)
    // ========================================================================
    input  wire [ID_WIDTH-1:0]      s00_axi_awid,
    input  wire [ADDR_WIDTH-1:0]    s00_axi_awaddr,
    input  wire [7:0]               s00_axi_awlen,
    input  wire [2:0]               s00_axi_awsize,
    input  wire [1:0]               s00_axi_awburst,
    input  wire                     s00_axi_awlock,
    input  wire [3:0]               s00_axi_awcache,
    input  wire [2:0]               s00_axi_awprot,
    input  wire [3:0]               s00_axi_awqos,
    input  wire [3:0]               s00_axi_awregion,
    input  wire                     s00_axi_awvalid,
    output wire                     s00_axi_awready,

    input  wire [DATA_WIDTH-1:0]    s00_axi_wdata,
    input  wire [STRB_WIDTH-1:0]    s00_axi_wstrb,
    input  wire                     s00_axi_wlast,
    input  wire                     s00_axi_wvalid,
    output wire                     s00_axi_wready,

    output wire [ID_WIDTH-1:0]      s00_axi_bid,
    output wire [1:0]               s00_axi_bresp,
    output wire                     s00_axi_bvalid,
    input  wire                     s00_axi_bready,

    input  wire [ID_WIDTH-1:0]      s00_axi_arid,
    input  wire [ADDR_WIDTH-1:0]    s00_axi_araddr,
    input  wire [7:0]               s00_axi_arlen,
    input  wire [2:0]               s00_axi_arsize,
    input  wire [1:0]               s00_axi_arburst,
    input  wire                     s00_axi_arlock,
    input  wire [3:0]               s00_axi_arcache,
    input  wire [2:0]               s00_axi_arprot,
    input  wire [3:0]               s00_axi_arqos,
    input  wire [3:0]               s00_axi_arregion,
    input  wire                     s00_axi_arvalid,
    output wire                     s00_axi_arready,

    output wire [ID_WIDTH-1:0]      s00_axi_rid,
    output wire [DATA_WIDTH-1:0]    s00_axi_rdata,
    output wire [1:0]               s00_axi_rresp,
    output wire                     s00_axi_rlast,
    output wire                     s00_axi_rvalid,
    input  wire                     s00_axi_rready,

    // ========================================================================
    // S01 AXI Interface (CPU LSU via 64-to-32 adapter)
    // ========================================================================
    input  wire [ID_WIDTH-1:0]      s01_axi_awid,
    input  wire [ADDR_WIDTH-1:0]    s01_axi_awaddr,
    input  wire [7:0]               s01_axi_awlen,
    input  wire [2:0]               s01_axi_awsize,
    input  wire [1:0]               s01_axi_awburst,
    input  wire                     s01_axi_awlock,
    input  wire [3:0]               s01_axi_awcache,
    input  wire [2:0]               s01_axi_awprot,
    input  wire [3:0]               s01_axi_awqos,
    input  wire [3:0]               s01_axi_awregion,
    input  wire                     s01_axi_awvalid,
    output wire                     s01_axi_awready,

    input  wire [DATA_WIDTH-1:0]    s01_axi_wdata,
    input  wire [STRB_WIDTH-1:0]    s01_axi_wstrb,
    input  wire                     s01_axi_wlast,
    input  wire                     s01_axi_wvalid,
    output wire                     s01_axi_wready,

    output wire [ID_WIDTH-1:0]      s01_axi_bid,
    output wire [1:0]               s01_axi_bresp,
    output wire                     s01_axi_bvalid,
    input  wire                     s01_axi_bready,

    input  wire [ID_WIDTH-1:0]      s01_axi_arid,
    input  wire [ADDR_WIDTH-1:0]    s01_axi_araddr,
    input  wire [7:0]               s01_axi_arlen,
    input  wire [2:0]               s01_axi_arsize,
    input  wire [1:0]               s01_axi_arburst,
    input  wire                     s01_axi_arlock,
    input  wire [3:0]               s01_axi_arcache,
    input  wire [2:0]               s01_axi_arprot,
    input  wire [3:0]               s01_axi_arqos,
    input  wire [3:0]               s01_axi_arregion,
    input  wire                     s01_axi_arvalid,
    output wire                     s01_axi_arready,

    output wire [ID_WIDTH-1:0]      s01_axi_rid,
    output wire [DATA_WIDTH-1:0]    s01_axi_rdata,
    output wire [1:0]               s01_axi_rresp,
    output wire                     s01_axi_rlast,
    output wire                     s01_axi_rvalid,
    input  wire                     s01_axi_rready,

    // ========================================================================
    // S02 AXI Interface (Testbench Master BFM)
    // ========================================================================
    input  wire [ID_WIDTH-1:0]      s02_axi_awid,
    input  wire [ADDR_WIDTH-1:0]    s02_axi_awaddr,
    input  wire [7:0]               s02_axi_awlen,
    input  wire [2:0]               s02_axi_awsize,
    input  wire [1:0]               s02_axi_awburst,
    input  wire                     s02_axi_awlock,
    input  wire [3:0]               s02_axi_awcache,
    input  wire [2:0]               s02_axi_awprot,
    input  wire [3:0]               s02_axi_awqos,
    input  wire [3:0]               s02_axi_awregion,
    input  wire                     s02_axi_awvalid,
    output wire                     s02_axi_awready,

    input  wire [DATA_WIDTH-1:0]    s02_axi_wdata,
    input  wire [STRB_WIDTH-1:0]    s02_axi_wstrb,
    input  wire                     s02_axi_wlast,
    input  wire                     s02_axi_wvalid,
    output wire                     s02_axi_wready,

    output wire [ID_WIDTH-1:0]      s02_axi_bid,
    output wire [1:0]               s02_axi_bresp,
    output wire                     s02_axi_bvalid,
    input  wire                     s02_axi_bready,

    input  wire [ID_WIDTH-1:0]      s02_axi_arid,
    input  wire [ADDR_WIDTH-1:0]    s02_axi_araddr,
    input  wire [7:0]               s02_axi_arlen,
    input  wire [2:0]               s02_axi_arsize,
    input  wire [1:0]               s02_axi_arburst,
    input  wire                     s02_axi_arlock,
    input  wire [3:0]               s02_axi_arcache,
    input  wire [2:0]               s02_axi_arprot,
    input  wire [3:0]               s02_axi_arqos,
    input  wire [3:0]               s02_axi_arregion,
    input  wire                     s02_axi_arvalid,
    output wire                     s02_axi_arready,

    output wire [ID_WIDTH-1:0]      s02_axi_rid,
    output wire [DATA_WIDTH-1:0]    s02_axi_rdata,
    output wire [1:0]               s02_axi_rresp,
    output wire                     s02_axi_rlast,
    output wire                     s02_axi_rvalid,
    input  wire                     s02_axi_rready,

    // ========================================================================
    // Physical External I/O Signals
    // ========================================================================
    // UART
    input  wire                     uart_rx_i,
    output wire                     uart_tx_o,

    // GPIO
    inout  wire [31:0]              gpio_io,

    // Timer
    input  wire                     timer_ext_meas_i,
    input  wire                     timer_capture_i,
    output wire                     timer_pwm_o,
    output wire                     timer_trigger_o,

    // ADC external sample interface
    input  wire [11:0]              adc_sample_in,
    input  wire                     adc_sample_valid,

    // FIR streaming interface (for verification & external stream)
    input  wire                     fir_s_axis_tvalid,
    output wire                     fir_s_axis_tready,
    input  wire [15:0]              fir_s_axis_tdata,
    output wire                     fir_m_axis_tvalid,
    input  wire                     fir_m_axis_tready,
    output wire [39:0]              fir_m_axis_tdata,

    // Peripheral Interrupt Outputs (to CPU extintsrc_req & top level)
    output wire                     uart_irq,
    output wire                     gpio_irq,
    output wire                     timer_irq,
    output wire                     adc_irq_sample,
    output wire                     adc_irq_overrun
);

    // ========================================================================
    // Internal Master Wires (M00 to M17 from Interconnect)
    // ========================================================================
    `define DECLARE_AXI_M(idx) \
        wire [ID_WIDTH-1:0]   m``idx``_axi_awid; \
        wire [ADDR_WIDTH-1:0] m``idx``_axi_awaddr; \
        wire [7:0]            m``idx``_axi_awlen; \
        wire [2:0]            m``idx``_axi_awsize; \
        wire [1:0]            m``idx``_axi_awburst; \
        wire                  m``idx``_axi_awlock; \
        wire [3:0]            m``idx``_axi_awcache; \
        wire [2:0]            m``idx``_axi_awprot; \
        wire [3:0]            m``idx``_axi_awqos; \
        wire [3:0]            m``idx``_axi_awregion; \
        wire                  m``idx``_axi_awvalid; \
        wire                  m``idx``_axi_awready; \
        wire [DATA_WIDTH-1:0] m``idx``_axi_wdata; \
        wire [STRB_WIDTH-1:0] m``idx``_axi_wstrb; \
        wire                  m``idx``_axi_wlast; \
        wire                  m``idx``_axi_wvalid; \
        wire                  m``idx``_axi_wready; \
        wire [ID_WIDTH-1:0]   m``idx``_axi_bid; \
        wire [1:0]            m``idx``_axi_bresp; \
        wire                  m``idx``_axi_bvalid; \
        wire                  m``idx``_axi_bready; \
        wire [ID_WIDTH-1:0]   m``idx``_axi_arid; \
        wire [ADDR_WIDTH-1:0] m``idx``_axi_araddr; \
        wire [7:0]            m``idx``_axi_arlen; \
        wire [2:0]            m``idx``_axi_arsize; \
        wire [1:0]            m``idx``_axi_arburst; \
        wire                  m``idx``_axi_arlock; \
        wire [3:0]            m``idx``_axi_arcache; \
        wire [2:0]            m``idx``_axi_arprot; \
        wire [3:0]            m``idx``_axi_arqos; \
        wire [3:0]            m``idx``_axi_arregion; \
        wire                  m``idx``_axi_arvalid; \
        wire                  m``idx``_axi_arready; \
        wire [ID_WIDTH-1:0]   m``idx``_axi_rid; \
        wire [DATA_WIDTH-1:0] m``idx``_axi_rdata; \
        wire [1:0]            m``idx``_axi_rresp; \
        wire                  m``idx``_axi_rlast; \
        wire                  m``idx``_axi_rvalid; \
        wire                  m``idx``_axi_rready;

    `DECLARE_AXI_M(00)
    `DECLARE_AXI_M(01)
    `DECLARE_AXI_M(02)
    `DECLARE_AXI_M(03)
    `DECLARE_AXI_M(04)
    `DECLARE_AXI_M(05)
    `DECLARE_AXI_M(06)
    `DECLARE_AXI_M(07)
    `DECLARE_AXI_M(08)
    `DECLARE_AXI_M(09)
    `DECLARE_AXI_M(10)
    `DECLARE_AXI_M(11)
    `DECLARE_AXI_M(12)
    `DECLARE_AXI_M(13)
    `DECLARE_AXI_M(14)
    `DECLARE_AXI_M(15)
    `DECLARE_AXI_M(16)
    `DECLARE_AXI_M(17)

    `undef DECLARE_AXI_M

    // ========================================================================
    // 3x18 AXI Interconnect Instance
    // ========================================================================
    axi_interconnect_wrap_3x18 #(
        .DATA_WIDTH        (DATA_WIDTH),
        .ADDR_WIDTH        (ADDR_WIDTH),
        .STRB_WIDTH        (STRB_WIDTH),
        .ID_WIDTH          (ID_WIDTH),
        .M_REGIONS         (1),

        // M00 : UART (0x4000_0000)
        .M00_BASE_ADDR     (32'h4000_0000),
        .M00_ADDR_WIDTH    (32'd12),
        .M00_CONNECT_READ  (3'b111),
        .M00_CONNECT_WRITE (3'b111),

        // M01 : GPIO (0x4000_2000)
        .M01_BASE_ADDR     (32'h4000_2000),
        .M01_ADDR_WIDTH    (32'd12),
        .M01_CONNECT_READ  (3'b111),
        .M01_CONNECT_WRITE (3'b111),

        // M02 : TIMER (0x4000_4000)
        .M02_BASE_ADDR     (32'h4000_4000),
        .M02_ADDR_WIDTH    (32'd12),
        .M02_CONNECT_READ  (3'b111),
        .M02_CONNECT_WRITE (3'b111),

        // M03 : FIR Filter (0x4000_C000)
        .M03_BASE_ADDR     (32'h4000_C000),
        .M03_ADDR_WIDTH    (32'd12),
        .M03_CONNECT_READ  (3'b111),
        .M03_CONNECT_WRITE (3'b111),

        // M04 : ADC Controller (0x4000_E000)
        .M04_BASE_ADDR     (32'h4000_E000),
        .M04_ADDR_WIDTH    (32'd12),
        .M04_CONNECT_READ  (3'b111),
        .M04_CONNECT_WRITE (3'b111),

        // M05 : FFT Control (0x4000_8000)
        .M05_BASE_ADDR     (32'h4000_8000),
        .M05_ADDR_WIDTH    (32'd12),
        .M05_CONNECT_READ  (3'b111),
        .M05_CONNECT_WRITE (3'b111),

        // M06 : FFT Memory Window (0x4000_A000)
        .M06_BASE_ADDR     (32'h4000_A000),
        .M06_ADDR_WIDTH    (32'd12),
        .M06_CONNECT_READ  (3'b111),
        .M06_CONNECT_WRITE (3'b111),

        // M07 : IMEM (0x0000_0000 - 64 KB)
        .M07_BASE_ADDR     (32'h0000_0000),
        .M07_ADDR_WIDTH    (32'd16),
        .M07_CONNECT_READ  (3'b111),
        .M07_CONNECT_WRITE (3'b111),

        // M08 : DMEM (0x0001_0000 - 64 KB)
        .M08_BASE_ADDR     (32'h0001_0000),
        .M08_ADDR_WIDTH    (32'd16),
        .M08_CONNECT_READ  (3'b111),
        .M08_CONNECT_WRITE (3'b111),

        // M09 : Watchdog Dummy (0x4000_6000)
        .M09_BASE_ADDR     (32'h4000_6000),
        .M09_ADDR_WIDTH    (32'd12),
        .M09_CONNECT_READ  (3'b111),
        .M09_CONNECT_WRITE (3'b111),

        // M10 : SPI Dummy (0x4001_0000)
        .M10_BASE_ADDR     (32'h4001_0000),
        .M10_ADDR_WIDTH    (32'd12),
        .M10_CONNECT_READ  (3'b111),
        .M10_CONNECT_WRITE (3'b111),

        // M11 : QRS Dummy (0x4001_2000)
        .M11_BASE_ADDR     (32'h4001_2000),
        .M11_ADDR_WIDTH    (32'd12),
        .M11_CONNECT_READ  (3'b111),
        .M11_CONNECT_WRITE (3'b111),

        // M12 : AES Dummy (0x4001_4000)
        .M12_BASE_ADDR     (32'h4001_4000),
        .M12_ADDR_WIDTH    (32'd12),
        .M12_CONNECT_READ  (3'b111),
        .M12_CONNECT_WRITE (3'b111),

        // M13 : Interrupt Aggregator Dummy (0x4001_6000)
        .M13_BASE_ADDR     (32'h4001_6000),
        .M13_ADDR_WIDTH    (32'd12),
        .M13_CONNECT_READ  (3'b111),
        .M13_CONNECT_WRITE (3'b111),

        // M14 : PWM Dummy (0x4001_8000)
        .M14_BASE_ADDR     (32'h4001_8000),
        .M14_ADDR_WIDTH    (32'd12),
        .M14_CONNECT_READ  (3'b111),
        .M14_CONNECT_WRITE (3'b111),

        // M15 : I2C Dummy (0x4001_A000)
        .M15_BASE_ADDR     (32'h4001_A000),
        .M15_ADDR_WIDTH    (32'd12),
        .M15_CONNECT_READ  (3'b111),
        .M15_CONNECT_WRITE (3'b111),

        // M16 : DMA Dummy (0x4001_C000)
        .M16_BASE_ADDR     (32'h4001_C000),
        .M16_ADDR_WIDTH    (32'd12),
        .M16_CONNECT_READ  (3'b111),
        .M16_CONNECT_WRITE (3'b111),

        // M17 : Reserved / Future Dummy (0x4001_E000)
        .M17_BASE_ADDR     (32'h4001_E000),
        .M17_ADDR_WIDTH    (32'd12),
        .M17_CONNECT_READ  (3'b111),
        .M17_CONNECT_WRITE (3'b111)
    ) u_interconnect (
        .clk (clk),
        .rst (rst),

        // S00
        .s00_axi_awid(s00_axi_awid), .s00_axi_awaddr(s00_axi_awaddr),
        .s00_axi_awlen(s00_axi_awlen), .s00_axi_awsize(s00_axi_awsize),
        .s00_axi_awburst(s00_axi_awburst), .s00_axi_awlock(s00_axi_awlock),
        .s00_axi_awcache(s00_axi_awcache), .s00_axi_awprot(s00_axi_awprot),
        .s00_axi_awqos(s00_axi_awqos), .s00_axi_awuser(1'b0),
        .s00_axi_awvalid(s00_axi_awvalid), .s00_axi_awready(s00_axi_awready),
        .s00_axi_wdata(s00_axi_wdata), .s00_axi_wstrb(s00_axi_wstrb),
        .s00_axi_wlast(s00_axi_wlast), .s00_axi_wuser(1'b0),
        .s00_axi_wvalid(s00_axi_wvalid), .s00_axi_wready(s00_axi_wready),
        .s00_axi_bid(s00_axi_bid), .s00_axi_bresp(s00_axi_bresp),
        .s00_axi_buser(), .s00_axi_bvalid(s00_axi_bvalid),
        .s00_axi_bready(s00_axi_bready),
        .s00_axi_arid(s00_axi_arid), .s00_axi_araddr(s00_axi_araddr),
        .s00_axi_arlen(s00_axi_arlen), .s00_axi_arsize(s00_axi_arsize),
        .s00_axi_arburst(s00_axi_arburst), .s00_axi_arlock(s00_axi_arlock),
        .s00_axi_arcache(s00_axi_arcache), .s00_axi_arprot(s00_axi_arprot),
        .s00_axi_arqos(s00_axi_arqos), .s00_axi_aruser(1'b0),
        .s00_axi_arvalid(s00_axi_arvalid), .s00_axi_arready(s00_axi_arready),
        .s00_axi_rid(s00_axi_rid), .s00_axi_rdata(s00_axi_rdata),
        .s00_axi_rresp(s00_axi_rresp), .s00_axi_rlast(s00_axi_rlast),
        .s00_axi_ruser(), .s00_axi_rvalid(s00_axi_rvalid),
        .s00_axi_rready(s00_axi_rready),

        // S01
        .s01_axi_awid(s01_axi_awid), .s01_axi_awaddr(s01_axi_awaddr),
        .s01_axi_awlen(s01_axi_awlen), .s01_axi_awsize(s01_axi_awsize),
        .s01_axi_awburst(s01_axi_awburst), .s01_axi_awlock(s01_axi_awlock),
        .s01_axi_awcache(s01_axi_awcache), .s01_axi_awprot(s01_axi_awprot),
        .s01_axi_awqos(s01_axi_awqos), .s01_axi_awuser(1'b0),
        .s01_axi_awvalid(s01_axi_awvalid), .s01_axi_awready(s01_axi_awready),
        .s01_axi_wdata(s01_axi_wdata), .s01_axi_wstrb(s01_axi_wstrb),
        .s01_axi_wlast(s01_axi_wlast), .s01_axi_wuser(1'b0),
        .s01_axi_wvalid(s01_axi_wvalid), .s01_axi_wready(s01_axi_wready),
        .s01_axi_bid(s01_axi_bid), .s01_axi_bresp(s01_axi_bresp),
        .s01_axi_buser(), .s01_axi_bvalid(s01_axi_bvalid),
        .s01_axi_bready(s01_axi_bready),
        .s01_axi_arid(s01_axi_arid), .s01_axi_araddr(s01_axi_araddr),
        .s01_axi_arlen(s01_axi_arlen), .s01_axi_arsize(s01_axi_arsize),
        .s01_axi_arburst(s01_axi_arburst), .s01_axi_arlock(s01_axi_arlock),
        .s01_axi_arcache(s01_axi_arcache), .s01_axi_arprot(s01_axi_arprot),
        .s01_axi_arqos(s01_axi_arqos), .s01_axi_aruser(1'b0),
        .s01_axi_arvalid(s01_axi_arvalid), .s01_axi_arready(s01_axi_arready),
        .s01_axi_rid(s01_axi_rid), .s01_axi_rdata(s01_axi_rdata),
        .s01_axi_rresp(s01_axi_rresp), .s01_axi_rlast(s01_axi_rlast),
        .s01_axi_ruser(), .s01_axi_rvalid(s01_axi_rvalid),
        .s01_axi_rready(s01_axi_rready),

        // S02
        .s02_axi_awid(s02_axi_awid), .s02_axi_awaddr(s02_axi_awaddr),
        .s02_axi_awlen(s02_axi_awlen), .s02_axi_awsize(s02_axi_awsize),
        .s02_axi_awburst(s02_axi_awburst), .s02_axi_awlock(s02_axi_awlock),
        .s02_axi_awcache(s02_axi_awcache), .s02_axi_awprot(s02_axi_awprot),
        .s02_axi_awqos(s02_axi_awqos), .s02_axi_awuser(1'b0),
        .s02_axi_awvalid(s02_axi_awvalid), .s02_axi_awready(s02_axi_awready),
        .s02_axi_wdata(s02_axi_wdata), .s02_axi_wstrb(s02_axi_wstrb),
        .s02_axi_wlast(s02_axi_wlast), .s02_axi_wuser(1'b0),
        .s02_axi_wvalid(s02_axi_wvalid), .s02_axi_wready(s02_axi_wready),
        .s02_axi_bid(s02_axi_bid), .s02_axi_bresp(s02_axi_bresp),
        .s02_axi_buser(), .s02_axi_bvalid(s02_axi_bvalid),
        .s02_axi_bready(s02_axi_bready),
        .s02_axi_arid(s02_axi_arid), .s02_axi_araddr(s02_axi_araddr),
        .s02_axi_arlen(s02_axi_arlen), .s02_axi_arsize(s02_axi_arsize),
        .s02_axi_arburst(s02_axi_arburst), .s02_axi_arlock(s02_axi_arlock),
        .s02_axi_arcache(s02_axi_arcache), .s02_axi_arprot(s02_axi_arprot),
        .s02_axi_arqos(s02_axi_arqos), .s02_axi_aruser(1'b0),
        .s02_axi_arvalid(s02_axi_arvalid), .s02_axi_arready(s02_axi_arready),
        .s02_axi_rid(s02_axi_rid), .s02_axi_rdata(s02_axi_rdata),
        .s02_axi_rresp(s02_axi_rresp), .s02_axi_rlast(s02_axi_rlast),
        .s02_axi_ruser(), .s02_axi_rvalid(s02_axi_rvalid),
        .s02_axi_rready(s02_axi_rready),

        // Connect M00 to M17 ports to interconnect
        `define CONNECT_M(idx) \
            .m``idx``_axi_awid(m``idx``_axi_awid), .m``idx``_axi_awaddr(m``idx``_axi_awaddr), \
            .m``idx``_axi_awlen(m``idx``_axi_awlen), .m``idx``_axi_awsize(m``idx``_axi_awsize), \
            .m``idx``_axi_awburst(m``idx``_axi_awburst), .m``idx``_axi_awlock(m``idx``_axi_awlock), \
            .m``idx``_axi_awcache(m``idx``_axi_awcache), .m``idx``_axi_awprot(m``idx``_axi_awprot), \
            .m``idx``_axi_awqos(m``idx``_axi_awqos), .m``idx``_axi_awregion(m``idx``_axi_awregion), \
            .m``idx``_axi_awuser(), .m``idx``_axi_awvalid(m``idx``_axi_awvalid), \
            .m``idx``_axi_awready(m``idx``_axi_awready), \
            .m``idx``_axi_wdata(m``idx``_axi_wdata), .m``idx``_axi_wstrb(m``idx``_axi_wstrb), \
            .m``idx``_axi_wlast(m``idx``_axi_wlast), .m``idx``_axi_wuser(), \
            .m``idx``_axi_wvalid(m``idx``_axi_wvalid), .m``idx``_axi_wready(m``idx``_axi_wready), \
            .m``idx``_axi_bid(m``idx``_axi_bid), .m``idx``_axi_bresp(m``idx``_axi_bresp), \
            .m``idx``_axi_buser(1'b0), .m``idx``_axi_bvalid(m``idx``_axi_bvalid), \
            .m``idx``_axi_bready(m``idx``_axi_bready), \
            .m``idx``_axi_arid(m``idx``_axi_arid), .m``idx``_axi_araddr(m``idx``_axi_araddr), \
            .m``idx``_axi_arlen(m``idx``_axi_arlen), .m``idx``_axi_arsize(m``idx``_axi_arsize), \
            .m``idx``_axi_arburst(m``idx``_axi_arburst), .m``idx``_axi_arlock(m``idx``_axi_arlock), \
            .m``idx``_axi_arcache(m``idx``_axi_arcache), .m``idx``_axi_arprot(m``idx``_axi_arprot), \
            .m``idx``_axi_arqos(m``idx``_axi_arqos), .m``idx``_axi_arregion(m``idx``_axi_arregion), \
            .m``idx``_axi_aruser(), .m``idx``_axi_arvalid(m``idx``_axi_arvalid), \
            .m``idx``_axi_arready(m``idx``_axi_arready), \
            .m``idx``_axi_rid(m``idx``_axi_rid), .m``idx``_axi_rdata(m``idx``_axi_rdata), \
            .m``idx``_axi_rresp(m``idx``_axi_rresp), .m``idx``_axi_rlast(m``idx``_axi_rlast), \
            .m``idx``_axi_ruser(1'b0), .m``idx``_axi_rvalid(m``idx``_axi_rvalid), \
            .m``idx``_axi_rready(m``idx``_axi_rready)

        `CONNECT_M(00),
        `CONNECT_M(01),
        `CONNECT_M(02),
        `CONNECT_M(03),
        `CONNECT_M(04),
        `CONNECT_M(05),
        `CONNECT_M(06),
        `CONNECT_M(07),
        `CONNECT_M(08),
        `CONNECT_M(09),
        `CONNECT_M(10),
        `CONNECT_M(11),
        `CONNECT_M(12),
        `CONNECT_M(13),
        `CONNECT_M(14),
        `CONNECT_M(15),
        `CONNECT_M(16),
        `CONNECT_M(17)

        `undef CONNECT_M
    );

    // ========================================================================
    // PERIPHERAL INSTANTIATIONS
    // ========================================================================

    // ------------------------------------------------------------------------
    // M00 : UART (axi_uart_top) at 0x4000_0000
    // ------------------------------------------------------------------------
    wire uart_read_interrupt;
    assign uart_irq = uart_read_interrupt;

    // Shadow register to retain UART LCR writes (0x4000_000C -> offset 5'h0C, word offset 3'd3)
    reg [31:0] uart_lcr_shadow;
    always @(posedge clk) begin
        if (rst) begin
            uart_lcr_shadow <= 32'h0000_0000;
        end else begin
            if (m00_axi_awvalid && m00_axi_awready && m00_axi_wvalid && m00_axi_wready && (m00_axi_awaddr[4:2] == 3'd3)) begin
                uart_lcr_shadow <= m00_axi_wdata;
            end
        end
    end

    // Determine if read address is natively handled by axi_uart_top (RBR=0x00, LSR=0x14)
    wire uart_native_read = (m00_axi_araddr[4:2] == 3'd0) || (m00_axi_araddr[4:2] == 3'd5);

    // Fallback read handshake for non-RBR/LSR addresses (returns shadowed LCR or 0 with OKAY)
    reg  uart_fallback_rvalid;
    reg [31:0] uart_fallback_rdata;
    reg [ID_WIDTH-1:0] uart_fallback_rid;

    always @(posedge clk) begin
        if (rst) begin
            uart_fallback_rvalid <= 1'b0;
            uart_fallback_rdata  <= 32'h0;
            uart_fallback_rid    <= {ID_WIDTH{1'b0}};
        end else begin
            if (uart_fallback_rvalid) begin
                if (m00_axi_rready)
                    uart_fallback_rvalid <= 1'b0;
            end else if (m00_axi_arvalid && !uart_native_read) begin
                uart_fallback_rvalid <= 1'b1;
                uart_fallback_rid    <= m00_axi_arid;
                if (m00_axi_araddr[4:2] == 3'd3)
                    uart_fallback_rdata <= uart_lcr_shadow;
                else
                    uart_fallback_rdata <= 32'h0;
            end
        end
    end

    wire        uart_ip_arready;
    wire [11:0] uart_ip_rid;
    wire [31:0] uart_ip_rdata;
    wire [1:0]  uart_ip_rresp;
    wire        uart_ip_rvalid;
    wire [11:0] uart_ip_bid;

    axi_uart_top u_uart (
        .fixed_clk_i       (clk),
        .axi_aclk_i        (clk),
        .axi_aresetn_i     (~rst),

        .axi_arid_i        ({4'b0000, m00_axi_arid}),
        .axi_araddr_i      (m00_axi_araddr[4:0]),
        .axi_arvalid_i     (m00_axi_arvalid && uart_native_read),
        .axi_arready_o     (uart_ip_arready),

        .axi_rid_o         (uart_ip_rid),
        .axi_rdata_o       (uart_ip_rdata),
        .axi_rresp_o       (uart_ip_rresp),
        .axi_rvalid_o      (uart_ip_rvalid),
        .axi_rready_i      (m00_axi_rready),

        .axi_awid_i        ({4'b0000, m00_axi_awid}),
        .axi_awaddr_i      (m00_axi_awaddr[4:0]),
        .axi_awvalid_i     (m00_axi_awvalid),
        .axi_awready_o     (m00_axi_awready),

        .axi_wdata_i       (m00_axi_wdata),
        .axi_wstrb_i       (m00_axi_wstrb),
        .axi_wvalid_i      (m00_axi_wvalid),
        .axi_wready_o      (m00_axi_wready),

        .axi_bid_o         (uart_ip_bid),
        .axi_bresp_o       (m00_axi_bresp),
        .axi_bvalid_o      (m00_axi_bvalid),
        .axi_bready_i      (m00_axi_bready),

        .read_interrupt_o  (uart_read_interrupt),
        .uart_rx_i         (uart_rx_i),
        .uart_tx_o         (uart_tx_o)
    );

    assign m00_axi_bid     = uart_ip_bid[ID_WIDTH-1:0];
    assign m00_axi_arready = uart_native_read ? uart_ip_arready : (!uart_fallback_rvalid);
    assign m00_axi_rid     = uart_native_read ? uart_ip_rid[ID_WIDTH-1:0] : uart_fallback_rid;
    assign m00_axi_rdata   = uart_native_read ? uart_ip_rdata : uart_fallback_rdata;
    assign m00_axi_rresp   = uart_native_read ? uart_ip_rresp : 2'b00;
    assign m00_axi_rvalid  = uart_native_read ? uart_ip_rvalid : uart_fallback_rvalid;
    assign m00_axi_rlast   = 1'b1;

    // ------------------------------------------------------------------------
    // M01 : GPIO (gpio_axi) at 0x4000_2000
    // ------------------------------------------------------------------------
    wire [31:0] gpio_axil_awaddr = m01_axi_awaddr - 32'h4000_2000;
    wire [31:0] gpio_axil_araddr = m01_axi_araddr - 32'h4000_2000;
    reg [ID_WIDTH-1:0] gpio_awid_q;
    reg [ID_WIDTH-1:0] gpio_arid_q;

    always @(posedge clk) begin
        if (rst) begin
            gpio_awid_q <= {ID_WIDTH{1'b0}};
            gpio_arid_q <= {ID_WIDTH{1'b0}};
        end else begin
            if (m01_axi_awvalid && m01_axi_awready)
                gpio_awid_q <= m01_axi_awid;
            if (m01_axi_arvalid && m01_axi_arready)
                gpio_arid_q <= m01_axi_arid;
        end
    end

    wire [31:0] gpio_axil_rdata;
    wire [1:0]  gpio_axil_rresp;
    wire        gpio_axil_rvalid;
    wire        gpio_axil_arready;
    wire        gpio_axil_awready;
    wire        gpio_axil_wready;
    wire        gpio_axil_bvalid;
    wire [1:0]  gpio_axil_bresp;

    assign m01_axi_awready = gpio_axil_awready;
    assign m01_axi_wready  = gpio_axil_wready;
    assign m01_axi_bid     = gpio_awid_q;
    assign m01_axi_bresp   = gpio_axil_bresp;
    assign m01_axi_bvalid  = gpio_axil_bvalid;
    assign m01_axi_arready = gpio_axil_arready;
    assign m01_axi_rid     = gpio_arid_q;
    assign m01_axi_rdata   = gpio_axil_rdata;
    assign m01_axi_rresp   = gpio_axil_rresp;
    assign m01_axi_rlast   = 1'b1;
    assign m01_axi_rvalid  = gpio_axil_rvalid;

    gpio_axi #(.NUM_BITS(32)) u_gpio (
        .s_axi_aclk     (clk),
        .s_axi_aresetn  (~rst),
        .s_axi_awaddr   (gpio_axil_awaddr),
        .s_axi_awprot   (m01_axi_awprot),
        .s_axi_awvalid  (m01_axi_awvalid),
        .s_axi_awready  (gpio_axil_awready),
        .s_axi_wdata    (m01_axi_wdata),
        .s_axi_wstrb    (m01_axi_wstrb),
        .s_axi_wvalid   (m01_axi_wvalid),
        .s_axi_wready   (gpio_axil_wready),
        .s_axi_bresp    (gpio_axil_bresp),
        .s_axi_bvalid   (gpio_axil_bvalid),
        .s_axi_bready   (m01_axi_bready),
        .s_axi_araddr   (gpio_axil_araddr),
        .s_axi_arprot   (m01_axi_arprot),
        .s_axi_arvalid  (m01_axi_arvalid),
        .s_axi_arready  (gpio_axil_arready),
        .s_axi_rdata    (gpio_axil_rdata),
        .s_axi_rresp    (gpio_axil_rresp),
        .s_axi_rvalid   (gpio_axil_rvalid),
        .s_axi_rready   (m01_axi_rready),
        .io             (gpio_io),
        .intr           (gpio_irq)
    );

    // ------------------------------------------------------------------------
    // M02 : TIMER (timer_axi) at 0x4000_4000
    // ------------------------------------------------------------------------
    wire [31:0] timer_axil_awaddr = m02_axi_awaddr - 32'h4000_4000;
    wire [31:0] timer_axil_araddr = m02_axi_araddr - 32'h4000_4000;
    reg [ID_WIDTH-1:0] timer_awid_q;
    reg [ID_WIDTH-1:0] timer_arid_q;

    always @(posedge clk) begin
        if (rst) begin
            timer_awid_q <= {ID_WIDTH{1'b0}};
            timer_arid_q <= {ID_WIDTH{1'b0}};
        end else begin
            if (m02_axi_awvalid && m02_axi_awready)
                timer_awid_q <= m02_axi_awid;
            if (m02_axi_arvalid && m02_axi_arready)
                timer_arid_q <= m02_axi_arid;
        end
    end

    wire [31:0] timer_axil_rdata;
    wire [1:0]  timer_axil_rresp;
    wire        timer_axil_rvalid;
    wire        timer_axil_arready;
    wire        timer_axil_awready;
    wire        timer_axil_wready;
    wire        timer_axil_bvalid;
    wire [1:0]  timer_axil_bresp;

    assign m02_axi_awready = timer_axil_awready;
    assign m02_axi_wready  = timer_axil_wready;
    assign m02_axi_bid     = timer_awid_q;
    assign m02_axi_bresp   = timer_axil_bresp;
    assign m02_axi_bvalid  = timer_axil_bvalid;
    assign m02_axi_arready = timer_axil_arready;
    assign m02_axi_rid     = timer_arid_q;
    assign m02_axi_rdata   = timer_axil_rdata;
    assign m02_axi_rresp   = timer_axil_rresp;
    assign m02_axi_rlast   = 1'b1;
    assign m02_axi_rvalid  = timer_axil_rvalid;

    timer_axi u_timer (
        .aclk        (clk),
        .aresetn     (~rst),
        .awaddr      (timer_axil_awaddr),
        .awprot      (m02_axi_awprot),
        .awvalid     (m02_axi_awvalid),
        .awready     (timer_axil_awready),
        .wdata       (m02_axi_wdata),
        .wstrb       (m02_axi_wstrb),
        .wvalid      (m02_axi_wvalid),
        .wready      (timer_axil_wready),
        .bresp       (timer_axil_bresp),
        .bvalid      (timer_axil_bvalid),
        .bready      (m02_axi_bready),
        .araddr      (timer_axil_araddr),
        .arprot      (m02_axi_arprot),
        .arvalid     (m02_axi_arvalid),
        .arready     (timer_axil_arready),
        .rdata       (timer_axil_rdata),
        .rresp       (timer_axil_rresp),
        .rvalid      (timer_axil_rvalid),
        .rready      (m02_axi_rready),
        .ext_meas_i  (timer_ext_meas_i),
        .capture_i   (timer_capture_i),
        .pwm_o       (timer_pwm_o),
        .trigger_o   (timer_trigger_o),
        .irq         (timer_irq)
    );

    // ------------------------------------------------------------------------
    // M03 : FIR Filter (fir_top) at 0x4000_C000
    // ------------------------------------------------------------------------
    wire [31:0] fir_axil_awaddr = m03_axi_awaddr - 32'h4000_C000;
    wire [31:0] fir_axil_araddr = m03_axi_araddr - 32'h4000_C000;
    reg [ID_WIDTH-1:0] fir_ctrl_awid_reg;
    reg [ID_WIDTH-1:0] fir_ctrl_arid_reg;

    always @(posedge clk) begin
        if (rst) begin
            fir_ctrl_awid_reg <= {ID_WIDTH{1'b0}};
            fir_ctrl_arid_reg <= {ID_WIDTH{1'b0}};
        end else begin
            if (m03_axi_awvalid && m03_axi_awready)
                fir_ctrl_awid_reg <= m03_axi_awid;
            if (m03_axi_arvalid && m03_axi_arready)
                fir_ctrl_arid_reg <= m03_axi_arid;
        end
    end

    wire        fir_axil_awvalid = m03_axi_awvalid;
    wire        fir_axil_awready;
    wire [31:0] fir_axil_wdata   = m03_axi_wdata;
    wire [3:0]  fir_axil_wstrb   = m03_axi_wstrb;
    wire        fir_axil_wvalid  = m03_axi_wvalid;
    wire        fir_axil_wready;
    wire        fir_axil_bvalid;
    wire [1:0]  fir_axil_bresp;
    wire        fir_axil_bready  = m03_axi_bready;
    wire        fir_axil_arvalid = m03_axi_arvalid;
    wire        fir_axil_arready;
    wire [31:0] fir_axil_rdata;
    wire        fir_axil_rvalid;
    wire [1:0]  fir_axil_rresp;
    wire        fir_axil_rready  = m03_axi_rready;

    assign m03_axi_awready = fir_axil_awready;
    assign m03_axi_wready  = fir_axil_wready;
    assign m03_axi_bid     = fir_ctrl_awid_reg;
    assign m03_axi_bresp   = fir_axil_bresp;
    assign m03_axi_bvalid  = fir_axil_bvalid;
    assign m03_axi_arready = fir_axil_arready;
    assign m03_axi_rid     = fir_ctrl_arid_reg;
    assign m03_axi_rdata   = fir_axil_rdata;
    assign m03_axi_rresp   = fir_axil_rresp;
    assign m03_axi_rlast   = 1'b1;
    assign m03_axi_rvalid  = fir_axil_rvalid;

    wire fir_input_fifo_full;
    wire fir_input_fifo_empty;
    wire fir_output_fifo_empty;

    fir_top #(
        .DATA_WIDTH  (16),
        .COEFF_WIDTH (16),
        .ACC_WIDTH   (40),
        .NUM_TAPS    (32),
        .FIFO_DEPTH  (16)
    ) u_fir (
        .clk                (clk),
        .rst_n              (~rst),

        .s_axis_tvalid     (fir_s_axis_tvalid),
        .s_axis_tready     (fir_s_axis_tready),
        .s_axis_tdata      (fir_s_axis_tdata),

        .m_axis_tvalid     (fir_m_axis_tvalid),
        .m_axis_tready     (fir_m_axis_tready),
        .m_axis_tdata      (fir_m_axis_tdata),

        .s_axi_awaddr      (fir_axil_awaddr),
        .s_axi_awvalid     (fir_axil_awvalid),
        .s_axi_awready     (fir_axil_awready),

        .s_axi_wdata       (fir_axil_wdata),
        .s_axi_wstrb       (fir_axil_wstrb),
        .s_axi_wvalid      (fir_axil_wvalid),
        .s_axi_wready      (fir_axil_wready),

        .s_axi_bvalid      (fir_axil_bvalid),
        .s_axi_bresp       (fir_axil_bresp),
        .s_axi_bready      (fir_axil_bready),

        .s_axi_araddr      (fir_axil_araddr),
        .s_axi_arvalid     (fir_axil_arvalid),
        .s_axi_arready     (fir_axil_arready),

        .s_axi_rdata       (fir_axil_rdata),
        .s_axi_rvalid      (fir_axil_rvalid),
        .s_axi_rresp       (fir_axil_rresp),
        .s_axi_rready      (fir_axil_rready),

        .input_fifo_full   (fir_input_fifo_full),
        .input_fifo_empty  (fir_input_fifo_empty),
        .output_fifo_empty (fir_output_fifo_empty)
    );

    // ------------------------------------------------------------------------
    // M04 : ADC Controller (adc_controller) at 0x4000_E000
    // ------------------------------------------------------------------------
    reg [ID_WIDTH-1:0] adc_ctrl_awid_reg;
    reg [ID_WIDTH-1:0] adc_ctrl_arid_reg;

    always @(posedge clk) begin
        if (rst) begin
            adc_ctrl_awid_reg <= {ID_WIDTH{1'b0}};
            adc_ctrl_arid_reg <= {ID_WIDTH{1'b0}};
        end else begin
            if (m04_axi_awvalid && m04_axi_awready)
                adc_ctrl_awid_reg <= m04_axi_awid;
            if (m04_axi_arvalid && m04_axi_arready)
                adc_ctrl_arid_reg <= m04_axi_arid;
        end
    end

    wire [31:0] adc_axil_awaddr  = m04_axi_awaddr; // passes absolute address (BASE_ADDR = 0x4000_E000)
    wire        adc_axil_awvalid = m04_axi_awvalid;
    wire        adc_axil_awready;
    wire [31:0] adc_axil_wdata   = m04_axi_wdata;
    wire [3:0]  adc_axil_wstrb   = m04_axi_wstrb;
    wire        adc_axil_wvalid  = m04_axi_wvalid;
    wire        adc_axil_wready;
    wire        adc_axil_bvalid;
    wire [1:0]  adc_axil_bresp;
    wire        adc_axil_bready  = m04_axi_bready;
    wire [31:0] adc_axil_araddr  = m04_axi_araddr;
    wire        adc_axil_arvalid = m04_axi_arvalid;
    wire        adc_axil_arready;
    wire [31:0] adc_axil_rdata;
    wire        adc_axil_rvalid;
    wire [1:0]  adc_axil_rresp;
    wire        adc_axil_rready  = m04_axi_rready;

    assign m04_axi_awready = adc_axil_awready;
    assign m04_axi_wready  = adc_axil_wready;
    assign m04_axi_bid     = adc_ctrl_awid_reg;
    assign m04_axi_bresp   = adc_axil_bresp;
    assign m04_axi_bvalid  = adc_axil_bvalid;
    assign m04_axi_arready = adc_axil_arready;
    assign m04_axi_rid     = adc_ctrl_arid_reg;
    assign m04_axi_rdata   = adc_axil_rdata;
    assign m04_axi_rresp   = adc_axil_rresp;
    assign m04_axi_rlast   = 1'b1;
    assign m04_axi_rvalid  = adc_axil_rvalid;

    adc_controller #(
        .ADC_RESOLUTION    (12),
        .NUM_CHANNELS      (1),
        .FIFO_DEPTH        (32),
        .CLK_FREQ_HZ       (50_000_000),
        .SAMPLE_RATE_HZ    (250),
        .BASE_ADDR         (32'h4000_E000),
        .ENABLE_FIFO       (1),
        .ENABLE_INTERRUPTS (1)
    ) u_adc (
        .aclk            (clk),
        .aresetn         (~rst),
        .sample_in       (adc_sample_in),
        .sample_valid    (adc_sample_valid),
        .irq_sample      (adc_irq_sample),
        .irq_overrun     (adc_irq_overrun),

        .s_axi_awaddr    (adc_axil_awaddr),
        .s_axi_awvalid   (adc_axil_awvalid),
        .s_axi_awready   (adc_axil_awready),
        .s_axi_wdata     (adc_axil_wdata),
        .s_axi_wstrb     (adc_axil_wstrb),
        .s_axi_wvalid    (adc_axil_wvalid),
        .s_axi_wready    (adc_axil_wready),
        .s_axi_bresp     (adc_axil_bresp),
        .s_axi_bvalid    (adc_axil_bvalid),
        .s_axi_bready    (adc_axil_bready),
        .s_axi_araddr    (adc_axil_araddr),
        .s_axi_arvalid   (adc_axil_arvalid),
        .s_axi_arready   (adc_axil_arready),
        .s_axi_rdata     (adc_axil_rdata),
        .s_axi_rresp     (adc_axil_rresp),
        .s_axi_rvalid    (adc_axil_rvalid),
        .s_axi_rready    (adc_axil_rready)
    );

    // ------------------------------------------------------------------------
    // M05 : FFT Control & M06 : FFT Memory (fft_accel_top)
    //   Control: 0x4000_8000
    //   Memory : 0x4000_A000 -> translated to local BRAM 0x1000
    // ------------------------------------------------------------------------
    reg [ID_WIDTH-1:0] fft_ctrl_awid_reg;
    reg [ID_WIDTH-1:0] fft_ctrl_arid_reg;

    always @(posedge clk) begin
        if (rst) begin
            fft_ctrl_awid_reg <= {ID_WIDTH{1'b0}};
            fft_ctrl_arid_reg <= {ID_WIDTH{1'b0}};
        end else begin
            if (m05_axi_awvalid && m05_axi_awready)
                fft_ctrl_awid_reg <= m05_axi_awid;
            if (m05_axi_arvalid && m05_axi_arready)
                fft_ctrl_arid_reg <= m05_axi_arid;
        end
    end

    wire [31:0] fft_axil_awaddr  = m05_axi_awaddr - 32'h4000_8000;
    wire        fft_axil_awvalid = m05_axi_awvalid;
    wire        fft_axil_awready;
    wire [31:0] fft_axil_wdata   = m05_axi_wdata;
    wire [3:0]  fft_axil_wstrb   = m05_axi_wstrb;
    wire        fft_axil_wvalid  = m05_axi_wvalid;
    wire        fft_axil_wready;
    wire [1:0]  fft_axil_bresp;
    wire        fft_axil_bvalid;
    wire        fft_axil_bready  = m05_axi_bready;
    wire [31:0] fft_axil_araddr  = m05_axi_araddr - 32'h4000_8000;
    wire        fft_axil_arvalid = m05_axi_arvalid;
    wire        fft_axil_arready;
    wire [31:0] fft_axil_rdata;
    wire [1:0]  fft_axil_rresp;
    wire        fft_axil_rvalid;
    wire        fft_axil_rready  = m05_axi_rready;

    assign m05_axi_awready = fft_axil_awready;
    assign m05_axi_wready  = fft_axil_wready;
    assign m05_axi_bid     = fft_ctrl_awid_reg;
    assign m05_axi_bresp   = fft_axil_bresp;
    assign m05_axi_bvalid  = fft_axil_bvalid;
    assign m05_axi_arready = fft_axil_arready;
    assign m05_axi_rid     = fft_ctrl_arid_reg;
    assign m05_axi_rdata   = fft_axil_rdata;
    assign m05_axi_rresp   = fft_axil_rresp;
    assign m05_axi_rlast   = 1'b1;
    assign m05_axi_rvalid  = fft_axil_rvalid;

    // FFT Memory (M06) - maps 0x4000_A000 -> 0x1000
    wire [3:0]  fft_mem_awid    = m06_axi_awid[3:0];
    wire [15:0] fft_mem_awaddr  = m06_axi_awaddr[15:0] - 16'h9000;
    wire [7:0]  fft_mem_awlen   = m06_axi_awlen;
    wire [2:0]  fft_mem_awsize  = m06_axi_awsize;
    wire [1:0]  fft_mem_awburst = m06_axi_awburst;
    wire        fft_mem_awvalid = m06_axi_awvalid;
    wire        fft_mem_awready;
    wire [31:0] fft_mem_wdata   = m06_axi_wdata;
    wire [3:0]  fft_mem_wstrb   = m06_axi_wstrb;
    wire        fft_mem_wlast   = m06_axi_wlast;
    wire        fft_mem_wvalid  = m06_axi_wvalid;
    wire        fft_mem_wready;
    wire [3:0]  fft_mem_bid;
    wire [1:0]  fft_mem_bresp;
    wire        fft_mem_bvalid;
    wire        fft_mem_bready  = m06_axi_bready;
    wire [3:0]  fft_mem_arid    = m06_axi_arid[3:0];
    wire [15:0] fft_mem_araddr  = m06_axi_araddr[15:0] - 16'h9000;
    wire [7:0]  fft_mem_arlen   = m06_axi_arlen;
    wire [2:0]  fft_mem_arsize  = m06_axi_arsize;
    wire [1:0]  fft_mem_arburst = m06_axi_arburst;
    wire        fft_mem_arvalid = m06_axi_arvalid;
    wire        fft_mem_arready;
    wire [3:0]  fft_mem_rid;
    wire [31:0] fft_mem_rdata;
    wire [1:0]  fft_mem_rresp;
    wire        fft_mem_rlast;
    wire        fft_mem_rvalid;
    wire        fft_mem_rready  = m06_axi_rready;

    assign m06_axi_awready = fft_mem_awready;
    assign m06_axi_wready  = fft_mem_wready;
    assign m06_axi_bid     = {{(ID_WIDTH-4){1'b0}}, fft_mem_bid};
    assign m06_axi_bresp   = fft_mem_bresp;
    assign m06_axi_bvalid  = fft_mem_bvalid;
    assign m06_axi_arready = fft_mem_arready;
    assign m06_axi_rid     = {{(ID_WIDTH-4){1'b0}}, fft_mem_rid};
    assign m06_axi_rdata   = fft_mem_rdata;
    assign m06_axi_rresp   = fft_mem_rresp;
    assign m06_axi_rlast   = fft_mem_rlast;
    assign m06_axi_rvalid  = fft_mem_rvalid;

    fft_accel_top #(
        .N(1024), .AXI_ADDR_W(16), .AXI_DATA_W(32), .AXI_ID_W(4)
    ) u_fft_accel (
        .clk             (clk),
        .rst_n           (~rst),
        .irq             (),

        .S_AXIL_AWADDR   (fft_axil_awaddr),
        .S_AXIL_AWVALID  (fft_axil_awvalid),
        .S_AXIL_AWREADY  (fft_axil_awready),
        .S_AXIL_WDATA    (fft_axil_wdata),
        .S_AXIL_WSTRB    (fft_axil_wstrb),
        .S_AXIL_WVALID   (fft_axil_wvalid),
        .S_AXIL_WREADY   (fft_axil_wready),
        .S_AXIL_BRESP    (fft_axil_bresp),
        .S_AXIL_BVALID   (fft_axil_bvalid),
        .S_AXIL_BREADY   (fft_axil_bready),
        .S_AXIL_ARADDR   (fft_axil_araddr),
        .S_AXIL_ARVALID  (fft_axil_arvalid),
        .S_AXIL_ARREADY  (fft_axil_arready),
        .S_AXIL_RDATA    (fft_axil_rdata),
        .S_AXIL_RRESP    (fft_axil_rresp),
        .S_AXIL_RVALID   (fft_axil_rvalid),
        .S_AXIL_RREADY   (fft_axil_rready),

        .S_AXI_AWID     (fft_mem_awid),
        .S_AXI_AWADDR   (fft_mem_awaddr),
        .S_AXI_AWLEN    (fft_mem_awlen),
        .S_AXI_AWSIZE   (fft_mem_awsize),
        .S_AXI_AWBURST  (fft_mem_awburst),
        .S_AXI_AWVALID  (fft_mem_awvalid),
        .S_AXI_AWREADY  (fft_mem_awready),
        .S_AXI_WDATA    (fft_mem_wdata),
        .S_AXI_WSTRB    (fft_mem_wstrb),
        .S_AXI_WLAST    (fft_mem_wlast),
        .S_AXI_WVALID   (fft_mem_wvalid),
        .S_AXI_WREADY   (fft_mem_wready),
        .S_AXI_BID      (fft_mem_bid),
        .S_AXI_BRESP    (fft_mem_bresp),
        .S_AXI_BVALID   (fft_mem_bvalid),
        .S_AXI_BREADY   (fft_mem_bready),
        .S_AXI_ARID     (fft_mem_arid),
        .S_AXI_ARADDR   (fft_mem_araddr),
        .S_AXI_ARLEN    (fft_mem_arlen),
        .S_AXI_ARSIZE   (fft_mem_arsize),
        .S_AXI_ARBURST  (fft_mem_arburst),
        .S_AXI_ARVALID  (fft_mem_arvalid),
        .S_AXI_ARREADY  (fft_mem_arready),
        .S_AXI_RID      (fft_mem_rid),
        .S_AXI_RDATA    (fft_mem_rdata),
        .S_AXI_RRESP    (fft_mem_rresp),
        .S_AXI_RLAST    (fft_mem_rlast),
        .S_AXI_RVALID   (fft_mem_rvalid),
        .S_AXI_RREADY   (fft_mem_rready)
    );

    // ------------------------------------------------------------------------
    // M07 : IMEM (axi_imem_slave) at 0x0000_0000 (64 KB)
    // ------------------------------------------------------------------------
    axi_imem_slave #(
        .AXI_ID_WIDTH   (ID_WIDTH),
        .AXI_DATA_WIDTH (DATA_WIDTH),
        .AXI_ADDR_WIDTH (ADDR_WIDTH),
        .MEM_SIZE_BYTES (65536),
        .BASE_ADDR      (32'h0000_0000)
    ) u_imem (
        .aclk           (clk),
        .aresetn        (~rst),
        .s_awid         (m07_axi_awid),
        .s_awaddr       (m07_axi_awaddr),
        .s_awlen        (m07_axi_awlen),
        .s_awsize       (m07_axi_awsize),
        .s_awburst      (m07_axi_awburst),
        .s_awlock       (m07_axi_awlock),
        .s_awcache      (m07_axi_awcache),
        .s_awprot       (m07_axi_awprot),
        .s_awqos        (m07_axi_awqos),
        .s_awregion     (m07_axi_awregion),
        .s_awvalid      (m07_axi_awvalid),
        .s_awready      (m07_axi_awready),
        .s_wdata        (m07_axi_wdata),
        .s_wstrb        (m07_axi_wstrb),
        .s_wlast        (m07_axi_wlast),
        .s_wvalid       (m07_axi_wvalid),
        .s_wready       (m07_axi_wready),
        .s_bid          (m07_axi_bid),
        .s_bresp        (m07_axi_bresp),
        .s_bvalid       (m07_axi_bvalid),
        .s_bready       (m07_axi_bready),
        .s_arid         (m07_axi_arid),
        .s_araddr       (m07_axi_araddr),
        .s_arlen        (m07_axi_arlen),
        .s_arsize       (m07_axi_arsize),
        .s_arburst      (m07_axi_arburst),
        .s_arlock       (m07_axi_arlock),
        .s_arcache      (m07_axi_arcache),
        .s_arprot       (m07_axi_arprot),
        .s_arqos        (m07_axi_arqos),
        .s_arregion     (m07_axi_arregion),
        .s_arvalid      (m07_axi_arvalid),
        .s_arready      (m07_axi_arready),
        .s_rid          (m07_axi_rid),
        .s_rdata        (m07_axi_rdata),
        .s_rresp        (m07_axi_rresp),
        .s_rlast        (m07_axi_rlast),
        .s_rvalid       (m07_axi_rvalid),
        .s_rready       (m07_axi_rready)
    );

    // ------------------------------------------------------------------------
    // M08 : DMEM (axi_dmem_slave) at 0x0001_0000 (64 KB)
    // ------------------------------------------------------------------------
    axi_dmem_slave #(
        .AXI_ID_WIDTH   (ID_WIDTH),
        .AXI_DATA_WIDTH (DATA_WIDTH),
        .AXI_ADDR_WIDTH (ADDR_WIDTH),
        .MEM_SIZE_BYTES (65536),
        .BASE_ADDR      (32'h0001_0000)
    ) u_dmem (
        .aclk           (clk),
        .aresetn        (~rst),
        .s_awid         (m08_axi_awid),
        .s_awaddr       (m08_axi_awaddr),
        .s_awlen        (m08_axi_awlen),
        .s_awsize       (m08_axi_awsize),
        .s_awburst      (m08_axi_awburst),
        .s_awlock       (m08_axi_awlock),
        .s_awcache      (m08_axi_awcache),
        .s_awprot       (m08_axi_awprot),
        .s_awqos        (m08_axi_awqos),
        .s_awregion     (m08_axi_awregion),
        .s_awvalid      (m08_axi_awvalid),
        .s_awready      (m08_axi_awready),
        .s_wdata        (m08_axi_wdata),
        .s_wstrb        (m08_axi_wstrb),
        .s_wlast        (m08_axi_wlast),
        .s_wvalid       (m08_axi_wvalid),
        .s_wready       (m08_axi_wready),
        .s_bid          (m08_axi_bid),
        .s_bresp        (m08_axi_bresp),
        .s_bvalid       (m08_axi_bvalid),
        .s_bready       (m08_axi_bready),
        .s_arid         (m08_axi_arid),
        .s_araddr       (m08_axi_araddr),
        .s_arlen        (m08_axi_arlen),
        .s_arsize       (m08_axi_arsize),
        .s_arburst      (m08_axi_arburst),
        .s_arlock       (m08_axi_arlock),
        .s_arcache      (m08_axi_arcache),
        .s_arprot       (m08_axi_arprot),
        .s_arqos        (m08_axi_arqos),
        .s_arregion     (m08_axi_arregion),
        .s_arvalid      (m08_axi_arvalid),
        .s_arready      (m08_axi_arready),
        .s_rid          (m08_axi_rid),
        .s_rdata        (m08_axi_rdata),
        .s_rresp        (m08_axi_rresp),
        .s_rlast        (m08_axi_rlast),
        .s_rvalid       (m08_axi_rvalid),
        .s_rready       (m08_axi_rready)
    );

    // ------------------------------------------------------------------------
    // M09-M17 : Dummy Slaves (axi_dummy_slave returning DECERR = 2'b11)
    // ------------------------------------------------------------------------
    `define INSTANTIATE_DUMMY(idx) \
        axi_dummy_slave #( \
            .DATA_WIDTH (DATA_WIDTH), \
            .ADDR_WIDTH (ADDR_WIDTH), \
            .STRB_WIDTH (STRB_WIDTH), \
            .ID_WIDTH   (ID_WIDTH), \
            .RESP       (2'b11) \
        ) u_dummy_``idx ( \
            .clk            (clk), \
            .rst            (rst), \
            .s_axi_awid     (m``idx``_axi_awid), \
            .s_axi_awaddr   (m``idx``_axi_awaddr), \
            .s_axi_awlen    (m``idx``_axi_awlen), \
            .s_axi_awsize   (m``idx``_axi_awsize), \
            .s_axi_awburst  (m``idx``_axi_awburst), \
            .s_axi_awlock   (m``idx``_axi_awlock), \
            .s_axi_awcache  (m``idx``_axi_awcache), \
            .s_axi_awprot   (m``idx``_axi_awprot), \
            .s_axi_awqos    (m``idx``_axi_awqos), \
            .s_axi_awregion (m``idx``_axi_awregion), \
            .s_axi_awuser   (1'b0), \
            .s_axi_awvalid  (m``idx``_axi_awvalid), \
            .s_axi_awready  (m``idx``_axi_awready), \
            .s_axi_wdata    (m``idx``_axi_wdata), \
            .s_axi_wstrb    (m``idx``_axi_wstrb), \
            .s_axi_wlast    (m``idx``_axi_wlast), \
            .s_axi_wuser    (1'b0), \
            .s_axi_wvalid   (m``idx``_axi_wvalid), \
            .s_axi_wready   (m``idx``_axi_wready), \
            .s_axi_bid      (m``idx``_axi_bid), \
            .s_axi_bresp    (m``idx``_axi_bresp), \
            .s_axi_buser    (), \
            .s_axi_bvalid   (m``idx``_axi_bvalid), \
            .s_axi_bready   (m``idx``_axi_bready), \
            .s_axi_arid     (m``idx``_axi_arid), \
            .s_axi_araddr   (m``idx``_axi_araddr), \
            .s_axi_arlen    (m``idx``_axi_arlen), \
            .s_axi_arsize   (m``idx``_axi_arsize), \
            .s_axi_arburst  (m``idx``_axi_arburst), \
            .s_axi_arlock   (m``idx``_axi_arlock), \
            .s_axi_arcache  (m``idx``_axi_arcache), \
            .s_axi_arprot   (m``idx``_axi_arprot), \
            .s_axi_arqos    (m``idx``_axi_arqos), \
            .s_axi_arregion (m``idx``_axi_arregion), \
            .s_axi_aruser   (1'b0), \
            .s_axi_arvalid  (m``idx``_axi_arvalid), \
            .s_axi_arready  (m``idx``_axi_arready), \
            .s_axi_rid      (m``idx``_axi_rid), \
            .s_axi_rdata    (m``idx``_axi_rdata), \
            .s_axi_rresp    (m``idx``_axi_rresp), \
            .s_axi_rlast    (m``idx``_axi_rlast), \
            .s_axi_ruser    (), \
            .s_axi_rvalid   (m``idx``_axi_rvalid), \
            .s_axi_rready   (m``idx``_axi_rready) \
        );

    `INSTANTIATE_DUMMY(09)
    `INSTANTIATE_DUMMY(10)
    `INSTANTIATE_DUMMY(11)
    `INSTANTIATE_DUMMY(12)
    `INSTANTIATE_DUMMY(13)
    `INSTANTIATE_DUMMY(14)
    `INSTANTIATE_DUMMY(15)
    `INSTANTIATE_DUMMY(16)
    `INSTANTIATE_DUMMY(17)

    `undef INSTANTIATE_DUMMY

endmodule

`default_nettype wire
