//`timescale 1ns/1ps

module soc_uart_top #(
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
    output wire                     uart_tx_o
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
     * AXI INTERCONNECT
     *
     * M00 = UART
     * UART address range:
     *
     * 0x4000_0000 - 0x4000_0FFF
     *
     * M01-M13 are disabled for this integration stage.
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

        /* Unused targets */
        .M01_ADDR_WIDTH    (32'd0),
        .M01_CONNECT_READ  (3'b000),
        .M01_CONNECT_WRITE (3'b000),

        .M02_ADDR_WIDTH    (32'd0),
        .M02_CONNECT_READ  (3'b000),
        .M02_CONNECT_WRITE (3'b000),

        .M03_ADDR_WIDTH    (32'd0),
        .M03_CONNECT_READ  (3'b000),
        .M03_CONNECT_WRITE (3'b000),

        .M04_ADDR_WIDTH    (32'd0),
        .M04_CONNECT_READ  (3'b000),
        .M04_CONNECT_WRITE (3'b000),

        .M05_ADDR_WIDTH    (32'd0),
        .M05_CONNECT_READ  (3'b000),
        .M05_CONNECT_WRITE (3'b000),

        .M06_ADDR_WIDTH    (32'd0),
        .M06_CONNECT_READ  (3'b000),
        .M06_CONNECT_WRITE (3'b000),

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
        .m00_axi_rready   (m00_axi_rready)

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

endmodule
