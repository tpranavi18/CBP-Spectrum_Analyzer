//`timescale 1ns/1ps

module soc_uart_fft_top #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter STRB_WIDTH = 4,
    parameter ID_WIDTH   = 8
)(
    input  wire                     clk,
    input  wire                     rst,

    /* ============================================================
     * S00 AXI interface
     * This is driven by the testbench now.
     * Later this will connect to the RISC-V master/interconnect side.
     * ============================================================ */

    input  wire [ID_WIDTH-1:0]      s00_axi_awid,
    input  wire [ADDR_WIDTH-1:0]    s00_axi_awaddr,
    input  wire [7:0]               s00_axi_awlen,
    input  wire [2:0]               s00_axi_awsize,
    input  wire [1:0]               s00_axi_awburst,
    input  wire                     s00_axi_awlock,
    input  wire [3:0]               s00_axi_awcache,
    input  wire [2:0]               s00_axi_awprot,
    input  wire [3:0]               s00_axi_awqos,
    input  wire [0:0]               s00_axi_awuser,
    input  wire                     s00_axi_awvalid,
    output wire                     s00_axi_awready,

    input  wire [DATA_WIDTH-1:0]    s00_axi_wdata,
    input  wire [STRB_WIDTH-1:0]    s00_axi_wstrb,
    input  wire                     s00_axi_wlast,
    input  wire [0:0]               s00_axi_wuser,
    input  wire                     s00_axi_wvalid,
    output wire                     s00_axi_wready,

    output wire [ID_WIDTH-1:0]      s00_axi_bid,
    output wire [1:0]               s00_axi_bresp,
    output wire [0:0]               s00_axi_buser,
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
    input  wire [0:0]               s00_axi_aruser,
    input  wire                     s00_axi_arvalid,
    output wire                     s00_axi_arready,

    output wire [ID_WIDTH-1:0]      s00_axi_rid,
    output wire [DATA_WIDTH-1:0]    s00_axi_rdata,
    output wire [1:0]               s00_axi_rresp,
    output wire                     s00_axi_rlast,
    output wire [0:0]               s00_axi_ruser,
    output wire                     s00_axi_rvalid,
    input  wire                     s00_axi_rready,

    /* UART external pins */
    input  wire                     uart_rx_i,
    output wire                     uart_tx_o,

    /* ADC external sample interface */
    input  wire [11:0]               adc_sample_in,
    input  wire                     adc_sample_valid,
    output wire                     adc_irq_sample,
    output wire                     adc_irq_overrun,

    /* GPIO physical pins and interrupt */
    inout  wire [31:0]              gpio_io,
    output wire                     gpio_intr,

    /* Timer external inputs, outputs and interrupt */
    input  wire                     timer_ext_meas_i,
    input  wire                     timer_capture_i,
    output wire                     timer_pwm_o,
    output wire                     timer_trigger_o,
    output wire                     timer_irq
);


    /* ============================================================
     * INTERCONNECT M00 <-> UART
     * ============================================================ */

    wire [ID_WIDTH-1:0]   m00_axi_awid;
    wire [ADDR_WIDTH-1:0] m00_axi_awaddr;
    wire [7:0]            m00_axi_awlen;
    wire [2:0]            m00_axi_awsize;
    wire [1:0]            m00_axi_awburst;
    wire                  m00_axi_awlock;
    wire [3:0]            m00_axi_awcache;
    wire [2:0]            m00_axi_awprot;
    wire [3:0]            m00_axi_awqos;
    wire [3:0]            m00_axi_awregion;
    wire [0:0]            m00_axi_awuser;
    wire                  m00_axi_awvalid;
    wire                  m00_axi_awready;

    wire [DATA_WIDTH-1:0] m00_axi_wdata;
    wire [STRB_WIDTH-1:0] m00_axi_wstrb;
    wire                  m00_axi_wlast;
    wire [0:0]            m00_axi_wuser;
    wire                  m00_axi_wvalid;
    wire                  m00_axi_wready;

    wire [ID_WIDTH-1:0]   m00_axi_bid;
    wire [1:0]            m00_axi_bresp;
    wire [0:0]            m00_axi_buser;
    wire                  m00_axi_bvalid;
    wire                  m00_axi_bready;

    wire [ID_WIDTH-1:0]   m00_axi_arid;
    wire [ADDR_WIDTH-1:0] m00_axi_araddr;
    wire [7:0]            m00_axi_arlen;
    wire [2:0]            m00_axi_arsize;
    wire [1:0]            m00_axi_arburst;
    wire                  m00_axi_arlock;
    wire [3:0]            m00_axi_arcache;
    wire [2:0]            m00_axi_arprot;
    wire [3:0]            m00_axi_arqos;
    wire [3:0]            m00_axi_arregion;
    wire [0:0]            m00_axi_aruser;
    wire                  m00_axi_arvalid;
    wire                  m00_axi_arready;

    wire [ID_WIDTH-1:0]   m00_axi_rid;
    wire [DATA_WIDTH-1:0] m00_axi_rdata;
    wire [1:0]            m00_axi_rresp;
    wire                  m00_axi_rlast;
    wire [0:0]            m00_axi_ruser;
    wire                  m00_axi_rvalid;
    wire                  m00_axi_rready;


    /* ============================================================
     * INTERCONNECT M01 <-> FFT CONTROL (AXI4-Lite)
     * INTERCONNECT M02 <-> FFT MEMORY (AXI4)
     * ============================================================ */

    wire [ID_WIDTH-1:0]   m01_axi_awid;
    wire [ADDR_WIDTH-1:0] m01_axi_awaddr;
    wire [7:0]            m01_axi_awlen;
    wire [2:0]            m01_axi_awsize;
    wire [1:0]            m01_axi_awburst;
    wire                  m01_axi_awlock;
    wire [3:0]            m01_axi_awcache;
    wire [2:0]            m01_axi_awprot;
    wire [3:0]            m01_axi_awqos;
    wire [3:0]            m01_axi_awregion;
    wire [0:0]            m01_axi_awuser;
    wire                  m01_axi_awvalid;
    wire                  m01_axi_awready;
    wire [DATA_WIDTH-1:0] m01_axi_wdata;
    wire [STRB_WIDTH-1:0] m01_axi_wstrb;
    wire                  m01_axi_wlast;
    wire [0:0]            m01_axi_wuser;
    wire                  m01_axi_wvalid;
    wire                  m01_axi_wready;
    wire [ID_WIDTH-1:0]   m01_axi_bid;
    wire [1:0]            m01_axi_bresp;
    wire [0:0]            m01_axi_buser;
    wire                  m01_axi_bvalid;
    wire                  m01_axi_bready;
    wire [ID_WIDTH-1:0]   m01_axi_arid;
    wire [ADDR_WIDTH-1:0] m01_axi_araddr;
    wire [7:0]            m01_axi_arlen;
    wire [2:0]            m01_axi_arsize;
    wire [1:0]            m01_axi_arburst;
    wire                  m01_axi_arlock;
    wire [3:0]            m01_axi_arcache;
    wire [2:0]            m01_axi_arprot;
    wire [3:0]            m01_axi_arqos;
    wire [3:0]            m01_axi_arregion;
    wire [0:0]            m01_axi_aruser;
    wire                  m01_axi_arvalid;
    wire                  m01_axi_arready;
    wire [ID_WIDTH-1:0]   m01_axi_rid;
    wire [DATA_WIDTH-1:0] m01_axi_rdata;
    wire [1:0]            m01_axi_rresp;
    wire                  m01_axi_rlast;
    wire [0:0]            m01_axi_ruser;
    wire                  m01_axi_rvalid;
    wire                  m01_axi_rready;

    wire [ID_WIDTH-1:0]   m02_axi_awid;
    wire [ADDR_WIDTH-1:0] m02_axi_awaddr;
    wire [7:0]            m02_axi_awlen;
    wire [2:0]            m02_axi_awsize;
    wire [1:0]            m02_axi_awburst;
    wire                  m02_axi_awlock;
    wire [3:0]            m02_axi_awcache;
    wire [2:0]            m02_axi_awprot;
    wire [3:0]            m02_axi_awqos;
    wire [3:0]            m02_axi_awregion;
    wire [0:0]            m02_axi_awuser;
    wire                  m02_axi_awvalid;
    wire                  m02_axi_awready;
    wire [DATA_WIDTH-1:0] m02_axi_wdata;
    wire [STRB_WIDTH-1:0] m02_axi_wstrb;
    wire                  m02_axi_wlast;
    wire [0:0]            m02_axi_wuser;
    wire                  m02_axi_wvalid;
    wire                  m02_axi_wready;
    wire [ID_WIDTH-1:0]   m02_axi_bid;
    wire [1:0]            m02_axi_bresp;
    wire [0:0]            m02_axi_buser;
    wire                  m02_axi_bvalid;
    wire                  m02_axi_bready;
    wire [ID_WIDTH-1:0]   m02_axi_arid;
    wire [ADDR_WIDTH-1:0] m02_axi_araddr;
    wire [7:0]            m02_axi_arlen;
    wire [2:0]            m02_axi_arsize;
    wire [1:0]            m02_axi_arburst;
    wire                  m02_axi_arlock;
    wire [3:0]            m02_axi_arcache;
    wire [2:0]            m02_axi_arprot;
    wire [3:0]            m02_axi_arqos;
    wire [3:0]            m02_axi_arregion;
    wire [0:0]            m02_axi_aruser;
    wire                  m02_axi_arvalid;
    wire                  m02_axi_arready;
    wire [ID_WIDTH-1:0]   m02_axi_rid;
    wire [DATA_WIDTH-1:0] m02_axi_rdata;
    wire [1:0]            m02_axi_rresp;
    wire                  m02_axi_rlast;
    wire [0:0]            m02_axi_ruser;
    wire                  m02_axi_rvalid;
    wire                  m02_axi_rready;


    /* ============================================================
     * INTERCONNECT M03 <-> FIR AXI4-Lite CONTROL
     *
     * FIR control address window:
     *   0x4000_7000 - 0x4000_7FFF
     *
     * FIR data path is AXI4-Stream and is intentionally left idle
     * here because the current AXI interconnect is memory-mapped.
     * No wrapper is added.
     * ============================================================ */

    wire [ID_WIDTH-1:0]   m03_axi_awid;
    wire [ADDR_WIDTH-1:0] m03_axi_awaddr;
    wire [7:0]            m03_axi_awlen;
    wire [2:0]            m03_axi_awsize;
    wire [1:0]            m03_axi_awburst;
    wire                  m03_axi_awlock;
    wire [3:0]            m03_axi_awcache;
    wire [2:0]            m03_axi_awprot;
    wire [3:0]            m03_axi_awqos;
    wire [3:0]            m03_axi_awregion;
    wire [0:0]            m03_axi_awuser;
    wire                  m03_axi_awvalid;
    wire                  m03_axi_awready;

    wire [DATA_WIDTH-1:0] m03_axi_wdata;
    wire [STRB_WIDTH-1:0] m03_axi_wstrb;
    wire                  m03_axi_wlast;
    wire [0:0]            m03_axi_wuser;
    wire                  m03_axi_wvalid;
    wire                  m03_axi_wready;

    wire [ID_WIDTH-1:0]   m03_axi_bid;
    wire [1:0]            m03_axi_bresp;
    wire [0:0]            m03_axi_buser;
    wire                  m03_axi_bvalid;
    wire                  m03_axi_bready;

    wire [ID_WIDTH-1:0]   m03_axi_arid;
    wire [ADDR_WIDTH-1:0] m03_axi_araddr;
    wire [7:0]            m03_axi_arlen;
    wire [2:0]            m03_axi_arsize;
    wire [1:0]            m03_axi_arburst;
    wire                  m03_axi_arlock;
    wire [3:0]            m03_axi_arcache;
    wire [2:0]            m03_axi_arprot;
    wire [3:0]            m03_axi_arqos;
    wire [3:0]            m03_axi_arregion;
    wire [0:0]            m03_axi_aruser;
    wire                  m03_axi_arvalid;
    wire                  m03_axi_arready;

    wire [ID_WIDTH-1:0]   m03_axi_rid;
    wire [DATA_WIDTH-1:0] m03_axi_rdata;
    wire [1:0]            m03_axi_rresp;
    wire                  m03_axi_rlast;
    wire [0:0]            m03_axi_ruser;
    wire                  m03_axi_rvalid;
    wire                  m03_axi_rready;

    /* ============================================================
     * INTERCONNECT M04 <-> ADC AXI4-Lite CONTROL
     *
     * ADC control address window:
     *   0x4000_3000 - 0x4000_3FFF
     * ============================================================ */

    wire [ID_WIDTH-1:0]   m04_axi_awid;
    wire [ADDR_WIDTH-1:0] m04_axi_awaddr;
    wire [7:0]            m04_axi_awlen;
    wire [2:0]            m04_axi_awsize;
    wire [1:0]            m04_axi_awburst;
    wire                  m04_axi_awlock;
    wire [3:0]            m04_axi_awcache;
    wire [2:0]            m04_axi_awprot;
    wire [3:0]            m04_axi_awqos;
    wire [3:0]            m04_axi_awregion;
    wire [0:0]            m04_axi_awuser;
    wire                  m04_axi_awvalid;
    wire                  m04_axi_awready;

    wire [DATA_WIDTH-1:0] m04_axi_wdata;
    wire [STRB_WIDTH-1:0] m04_axi_wstrb;
    wire                  m04_axi_wlast;
    wire [0:0]            m04_axi_wuser;
    wire                  m04_axi_wvalid;
    wire                  m04_axi_wready;

    wire [ID_WIDTH-1:0]   m04_axi_bid;
    wire [1:0]            m04_axi_bresp;
    wire [0:0]            m04_axi_buser;
    wire                  m04_axi_bvalid;
    wire                  m04_axi_bready;

    wire [ID_WIDTH-1:0]   m04_axi_arid;
    wire [ADDR_WIDTH-1:0] m04_axi_araddr;
    wire [7:0]            m04_axi_arlen;
    wire [2:0]            m04_axi_arsize;
    wire [1:0]            m04_axi_arburst;
    wire                  m04_axi_arlock;
    wire [3:0]            m04_axi_arcache;
    wire [2:0]            m04_axi_arprot;
    wire [3:0]            m04_axi_arqos;
    wire [3:0]            m04_axi_arregion;
    wire [0:0]            m04_axi_aruser;
    wire                  m04_axi_arvalid;
    wire                  m04_axi_arready;

    wire [ID_WIDTH-1:0]   m04_axi_rid;
    wire [DATA_WIDTH-1:0] m04_axi_rdata;
    wire [1:0]            m04_axi_rresp;
    wire                  m04_axi_rlast;
    wire [0:0]            m04_axi_ruser;
    wire                  m04_axi_rvalid;
    wire                  m04_axi_rready;

    wire [ID_WIDTH-1:0]   m05_axi_awid;
    wire [ADDR_WIDTH-1:0] m05_axi_awaddr;
    wire [7:0]            m05_axi_awlen;
    wire [2:0]            m05_axi_awsize;
    wire [1:0]            m05_axi_awburst;
    wire                  m05_axi_awlock;
    wire [3:0]            m05_axi_awcache;
    wire [2:0]            m05_axi_awprot;
    wire [3:0]            m05_axi_awqos;
    wire [3:0]            m05_axi_awregion;
    wire [0:0]            m05_axi_awuser;
    wire                  m05_axi_awvalid;
    wire                  m05_axi_awready;

    wire [DATA_WIDTH-1:0] m05_axi_wdata;
    wire [STRB_WIDTH-1:0] m05_axi_wstrb;
    wire                  m05_axi_wlast;
    wire [0:0]            m05_axi_wuser;
    wire                  m05_axi_wvalid;
    wire                  m05_axi_wready;

    wire [ID_WIDTH-1:0]   m05_axi_bid;
    wire [1:0]            m05_axi_bresp;
    wire [0:0]            m05_axi_buser;
    wire                  m05_axi_bvalid;
    wire                  m05_axi_bready;

    wire [ID_WIDTH-1:0]   m05_axi_arid;
    wire [ADDR_WIDTH-1:0] m05_axi_araddr;
    wire [7:0]            m05_axi_arlen;
    wire [2:0]            m05_axi_arsize;
    wire [1:0]            m05_axi_arburst;
    wire                  m05_axi_arlock;
    wire [3:0]            m05_axi_arcache;
    wire [2:0]            m05_axi_arprot;
    wire [3:0]            m05_axi_arqos;
    wire [3:0]            m05_axi_arregion;
    wire [0:0]            m05_axi_aruser;
    wire                  m05_axi_arvalid;
    wire                  m05_axi_arready;

    wire [ID_WIDTH-1:0]   m05_axi_rid;
    wire [DATA_WIDTH-1:0] m05_axi_rdata;
    wire [1:0]            m05_axi_rresp;
    wire                  m05_axi_rlast;
    wire [0:0]            m05_axi_ruser;
    wire                  m05_axi_rvalid;
    wire                  m05_axi_rready;

    wire [ID_WIDTH-1:0]   m06_axi_awid;
    wire [ADDR_WIDTH-1:0] m06_axi_awaddr;
    wire [7:0]            m06_axi_awlen;
    wire [2:0]            m06_axi_awsize;
    wire [1:0]            m06_axi_awburst;
    wire                  m06_axi_awlock;
    wire [3:0]            m06_axi_awcache;
    wire [2:0]            m06_axi_awprot;
    wire [3:0]            m06_axi_awqos;
    wire [3:0]            m06_axi_awregion;
    wire [0:0]            m06_axi_awuser;
    wire                  m06_axi_awvalid;
    wire                  m06_axi_awready;

    wire [DATA_WIDTH-1:0] m06_axi_wdata;
    wire [STRB_WIDTH-1:0] m06_axi_wstrb;
    wire                  m06_axi_wlast;
    wire [0:0]            m06_axi_wuser;
    wire                  m06_axi_wvalid;
    wire                  m06_axi_wready;

    wire [ID_WIDTH-1:0]   m06_axi_bid;
    wire [1:0]            m06_axi_bresp;
    wire [0:0]            m06_axi_buser;
    wire                  m06_axi_bvalid;
    wire                  m06_axi_bready;

    wire [ID_WIDTH-1:0]   m06_axi_arid;
    wire [ADDR_WIDTH-1:0] m06_axi_araddr;
    wire [7:0]            m06_axi_arlen;
    wire [2:0]            m06_axi_arsize;
    wire [1:0]            m06_axi_arburst;
    wire                  m06_axi_arlock;
    wire [3:0]            m06_axi_arcache;
    wire [2:0]            m06_axi_arprot;
    wire [3:0]            m06_axi_arqos;
    wire [3:0]            m06_axi_arregion;
    wire [0:0]            m06_axi_aruser;
    wire                  m06_axi_arvalid;
    wire                  m06_axi_arready;

    wire [ID_WIDTH-1:0]   m06_axi_rid;
    wire [DATA_WIDTH-1:0] m06_axi_rdata;
    wire [1:0]            m06_axi_rresp;
    wire                  m06_axi_rlast;
    wire [0:0]            m06_axi_ruser;
    wire                  m06_axi_rvalid;
    wire                  m06_axi_rready;

    /* ============================================================
     * AXI INTERCONNECT
     *
     * M00 = UART
     * UART address range:
     *
     * 0x4000_0000 - 0x4000_0FFF
     *
     * M00 = UART
     * M01 = FFT AXI4-Lite control
     * M02 = FFT AXI4 memory window
     * M03 = FIR AXI4-Lite control
     * M04 = ADC AXI4-Lite control
     * M05-M13 remain unused.
     * ============================================================ */

    axi_interconnect_wrap_3x14 #(
        .DATA_WIDTH        (DATA_WIDTH),
        .ADDR_WIDTH        (ADDR_WIDTH),
        .STRB_WIDTH        (STRB_WIDTH),
        .ID_WIDTH          (ID_WIDTH),

        .AWUSER_WIDTH      (1),
        .WUSER_WIDTH       (1),
        .BUSER_WIDTH       (1),
        .ARUSER_WIDTH      (1),
        .RUSER_WIDTH       (1),

        .M_REGIONS         (1),

        /* UART */
        .M00_BASE_ADDR     (32'h4000_0000),
        .M00_ADDR_WIDTH    (32'd12),
        .M00_CONNECT_READ  (3'b001),
        .M00_CONNECT_WRITE (3'b001),

        /* FFT control */
        .M01_BASE_ADDR     (32'h4000_5000),
        .M01_ADDR_WIDTH    (32'd12),
        .M01_CONNECT_READ  (3'b001),
        .M01_CONNECT_WRITE (3'b001),

        /* FFT memory */
        .M02_BASE_ADDR     (32'h4000_6000),
        .M02_ADDR_WIDTH    (32'd12),
        .M02_CONNECT_READ  (3'b001),
        .M02_CONNECT_WRITE (3'b001),

        /* FIR AXI4-Lite control */
        .M03_BASE_ADDR     (32'h4000_7000),
        .M03_ADDR_WIDTH    (32'd12),
        .M03_CONNECT_READ  (3'b001),
        .M03_CONNECT_WRITE (3'b001),

        /* ADC AXI4-Lite control */
        .M04_BASE_ADDR     (32'h4000_3000),
        .M04_ADDR_WIDTH    (32'd12),
        .M04_CONNECT_READ  (3'b001),
        .M04_CONNECT_WRITE (3'b001),

        /* GPIO AXI4-Lite slave */
        .M05_BASE_ADDR     (32'h4000_2000),
        .M05_ADDR_WIDTH    (32'd12),
        .M05_CONNECT_READ  (3'b001),
        .M05_CONNECT_WRITE (3'b001),

        /* Timer AXI4-Lite slave */
        .M06_BASE_ADDR     (32'h4000_1000),
        .M06_ADDR_WIDTH    (32'd12),
        .M06_CONNECT_READ  (3'b001),
        .M06_CONNECT_WRITE (3'b001),

        .M07_ADDR_WIDTH    (32'd0),
        .M07_CONNECT_READ  (3'b000),
        .M07_CONNECT_WRITE (3'b000),

        .M08_ADDR_WIDTH    (32'd0),
        .M08_CONNECT_READ  (3'b000),
        .M08_CONNECT_WRITE (3'b000),

        .M09_ADDR_WIDTH    (32'd0),
        .M09_CONNECT_READ  (3'b000),
        .M09_CONNECT_WRITE (3'b000),

        .M10_ADDR_WIDTH    (32'd0),
        .M10_CONNECT_READ  (3'b000),
        .M10_CONNECT_WRITE (3'b000),

        .M11_ADDR_WIDTH    (32'd0),
        .M11_CONNECT_READ  (3'b000),
        .M11_CONNECT_WRITE (3'b000),

        .M12_ADDR_WIDTH    (32'd0),
        .M12_CONNECT_READ  (3'b000),
        .M12_CONNECT_WRITE (3'b000),

        .M13_ADDR_WIDTH    (32'd0),
        .M13_CONNECT_READ  (3'b000),
        .M13_CONNECT_WRITE (3'b000)

    ) u_interconnect (

        .clk              (clk),
        .rst              (rst),

        /* ========================================================
         * S00 ACTIVE
         * ======================================================== */

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


        /* ========================================================
         * S01 INACTIVE
         * ======================================================== */

        .s01_axi_awid     (8'd0),
        .s01_axi_awaddr   (32'd0),
        .s01_axi_awlen    (8'd0),
        .s01_axi_awsize   (3'd0),
        .s01_axi_awburst  (2'd0),
        .s01_axi_awlock   (1'b0),
        .s01_axi_awcache  (4'd0),
        .s01_axi_awprot   (3'd0),
        .s01_axi_awqos    (4'd0),
        .s01_axi_awuser   (1'b0),
        .s01_axi_awvalid  (1'b0),

        .s01_axi_wdata    (32'd0),
        .s01_axi_wstrb    (4'd0),
        .s01_axi_wlast    (1'b0),
        .s01_axi_wuser    (1'b0),
        .s01_axi_wvalid   (1'b0),
        .s01_axi_bready   (1'b0),

        .s01_axi_arid     (8'd0),
        .s01_axi_araddr   (32'd0),
        .s01_axi_arlen    (8'd0),
        .s01_axi_arsize   (3'd0),
        .s01_axi_arburst  (2'd0),
        .s01_axi_arlock   (1'b0),
        .s01_axi_arcache  (4'd0),
        .s01_axi_arprot   (3'd0),
        .s01_axi_arqos    (4'd0),
        .s01_axi_aruser   (1'b0),
        .s01_axi_arvalid  (1'b0),
        .s01_axi_rready   (1'b0),


        /* ========================================================
         * S02 INACTIVE
         * ======================================================== */

        .s02_axi_awid     (8'd0),
        .s02_axi_awaddr   (32'd0),
        .s02_axi_awlen    (8'd0),
        .s02_axi_awsize   (3'd0),
        .s02_axi_awburst  (2'd0),
        .s02_axi_awlock   (1'b0),
        .s02_axi_awcache  (4'd0),
        .s02_axi_awprot   (3'd0),
        .s02_axi_awqos    (4'd0),
        .s02_axi_awuser   (1'b0),
        .s02_axi_awvalid  (1'b0),

        .s02_axi_wdata    (32'd0),
        .s02_axi_wstrb    (4'd0),
        .s02_axi_wlast    (1'b0),
        .s02_axi_wuser    (1'b0),
        .s02_axi_wvalid   (1'b0),
        .s02_axi_bready   (1'b0),

        .s02_axi_arid     (8'd0),
        .s02_axi_araddr   (32'd0),
        .s02_axi_arlen    (8'd0),
        .s02_axi_arsize   (3'd0),
        .s02_axi_arburst  (2'd0),
        .s02_axi_arlock   (1'b0),
        .s02_axi_arcache  (4'd0),
        .s02_axi_arprot   (3'd0),
        .s02_axi_arqos    (4'd0),
        .s02_axi_aruser   (1'b0),
        .s02_axi_arvalid  (1'b0),
        .s02_axi_rready   (1'b0),


        /* ========================================================
         * M00 ACTIVE -> UART
         * ======================================================== */

        .m00_axi_awid     (m00_axi_awid),
        .m00_axi_awaddr   (m00_axi_awaddr),
        .m00_axi_awlen    (m00_axi_awlen),
        .m00_axi_awsize   (m00_axi_awsize),
        .m00_axi_awburst  (m00_axi_awburst),
        .m00_axi_awlock   (m00_axi_awlock),
        .m00_axi_awcache  (m00_axi_awcache),
        .m00_axi_awprot   (m00_axi_awprot),
        .m00_axi_awqos    (m00_axi_awqos),
        .m00_axi_awregion (m00_axi_awregion),
        .m00_axi_awuser   (m00_axi_awuser),
        .m00_axi_awvalid  (m00_axi_awvalid),
        .m00_axi_awready  (m00_axi_awready),

        .m00_axi_wdata    (m00_axi_wdata),
        .m00_axi_wstrb    (m00_axi_wstrb),
        .m00_axi_wlast    (m00_axi_wlast),
        .m00_axi_wuser    (m00_axi_wuser),
        .m00_axi_wvalid   (m00_axi_wvalid),
        .m00_axi_wready   (m00_axi_wready),

        .m00_axi_bid      (m00_axi_bid),
        .m00_axi_bresp    (m00_axi_bresp),
        .m00_axi_buser    (m00_axi_buser),
        .m00_axi_bvalid   (m00_axi_bvalid),
        .m00_axi_bready   (m00_axi_bready),

        .m00_axi_arid     (m00_axi_arid),
        .m00_axi_araddr   (m00_axi_araddr),
        .m00_axi_arlen    (m00_axi_arlen),
        .m00_axi_arsize   (m00_axi_arsize),
        .m00_axi_arburst  (m00_axi_arburst),
        .m00_axi_arlock   (m00_axi_arlock),
        .m00_axi_arcache  (m00_axi_arcache),
        .m00_axi_arprot   (m00_axi_arprot),
        .m00_axi_arqos    (m00_axi_arqos),
        .m00_axi_arregion (m00_axi_arregion),
        .m00_axi_aruser   (m00_axi_aruser),
        .m00_axi_arvalid  (m00_axi_arvalid),
        .m00_axi_arready  (m00_axi_arready),

        .m00_axi_rid      (m00_axi_rid),
        .m00_axi_rdata    (m00_axi_rdata),
        .m00_axi_rresp    (m00_axi_rresp),
        .m00_axi_rlast    (m00_axi_rlast),
        .m00_axi_ruser    (m00_axi_ruser),
        .m00_axi_rvalid   (m00_axi_rvalid),
        .m00_axi_rready   (m00_axi_rready),

        /* M01 ACTIVE */
        .m01_axi_awid    (m01_axi_awid),
        .m01_axi_awaddr  (m01_axi_awaddr),
        .m01_axi_awlen   (m01_axi_awlen),
        .m01_axi_awsize  (m01_axi_awsize),
        .m01_axi_awburst (m01_axi_awburst),
        .m01_axi_awlock  (m01_axi_awlock),
        .m01_axi_awcache (m01_axi_awcache),
        .m01_axi_awprot  (m01_axi_awprot),
        .m01_axi_awqos   (m01_axi_awqos),
        .m01_axi_awregion (m01_axi_awregion),
        .m01_axi_awuser  (m01_axi_awuser),
        .m01_axi_awvalid (m01_axi_awvalid),
        .m01_axi_awready (m01_axi_awready),
        .m01_axi_wdata   (m01_axi_wdata),
        .m01_axi_wstrb   (m01_axi_wstrb),
        .m01_axi_wlast   (m01_axi_wlast),
        .m01_axi_wuser   (m01_axi_wuser),
        .m01_axi_wvalid  (m01_axi_wvalid),
        .m01_axi_wready  (m01_axi_wready),
        .m01_axi_bid     (m01_axi_bid),
        .m01_axi_bresp   (m01_axi_bresp),
        .m01_axi_buser   (m01_axi_buser),
        .m01_axi_bvalid  (m01_axi_bvalid),
        .m01_axi_bready  (m01_axi_bready),
        .m01_axi_arid    (m01_axi_arid),
        .m01_axi_araddr  (m01_axi_araddr),
        .m01_axi_arlen   (m01_axi_arlen),
        .m01_axi_arsize  (m01_axi_arsize),
        .m01_axi_arburst (m01_axi_arburst),
        .m01_axi_arlock  (m01_axi_arlock),
        .m01_axi_arcache (m01_axi_arcache),
        .m01_axi_arprot  (m01_axi_arprot),
        .m01_axi_arqos   (m01_axi_arqos),
        .m01_axi_arregion (m01_axi_arregion),
        .m01_axi_aruser  (m01_axi_aruser),
        .m01_axi_arvalid (m01_axi_arvalid),
        .m01_axi_arready (m01_axi_arready),
        .m01_axi_rid     (m01_axi_rid),
        .m01_axi_rdata   (m01_axi_rdata),
        .m01_axi_rresp   (m01_axi_rresp),
        .m01_axi_rlast   (m01_axi_rlast),
        .m01_axi_ruser   (m01_axi_ruser),
        .m01_axi_rvalid  (m01_axi_rvalid),
        .m01_axi_rready  (m01_axi_rready),

        /* M02 ACTIVE */
        .m02_axi_awid    (m02_axi_awid),
        .m02_axi_awaddr  (m02_axi_awaddr),
        .m02_axi_awlen   (m02_axi_awlen),
        .m02_axi_awsize  (m02_axi_awsize),
        .m02_axi_awburst (m02_axi_awburst),
        .m02_axi_awlock  (m02_axi_awlock),
        .m02_axi_awcache (m02_axi_awcache),
        .m02_axi_awprot  (m02_axi_awprot),
        .m02_axi_awqos   (m02_axi_awqos),
        .m02_axi_awregion (m02_axi_awregion),
        .m02_axi_awuser  (m02_axi_awuser),
        .m02_axi_awvalid (m02_axi_awvalid),
        .m02_axi_awready (m02_axi_awready),
        .m02_axi_wdata   (m02_axi_wdata),
        .m02_axi_wstrb   (m02_axi_wstrb),
        .m02_axi_wlast   (m02_axi_wlast),
        .m02_axi_wuser   (m02_axi_wuser),
        .m02_axi_wvalid  (m02_axi_wvalid),
        .m02_axi_wready  (m02_axi_wready),
        .m02_axi_bid     (m02_axi_bid),
        .m02_axi_bresp   (m02_axi_bresp),
        .m02_axi_buser   (m02_axi_buser),
        .m02_axi_bvalid  (m02_axi_bvalid),
        .m02_axi_bready  (m02_axi_bready),
        .m02_axi_arid    (m02_axi_arid),
        .m02_axi_araddr  (m02_axi_araddr),
        .m02_axi_arlen   (m02_axi_arlen),
        .m02_axi_arsize  (m02_axi_arsize),
        .m02_axi_arburst (m02_axi_arburst),
        .m02_axi_arlock  (m02_axi_arlock),
        .m02_axi_arcache (m02_axi_arcache),
        .m02_axi_arprot  (m02_axi_arprot),
        .m02_axi_arqos   (m02_axi_arqos),
        .m02_axi_arregion (m02_axi_arregion),
        .m02_axi_aruser  (m02_axi_aruser),
        .m02_axi_arvalid (m02_axi_arvalid),
        .m02_axi_arready (m02_axi_arready),
        .m02_axi_rid     (m02_axi_rid),
        .m02_axi_rdata   (m02_axi_rdata),
        .m02_axi_rresp   (m02_axi_rresp),
        .m02_axi_rlast   (m02_axi_rlast),
        .m02_axi_ruser   (m02_axi_ruser),
        .m02_axi_rvalid  (m02_axi_rvalid),
        .m02_axi_rready  (m02_axi_rready),


        /* ========================================================
         * M03 ACTIVE -> FIR AXI4-Lite CONTROL
         * ======================================================== */

        .m03_axi_awid     (m03_axi_awid),
        .m03_axi_awaddr   (m03_axi_awaddr),
        .m03_axi_awlen    (m03_axi_awlen),
        .m03_axi_awsize   (m03_axi_awsize),
        .m03_axi_awburst  (m03_axi_awburst),
        .m03_axi_awlock   (m03_axi_awlock),
        .m03_axi_awcache  (m03_axi_awcache),
        .m03_axi_awprot   (m03_axi_awprot),
        .m03_axi_awqos    (m03_axi_awqos),
        .m03_axi_awregion (m03_axi_awregion),
        .m03_axi_awuser   (m03_axi_awuser),
        .m03_axi_awvalid  (m03_axi_awvalid),
        .m03_axi_awready  (m03_axi_awready),

        .m03_axi_wdata   (m03_axi_wdata),
        .m03_axi_wstrb   (m03_axi_wstrb),
        .m03_axi_wlast   (m03_axi_wlast),
        .m03_axi_wuser   (m03_axi_wuser),
        .m03_axi_wvalid  (m03_axi_wvalid),
        .m03_axi_wready  (m03_axi_wready),

        .m03_axi_bid     (m03_axi_bid),
        .m03_axi_bresp   (m03_axi_bresp),
        .m03_axi_buser   (m03_axi_buser),
        .m03_axi_bvalid  (m03_axi_bvalid),
        .m03_axi_bready  (m03_axi_bready),

        .m03_axi_arid    (m03_axi_arid),
        .m03_axi_araddr  (m03_axi_araddr),
        .m03_axi_arlen   (m03_axi_arlen),
        .m03_axi_arsize  (m03_axi_arsize),
        .m03_axi_arburst (m03_axi_arburst),
        .m03_axi_arlock  (m03_axi_arlock),
        .m03_axi_arcache (m03_axi_arcache),
        .m03_axi_arprot  (m03_axi_arprot),
        .m03_axi_arqos   (m03_axi_arqos),
        .m03_axi_arregion(m03_axi_arregion),
        .m03_axi_aruser  (m03_axi_aruser),
        .m03_axi_arvalid (m03_axi_arvalid),
        .m03_axi_arready (m03_axi_arready),

        .m03_axi_rid     (m03_axi_rid),
        .m03_axi_rdata   (m03_axi_rdata),
        .m03_axi_rresp   (m03_axi_rresp),
        .m03_axi_rlast   (m03_axi_rlast),
        .m03_axi_ruser   (m03_axi_ruser),
        .m03_axi_rvalid  (m03_axi_rvalid),
        .m03_axi_rready  (m03_axi_rready),

        /* ========================================================
         * M04 ACTIVE -> ADC AXI4-Lite CONTROL
         * ======================================================== */

        .m04_axi_awid     (m04_axi_awid),
        .m04_axi_awaddr   (m04_axi_awaddr),
        .m04_axi_awlen    (m04_axi_awlen),
        .m04_axi_awsize   (m04_axi_awsize),
        .m04_axi_awburst  (m04_axi_awburst),
        .m04_axi_awlock   (m04_axi_awlock),
        .m04_axi_awcache  (m04_axi_awcache),
        .m04_axi_awprot   (m04_axi_awprot),
        .m04_axi_awqos    (m04_axi_awqos),
        .m04_axi_awregion (m04_axi_awregion),
        .m04_axi_awuser   (m04_axi_awuser),
        .m04_axi_awvalid  (m04_axi_awvalid),
        .m04_axi_awready  (m04_axi_awready),

        .m04_axi_wdata   (m04_axi_wdata),
        .m04_axi_wstrb   (m04_axi_wstrb),
        .m04_axi_wlast   (m04_axi_wlast),
        .m04_axi_wuser   (m04_axi_wuser),
        .m04_axi_wvalid  (m04_axi_wvalid),
        .m04_axi_wready  (m04_axi_wready),

        .m04_axi_bid     (m04_axi_bid),
        .m04_axi_bresp   (m04_axi_bresp),
        .m04_axi_buser   (m04_axi_buser),
        .m04_axi_bvalid  (m04_axi_bvalid),
        .m04_axi_bready  (m04_axi_bready),

        .m04_axi_arid    (m04_axi_arid),
        .m04_axi_araddr  (m04_axi_araddr),
        .m04_axi_arlen   (m04_axi_arlen),
        .m04_axi_arsize  (m04_axi_arsize),
        .m04_axi_arburst (m04_axi_arburst),
        .m04_axi_arlock  (m04_axi_arlock),
        .m04_axi_arcache (m04_axi_arcache),
        .m04_axi_arprot  (m04_axi_arprot),
        .m04_axi_arqos   (m04_axi_arqos),
        .m04_axi_arregion(m04_axi_arregion),
        .m04_axi_aruser  (m04_axi_aruser),
        .m04_axi_arvalid (m04_axi_arvalid),
        .m04_axi_arready (m04_axi_arready),

        .m04_axi_rid     (m04_axi_rid),
        .m04_axi_rdata   (m04_axi_rdata),
        .m04_axi_rresp   (m04_axi_rresp),
        .m04_axi_rlast   (m04_axi_rlast),
        .m04_axi_ruser   (m04_axi_ruser),
        .m04_axi_rvalid  (m04_axi_rvalid),
        .m04_axi_rready  (m04_axi_rready),

        /* M05 ACTIVE -> GPIO AXI4-Lite */
        .m05_axi_awid     (m05_axi_awid),
        .m05_axi_awaddr   (m05_axi_awaddr),
        .m05_axi_awlen    (m05_axi_awlen),
        .m05_axi_awsize   (m05_axi_awsize),
        .m05_axi_awburst  (m05_axi_awburst),
        .m05_axi_awlock   (m05_axi_awlock),
        .m05_axi_awcache  (m05_axi_awcache),
        .m05_axi_awprot   (m05_axi_awprot),
        .m05_axi_awqos    (m05_axi_awqos),
        .m05_axi_awregion (m05_axi_awregion),
        .m05_axi_awuser   (m05_axi_awuser),
        .m05_axi_awvalid  (m05_axi_awvalid),
        .m05_axi_awready  (m05_axi_awready),

        .m05_axi_wdata   (m05_axi_wdata),
        .m05_axi_wstrb   (m05_axi_wstrb),
        .m05_axi_wlast   (m05_axi_wlast),
        .m05_axi_wuser   (m05_axi_wuser),
        .m05_axi_wvalid  (m05_axi_wvalid),
        .m05_axi_wready  (m05_axi_wready),

        .m05_axi_bid     (m05_axi_bid),
        .m05_axi_bresp   (m05_axi_bresp),
        .m05_axi_buser   (m05_axi_buser),
        .m05_axi_bvalid  (m05_axi_bvalid),
        .m05_axi_bready  (m05_axi_bready),

        .m05_axi_arid    (m05_axi_arid),
        .m05_axi_araddr  (m05_axi_araddr),
        .m05_axi_arlen   (m05_axi_arlen),
        .m05_axi_arsize  (m05_axi_arsize),
        .m05_axi_arburst (m05_axi_arburst),
        .m05_axi_arlock  (m05_axi_arlock),
        .m05_axi_arcache (m05_axi_arcache),
        .m05_axi_arprot  (m05_axi_arprot),
        .m05_axi_arqos   (m05_axi_arqos),
        .m05_axi_arregion(m05_axi_arregion),
        .m05_axi_aruser  (m05_axi_aruser),
        .m05_axi_arvalid (m05_axi_arvalid),
        .m05_axi_arready (m05_axi_arready),

        .m05_axi_rid     (m05_axi_rid),
        .m05_axi_rdata   (m05_axi_rdata),
        .m05_axi_rresp   (m05_axi_rresp),
        .m05_axi_rlast   (m05_axi_rlast),
        .m05_axi_ruser   (m05_axi_ruser),
        .m05_axi_rvalid  (m05_axi_rvalid),
        .m05_axi_rready  (m05_axi_rready),

        /* M06 ACTIVE -> TIMER AXI4-Lite */
        .m06_axi_awid     (m06_axi_awid),
        .m06_axi_awaddr   (m06_axi_awaddr),
        .m06_axi_awlen    (m06_axi_awlen),
        .m06_axi_awsize   (m06_axi_awsize),
        .m06_axi_awburst  (m06_axi_awburst),
        .m06_axi_awlock   (m06_axi_awlock),
        .m06_axi_awcache  (m06_axi_awcache),
        .m06_axi_awprot   (m06_axi_awprot),
        .m06_axi_awqos    (m06_axi_awqos),
        .m06_axi_awregion (m06_axi_awregion),
        .m06_axi_awuser   (m06_axi_awuser),
        .m06_axi_awvalid  (m06_axi_awvalid),
        .m06_axi_awready  (m06_axi_awready),

        .m06_axi_wdata   (m06_axi_wdata),
        .m06_axi_wstrb   (m06_axi_wstrb),
        .m06_axi_wlast   (m06_axi_wlast),
        .m06_axi_wuser   (m06_axi_wuser),
        .m06_axi_wvalid  (m06_axi_wvalid),
        .m06_axi_wready  (m06_axi_wready),

        .m06_axi_bid     (m06_axi_bid),
        .m06_axi_bresp   (m06_axi_bresp),
        .m06_axi_buser   (m06_axi_buser),
        .m06_axi_bvalid  (m06_axi_bvalid),
        .m06_axi_bready  (m06_axi_bready),

        .m06_axi_arid    (m06_axi_arid),
        .m06_axi_araddr  (m06_axi_araddr),
        .m06_axi_arlen   (m06_axi_arlen),
        .m06_axi_arsize  (m06_axi_arsize),
        .m06_axi_arburst (m06_axi_arburst),
        .m06_axi_arlock  (m06_axi_arlock),
        .m06_axi_arcache (m06_axi_arcache),
        .m06_axi_arprot  (m06_axi_arprot),
        .m06_axi_arqos   (m06_axi_arqos),
        .m06_axi_arregion(m06_axi_arregion),
        .m06_axi_aruser  (m06_axi_aruser),
        .m06_axi_arvalid (m06_axi_arvalid),
        .m06_axi_arready (m06_axi_arready),

        .m06_axi_rid     (m06_axi_rid),
        .m06_axi_rdata   (m06_axi_rdata),
        .m06_axi_rresp   (m06_axi_rresp),
        .m06_axi_rlast   (m06_axi_rlast),
        .m06_axi_ruser   (m06_axi_ruser),
        .m06_axi_rvalid  (m06_axi_rvalid),
        .m06_axi_rready  (m06_axi_rready)

    );


    /* ============================================================
     * UART
     *
     * Interconnect ID = 8 bits
     * UART ID         = 12 bits
     *
     * Therefore IDs are zero-extended toward UART and the lower
     * 8 bits are returned to the interconnect.
     * ============================================================ */

    wire [11:0] uart_axi_arid;
    wire [4:0]  uart_axi_araddr;
    wire        uart_axi_arvalid;
    wire        uart_axi_arready;

    wire [11:0] uart_axi_rid;
    wire [31:0] uart_axi_rdata;
    wire [1:0]  uart_axi_rresp;
    wire        uart_axi_rvalid;
    wire        uart_axi_rready;

    wire [11:0] uart_axi_awid;
    wire [4:0]  uart_axi_awaddr;
    wire        uart_axi_awvalid;
    wire        uart_axi_awready;

    wire [31:0] uart_axi_wdata;
    wire [3:0]  uart_axi_wstrb;
    wire        uart_axi_wvalid;
    wire        uart_axi_wready;

    wire [11:0] uart_axi_bid;
    wire [1:0]  uart_axi_bresp;
    wire        uart_axi_bvalid;
    wire        uart_axi_bready;

    wire uart_read_interrupt;


    /* ---------------- READ ADDRESS ---------------- */

    assign uart_axi_arid    = {4'b0000, m00_axi_arid};
    assign uart_axi_araddr  = m00_axi_araddr[4:0];
    assign uart_axi_arvalid = m00_axi_arvalid;

    assign m00_axi_arready  = uart_axi_arready;


    /* ---------------- READ RESPONSE ---------------- */

    assign m00_axi_rid     = uart_axi_rid[7:0];
    assign m00_axi_rdata   = uart_axi_rdata;
    assign m00_axi_rresp   = uart_axi_rresp;

    /* UART is AXI4-Lite, therefore every response is one beat. */
    assign m00_axi_rlast   = 1'b1;

    assign m00_axi_ruser   = 1'b0;
    assign m00_axi_rvalid  = uart_axi_rvalid;

    assign uart_axi_rready = m00_axi_rready;


    /* ---------------- WRITE ADDRESS ---------------- */

    assign uart_axi_awid    = {4'b0000, m00_axi_awid};
    assign uart_axi_awaddr  = m00_axi_awaddr[4:0];
    assign uart_axi_awvalid = m00_axi_awvalid;

    assign m00_axi_awready  = uart_axi_awready;


    /* ---------------- WRITE DATA ---------------- */

    assign uart_axi_wdata   = m00_axi_wdata;
    assign uart_axi_wstrb   = m00_axi_wstrb;
    assign uart_axi_wvalid  = m00_axi_wvalid;

    assign m00_axi_wready   = uart_axi_wready;


    /* ---------------- WRITE RESPONSE ---------------- */

    assign m00_axi_bid      = uart_axi_bid[7:0];
    assign m00_axi_bresp    = uart_axi_bresp;
    assign m00_axi_buser    = 1'b0;
    assign m00_axi_bvalid   = uart_axi_bvalid;

    assign uart_axi_bready  = m00_axi_bready;


    /* ============================================================
     * UART INSTANCE
     * Exact port names taken from the supplied axi_uart_top.v
     * ============================================================ */

    axi_uart_top u_uart (

        .fixed_clk_i       (clk),
        .axi_aclk_i        (clk),
        .axi_aresetn_i     (~rst),

        .axi_arid_i        (uart_axi_arid),
        .axi_araddr_i      (uart_axi_araddr),
        .axi_arvalid_i     (uart_axi_arvalid),
        .axi_arready_o     (uart_axi_arready),

        .axi_rid_o         (uart_axi_rid),
        .axi_rdata_o       (uart_axi_rdata),
        .axi_rresp_o       (uart_axi_rresp),
        .axi_rvalid_o      (uart_axi_rvalid),
        .axi_rready_i      (uart_axi_rready),

        .axi_awid_i        (uart_axi_awid),
        .axi_awaddr_i      (uart_axi_awaddr),
        .axi_awvalid_i     (uart_axi_awvalid),
        .axi_awready_o     (uart_axi_awready),

        .axi_wdata_i       (uart_axi_wdata),
        .axi_wstrb_i       (uart_axi_wstrb),
        .axi_wvalid_i      (uart_axi_wvalid),
        .axi_wready_o      (uart_axi_wready),

        .axi_bid_o         (uart_axi_bid),
        .axi_bresp_o       (uart_axi_bresp),
        .axi_bvalid_o      (uart_axi_bvalid),
        .axi_bready_i      (uart_axi_bready),

        .read_interrupt_o  (uart_read_interrupt),

        .uart_rx_i         (uart_rx_i),
        .uart_tx_o         (uart_tx_o)
    );


    /* ============================================================
     * FFT ACCELERATOR INTEGRATION
     *
     * M01: AXI4 -> AXI4-Lite control conversion by direct wiring.
     * M02: AXI4 memory interface with global SoC addresses translated
     *      to the NEXHUS 16-bit local address space.
     *
     * Global address map:
     *   UART       : 0x4000_0000 - 0x4000_0FFF
     *   FFT CTRL   : 0x4000_5000 - 0x4000_5FFF
     *   FFT MEMORY : 0x4000_6000 - 0x4000_6FFF
     * ============================================================ */

    /* ---------------- FFT AXI4-Lite control ---------------- */
    wire [15:0] fft_axil_awaddr;
    wire        fft_axil_awvalid;
    wire        fft_axil_awready;
    wire [31:0] fft_axil_wdata;
    wire [3:0]  fft_axil_wstrb;
    wire        fft_axil_wvalid;
    wire        fft_axil_wready;
    wire [1:0]  fft_axil_bresp;
    wire        fft_axil_bvalid;
    wire        fft_axil_bready;
    wire [15:0] fft_axil_araddr;
    wire        fft_axil_arvalid;
    wire        fft_axil_arready;
    wire [31:0] fft_axil_rdata;
    wire [1:0]  fft_axil_rresp;
    wire        fft_axil_rvalid;
    wire        fft_axil_rready;

    reg [ID_WIDTH-1:0] fft_ctrl_awid_reg;
    reg [ID_WIDTH-1:0] fft_ctrl_arid_reg;

    always @(posedge clk) begin
        if (rst) begin
            fft_ctrl_awid_reg <= {ID_WIDTH{1'b0}};
            fft_ctrl_arid_reg <= {ID_WIDTH{1'b0}};
        end
        else begin
            if (m01_axi_awvalid && m01_axi_awready)
                fft_ctrl_awid_reg <= m01_axi_awid;
            if (m01_axi_arvalid && m01_axi_arready)
                fft_ctrl_arid_reg <= m01_axi_arid;
        end
    end

    assign fft_axil_awaddr  = m01_axi_awaddr[15:0] - 16'h5000;
    assign fft_axil_awvalid = m01_axi_awvalid;
    assign m01_axi_awready  = fft_axil_awready;
    assign fft_axil_wdata   = m01_axi_wdata;
    assign fft_axil_wstrb   = m01_axi_wstrb;
    assign fft_axil_wvalid  = m01_axi_wvalid;
    assign m01_axi_wready   = fft_axil_wready;
    assign m01_axi_bresp    = fft_axil_bresp;
    assign m01_axi_bvalid   = fft_axil_bvalid;
    assign m01_axi_bid      = fft_ctrl_awid_reg;
    assign m01_axi_buser    = 1'b0;
    assign m01_axi_bready   = fft_axil_bready;
    assign fft_axil_araddr  = m01_axi_araddr[15:0] - 16'h5000;
    assign fft_axil_arvalid = m01_axi_arvalid;
    assign m01_axi_arready  = fft_axil_arready;
    assign m01_axi_rid      = fft_ctrl_arid_reg;
    assign m01_axi_rdata    = fft_axil_rdata;
    assign m01_axi_rresp    = fft_axil_rresp;
    assign m01_axi_rlast    = 1'b1;
    assign m01_axi_ruser    = 1'b0;
    assign m01_axi_rvalid   = fft_axil_rvalid;
    assign fft_axil_rready  = m01_axi_rready;

    /* ---------------- FFT AXI4 memory ---------------- */
    wire [3:0]  fft_mem_awid;
    wire [15:0] fft_mem_awaddr;
    wire [7:0]  fft_mem_awlen;
    wire [2:0]  fft_mem_awsize;
    wire [1:0]  fft_mem_awburst;
    wire        fft_mem_awvalid;
    wire        fft_mem_awready;
    wire [31:0] fft_mem_wdata;
    wire [3:0]  fft_mem_wstrb;
    wire        fft_mem_wlast;
    wire        fft_mem_wvalid;
    wire        fft_mem_wready;
    wire [3:0]  fft_mem_bid;
    wire [1:0]  fft_mem_bresp;
    wire        fft_mem_bvalid;
    wire        fft_mem_bready;
    wire [3:0]  fft_mem_arid;
    wire [15:0] fft_mem_araddr;
    wire [7:0]  fft_mem_arlen;
    wire [2:0]  fft_mem_arsize;
    wire [1:0]  fft_mem_arburst;
    wire        fft_mem_arvalid;
    wire        fft_mem_arready;
    wire [3:0]  fft_mem_rid;
    wire [31:0] fft_mem_rdata;
    wire [1:0]  fft_mem_rresp;
    wire        fft_mem_rlast;
    wire        fft_mem_rvalid;
    wire        fft_mem_rready;

    assign fft_mem_awid     = m02_axi_awid[3:0];
    assign fft_mem_awaddr   = m02_axi_awaddr[15:0] - 16'h5000;
    assign fft_mem_awlen    = m02_axi_awlen;
    assign fft_mem_awsize   = m02_axi_awsize;
    assign fft_mem_awburst  = m02_axi_awburst;
    assign fft_mem_awvalid  = m02_axi_awvalid;
    assign m02_axi_awready  = fft_mem_awready;
    assign fft_mem_wdata    = m02_axi_wdata;
    assign fft_mem_wstrb    = m02_axi_wstrb;
    assign fft_mem_wlast    = m02_axi_wlast;
    assign fft_mem_wvalid   = m02_axi_wvalid;
    assign m02_axi_wready   = fft_mem_wready;
    assign m02_axi_bid      = {{(ID_WIDTH-4){1'b0}}, fft_mem_bid};
    assign m02_axi_bresp    = fft_mem_bresp;
    assign m02_axi_buser    = 1'b0;
    assign m02_axi_bvalid   = fft_mem_bvalid;
    assign fft_mem_bready   = m02_axi_bready;
    assign fft_mem_arid     = m02_axi_arid[3:0];
    assign fft_mem_araddr   = m02_axi_araddr[15:0] - 16'h5000;
    assign fft_mem_arlen    = m02_axi_arlen;
    assign fft_mem_arsize   = m02_axi_arsize;
    assign fft_mem_arburst  = m02_axi_arburst;
    assign fft_mem_arvalid  = m02_axi_arvalid;
    assign m02_axi_arready  = fft_mem_arready;
    assign m02_axi_rid      = {{(ID_WIDTH-4){1'b0}}, fft_mem_rid};
    assign m02_axi_rdata    = fft_mem_rdata;
    assign m02_axi_rresp    = fft_mem_rresp;
    assign m02_axi_rlast    = fft_mem_rlast;
    assign m02_axi_ruser    = 1'b0;
    assign m02_axi_rvalid   = fft_mem_rvalid;
    assign fft_mem_rready   = m02_axi_rready;

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
        .S_AXI_BID     (fft_mem_bid),
        .S_AXI_BRESP   (fft_mem_bresp),
        .S_AXI_BVALID  (fft_mem_bvalid),
        .S_AXI_BREADY  (fft_mem_bready),
        .S_AXI_ARID    (fft_mem_arid),
        .S_AXI_ARADDR  (fft_mem_araddr),
        .S_AXI_ARLEN   (fft_mem_arlen),
        .S_AXI_ARSIZE  (fft_mem_arsize),
        .S_AXI_ARBURST (fft_mem_arburst),
        .S_AXI_ARVALID (fft_mem_arvalid),
        .S_AXI_ARREADY (fft_mem_arready),
        .S_AXI_RID     (fft_mem_rid),
        .S_AXI_RDATA   (fft_mem_rdata),
        .S_AXI_RRESP   (fft_mem_rresp),
        .S_AXI_RLAST   (fft_mem_rlast),
        .S_AXI_RVALID  (fft_mem_rvalid),
        .S_AXI_RREADY  (fft_mem_rready)
    );


    /* ============================================================
     * ADC AXI4-Lite CONTROL INTEGRATION
     *
     * M04: AXI4 -> AXI4-Lite control conversion by direct wiring.
     *
     * Global ADC address window:
     *   0x4000_3000 - 0x4000_3FFF
     *
     * ADC sample input is exposed at the SoC top level for
     * integration-testbench/sample-source driving.
     * ============================================================ */

    wire [31:0] adc_axil_awaddr;
    wire        adc_axil_awvalid;
    wire        adc_axil_awready;
    wire [31:0] adc_axil_wdata;
    wire [3:0]  adc_axil_wstrb;
    wire        adc_axil_wvalid;
    wire        adc_axil_wready;
    wire        adc_axil_bvalid;
    wire [1:0]  adc_axil_bresp;
    wire        adc_axil_bready;
    wire [31:0] adc_axil_araddr;
    wire        adc_axil_arvalid;
    wire        adc_axil_arready;
    wire [31:0] adc_axil_rdata;
    wire        adc_axil_rvalid;
    wire [1:0]  adc_axil_rresp;
    wire        adc_axil_rready;

    reg [ID_WIDTH-1:0] adc_ctrl_awid_reg;
    reg [ID_WIDTH-1:0] adc_ctrl_arid_reg;

    always @(posedge clk) begin
        if (rst) begin
            adc_ctrl_awid_reg <= {ID_WIDTH{1'b0}};
            adc_ctrl_arid_reg <= {ID_WIDTH{1'b0}};
        end
        else begin
            if (m04_axi_awvalid && m04_axi_awready)
                adc_ctrl_awid_reg <= m04_axi_awid;

            if (m04_axi_arvalid && m04_axi_arready)
                adc_ctrl_arid_reg <= m04_axi_arid;
        end
    end

    /*
     * ADC address handling:
     *
     * The ADC controller expects the ABSOLUTE AXI address because
     * adc_controller internally computes:
     *
     *     register_offset = reg_axi_address - BASE_ADDR
     *
     * Therefore, unlike the FIR adapter, do NOT subtract 0x4000_3000
     * here. Pass the interconnect address directly to the ADC.
     */
    assign adc_axil_awaddr  = m04_axi_awaddr;
    assign adc_axil_awvalid = m04_axi_awvalid;
    assign m04_axi_awready  = adc_axil_awready;

    assign adc_axil_wdata   = m04_axi_wdata;
    assign adc_axil_wstrb   = m04_axi_wstrb;
    assign adc_axil_wvalid  = m04_axi_wvalid;
    assign m04_axi_wready   = adc_axil_wready;

    assign m04_axi_bid      = adc_ctrl_awid_reg;
    assign m04_axi_bresp    = adc_axil_bresp;
    assign m04_axi_buser    = 1'b0;
    assign m04_axi_bvalid   = adc_axil_bvalid;
    assign adc_axil_bready  = m04_axi_bready;

    assign adc_axil_araddr  = m04_axi_araddr;
    assign adc_axil_arvalid = m04_axi_arvalid;
    assign m04_axi_arready  = adc_axil_arready;

    assign m04_axi_rid      = adc_ctrl_arid_reg;
    assign m04_axi_rdata    = adc_axil_rdata;
    assign m04_axi_rresp    = adc_axil_rresp;
    assign m04_axi_rlast    = 1'b1;
    assign m04_axi_ruser    = 1'b0;
    assign m04_axi_rvalid   = adc_axil_rvalid;
    assign adc_axil_rready  = m04_axi_rready;

    adc_controller #(
        .ADC_RESOLUTION    (12),
        .NUM_CHANNELS      (1),
        .FIFO_DEPTH        (32),
        .CLK_FREQ_HZ       (50_000_000),
        .SAMPLE_RATE_HZ    (250),
        .BASE_ADDR         (32'h4000_3000),
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


    /* ============================================================
     * FIR AXI4-Lite CONTROL INTEGRATION
     *
     * Global address:
     *   0x4000_7000 + local FIR register offset
     *
     * The FIR IP itself is unchanged.
     *
     * FIR AXI-Stream data ports are held idle for this integration
     * step because the present AXI interconnect is AXI memory-mapped.
     * ============================================================ */

    wire [31:0] fir_axil_awaddr;
    wire        fir_axil_awvalid;
    wire        fir_axil_awready;
    wire [31:0] fir_axil_wdata;
    wire [3:0]  fir_axil_wstrb;
    wire        fir_axil_wvalid;
    wire        fir_axil_wready;
    wire        fir_axil_bvalid;
    wire [1:0]  fir_axil_bresp;
    wire        fir_axil_bready;
    wire [31:0] fir_axil_araddr;
    wire        fir_axil_arvalid;
    wire        fir_axil_arready;
    wire [31:0] fir_axil_rdata;
    wire        fir_axil_rvalid;
    wire [1:0]  fir_axil_rresp;
    wire        fir_axil_rready;

    reg [ID_WIDTH-1:0] fir_ctrl_awid_reg;
    reg [ID_WIDTH-1:0] fir_ctrl_arid_reg;

    always @(posedge clk) begin
        if (rst) begin
            fir_ctrl_awid_reg <= {ID_WIDTH{1'b0}};
            fir_ctrl_arid_reg <= {ID_WIDTH{1'b0}};
        end
        else begin
            if (m03_axi_awvalid && m03_axi_awready)
                fir_ctrl_awid_reg <= m03_axi_awid;

            if (m03_axi_arvalid && m03_axi_arready)
                fir_ctrl_arid_reg <= m03_axi_arid;
        end
    end

    /* Global 0x4000_7000 -> FIR local 0x0000_0000 */
    assign fir_axil_awaddr  = m03_axi_awaddr - 32'h4000_7000;
    assign fir_axil_awvalid = m03_axi_awvalid;
    assign m03_axi_awready  = fir_axil_awready;

    assign fir_axil_wdata   = m03_axi_wdata;
    assign fir_axil_wstrb   = m03_axi_wstrb;
    assign fir_axil_wvalid  = m03_axi_wvalid;
    assign m03_axi_wready   = fir_axil_wready;

    assign m03_axi_bid      = fir_ctrl_awid_reg;
    assign m03_axi_bresp    = fir_axil_bresp;
    assign m03_axi_buser    = 1'b0;
    assign m03_axi_bvalid   = fir_axil_bvalid;
    assign fir_axil_bready  = m03_axi_bready;

    assign fir_axil_araddr  = m03_axi_araddr - 32'h4000_7000;
    assign fir_axil_arvalid = m03_axi_arvalid;
    assign m03_axi_arready  = fir_axil_arready;

    assign m03_axi_rid      = fir_ctrl_arid_reg;
    assign m03_axi_rdata    = fir_axil_rdata;
    assign m03_axi_rresp    = fir_axil_rresp;
    assign m03_axi_rlast    = 1'b1;
    assign m03_axi_ruser    = 1'b0;
    assign m03_axi_rvalid   = fir_axil_rvalid;
    assign fir_axil_rready  = m03_axi_rready;

    /* FIR AXI-Stream ports: idle for now; no wrapper is used. */
    wire        fir_s_axis_tvalid;
    wire        fir_s_axis_tready;
    wire [15:0] fir_s_axis_tdata;

    wire        fir_m_axis_tvalid;
    wire        fir_m_axis_tready;
    wire [39:0] fir_m_axis_tdata;

    assign fir_s_axis_tvalid = 1'b0;
    assign fir_s_axis_tdata  = 16'd0;
    assign fir_m_axis_tready = 1'b1;

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

        /* AXI4-Stream */
        .s_axis_tvalid     (fir_s_axis_tvalid),
        .s_axis_tready     (fir_s_axis_tready),
        .s_axis_tdata      (fir_s_axis_tdata),

        .m_axis_tvalid     (fir_m_axis_tvalid),
        .m_axis_tready     (fir_m_axis_tready),
        .m_axis_tdata      (fir_m_axis_tdata),

        /* AXI4-Lite control */
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

        /* Status */
        .input_fifo_full   (fir_input_fifo_full),
        .input_fifo_empty  (fir_input_fifo_empty),
        .output_fifo_empty (fir_output_fifo_empty)
    );



    // =====================================================================
    // GPIO AXI4-Lite integration on interconnect M05
    // Global address window: 0x4000_2000 - 0x4000_2FFF
    // =====================================================================
    wire [31:0] gpio_axil_awaddr = m05_axi_awaddr - 32'h4000_2000;
    wire [31:0] gpio_axil_araddr = m05_axi_araddr - 32'h4000_2000;
    reg [ID_WIDTH-1:0] gpio_awid_q;
    reg [ID_WIDTH-1:0] gpio_arid_q;

    always @(posedge clk) begin
        if (rst) begin
            gpio_awid_q <= {ID_WIDTH{1'b0}};
            gpio_arid_q <= {ID_WIDTH{1'b0}};
        end else begin
            if (m05_axi_awvalid && m05_axi_awready)
                gpio_awid_q <= m05_axi_awid;
            if (m05_axi_arvalid && m05_axi_arready)
                gpio_arid_q <= m05_axi_arid;
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

    assign m05_axi_awready = gpio_axil_awready;
    assign m05_axi_wready  = gpio_axil_wready;
    assign m05_axi_bid     = gpio_awid_q;
    assign m05_axi_bresp   = gpio_axil_bresp;
    assign m05_axi_buser   = 1'b0;
    assign m05_axi_bvalid  = gpio_axil_bvalid;
    assign m05_axi_arready = gpio_axil_arready;
    assign m05_axi_rid     = gpio_arid_q;
    assign m05_axi_rdata   = gpio_axil_rdata;
    assign m05_axi_rresp   = gpio_axil_rresp;
    assign m05_axi_rlast   = 1'b1;
    assign m05_axi_ruser   = 1'b0;
    assign m05_axi_rvalid  = gpio_axil_rvalid;

    gpio_axi #(.NUM_BITS(32)) u_gpio (
        .s_axi_aclk     (clk),
        .s_axi_aresetn  (~rst),
        .s_axi_awaddr   (gpio_axil_awaddr),
        .s_axi_awprot   (m05_axi_awprot),
        .s_axi_awvalid  (m05_axi_awvalid),
        .s_axi_awready  (gpio_axil_awready),
        .s_axi_wdata    (m05_axi_wdata),
        .s_axi_wstrb    (m05_axi_wstrb),
        .s_axi_wvalid   (m05_axi_wvalid),
        .s_axi_wready   (gpio_axil_wready),
        .s_axi_bresp    (gpio_axil_bresp),
        .s_axi_bvalid   (gpio_axil_bvalid),
        .s_axi_bready   (m05_axi_bready),
        .s_axi_araddr   (gpio_axil_araddr),
        .s_axi_arprot   (m05_axi_arprot),
        .s_axi_arvalid  (m05_axi_arvalid),
        .s_axi_arready  (gpio_axil_arready),
        .s_axi_rdata    (gpio_axil_rdata),
        .s_axi_rresp    (gpio_axil_rresp),
        .s_axi_rvalid   (gpio_axil_rvalid),
        .s_axi_rready   (m05_axi_rready),
        .io             (gpio_io),
        .intr           (gpio_intr)
    );

    // =====================================================================
    // Timer AXI4-Lite integration on interconnect M06
    // Global address window: 0x4000_1000 - 0x4000_1FFF
    // =====================================================================
    wire [31:0] timer_axil_awaddr = m06_axi_awaddr - 32'h4000_1000;
    wire [31:0] timer_axil_araddr = m06_axi_araddr - 32'h4000_1000;
    reg [ID_WIDTH-1:0] timer_awid_q;
    reg [ID_WIDTH-1:0] timer_arid_q;

    always @(posedge clk) begin
        if (rst) begin
            timer_awid_q <= {ID_WIDTH{1'b0}};
            timer_arid_q <= {ID_WIDTH{1'b0}};
        end else begin
            if (m06_axi_awvalid && m06_axi_awready)
                timer_awid_q <= m06_axi_awid;
            if (m06_axi_arvalid && m06_axi_arready)
                timer_arid_q <= m06_axi_arid;
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

    assign m06_axi_awready = timer_axil_awready;
    assign m06_axi_wready  = timer_axil_wready;
    assign m06_axi_bid     = timer_awid_q;
    assign m06_axi_bresp   = timer_axil_bresp;
    assign m06_axi_buser   = 1'b0;
    assign m06_axi_bvalid  = timer_axil_bvalid;
    assign m06_axi_arready = timer_axil_arready;
    assign m06_axi_rid     = timer_arid_q;
    assign m06_axi_rdata   = timer_axil_rdata;
    assign m06_axi_rresp   = timer_axil_rresp;
    assign m06_axi_rlast   = 1'b1;
    assign m06_axi_ruser   = 1'b0;
    assign m06_axi_rvalid  = timer_axil_rvalid;

    timer_axi u_timer (
        .aclk        (clk),
        .aresetn     (~rst),
        .awaddr      (timer_axil_awaddr),
        .awprot      (m06_axi_awprot),
        .awvalid     (m06_axi_awvalid),
        .awready     (timer_axil_awready),
        .wdata       (m06_axi_wdata),
        .wstrb       (m06_axi_wstrb),
        .wvalid      (m06_axi_wvalid),
        .wready      (timer_axil_wready),
        .bresp       (timer_axil_bresp),
        .bvalid      (timer_axil_bvalid),
        .bready      (m06_axi_bready),
        .araddr      (timer_axil_araddr),
        .arprot      (m06_axi_arprot),
        .arvalid     (m06_axi_arvalid),
        .arready     (timer_axil_arready),
        .rdata       (timer_axil_rdata),
        .rresp       (timer_axil_rresp),
        .rvalid      (timer_axil_rvalid),
        .rready      (m06_axi_rready),
        .ext_meas_i  (timer_ext_meas_i),
        .capture_i   (timer_capture_i),
        .pwm_o       (timer_pwm_o),
        .trigger_o   (timer_trigger_o),
        .irq         (timer_irq)
    );

endmodule
