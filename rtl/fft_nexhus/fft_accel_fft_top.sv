`timescale 1ns/1ps

module fft_accel_top #(
    parameter int N           = 1024,
    parameter int AXI_ADDR_W  = 16,
    parameter int AXI_DATA_W  = 32,
    parameter int AXI_ID_W    = 4
)(
    input  logic                     clk,
    input  logic                     rst_n,

    output logic                     irq,

    // ------------------------------------------------------------
    // AXI4-Lite control interface
    // ------------------------------------------------------------
    input  logic [AXI_ADDR_W-1:0]    S_AXIL_AWADDR,
    input  logic                     S_AXIL_AWVALID,
    output logic                     S_AXIL_AWREADY,

    input  logic [AXI_DATA_W-1:0]    S_AXIL_WDATA,
    input  logic [AXI_DATA_W/8-1:0]  S_AXIL_WSTRB,
    input  logic                     S_AXIL_WVALID,
    output logic                     S_AXIL_WREADY,

    output logic [1:0]               S_AXIL_BRESP,
    output logic                     S_AXIL_BVALID,
    input  logic                     S_AXIL_BREADY,

    input  logic [AXI_ADDR_W-1:0]    S_AXIL_ARADDR,
    input  logic                     S_AXIL_ARVALID,
    output logic                     S_AXIL_ARREADY,

    output logic [AXI_DATA_W-1:0]    S_AXIL_RDATA,
    output logic [1:0]               S_AXIL_RRESP,
    output logic                     S_AXIL_RVALID,
    input  logic                     S_AXIL_RREADY,

    // ------------------------------------------------------------
    // AXI4 memory-window interface
    // ------------------------------------------------------------
    input  logic [AXI_ID_W-1:0]      S_AXI_AWID,
    input  logic [AXI_ADDR_W-1:0]    S_AXI_AWADDR,
    input  logic [7:0]               S_AXI_AWLEN,
    input  logic [2:0]               S_AXI_AWSIZE,
    input  logic [1:0]               S_AXI_AWBURST,
    input  logic                     S_AXI_AWVALID,
    output logic                     S_AXI_AWREADY,

    input  logic [AXI_DATA_W-1:0]    S_AXI_WDATA,
    input  logic [AXI_DATA_W/8-1:0]  S_AXI_WSTRB,
    input  logic                     S_AXI_WLAST,
    input  logic                     S_AXI_WVALID,
    output logic                     S_AXI_WREADY,

    output logic [AXI_ID_W-1:0]      S_AXI_BID,
    output logic [1:0]               S_AXI_BRESP,
    output logic                     S_AXI_BVALID,
    input  logic                     S_AXI_BREADY,

    input  logic [AXI_ID_W-1:0]      S_AXI_ARID,
    input  logic [AXI_ADDR_W-1:0]    S_AXI_ARADDR,
    input  logic [7:0]               S_AXI_ARLEN,
    input  logic [2:0]               S_AXI_ARSIZE,
    input  logic [1:0]               S_AXI_ARBURST,
    input  logic                     S_AXI_ARVALID,
    output logic                     S_AXI_ARREADY,

    output logic [AXI_ID_W-1:0]      S_AXI_RID,
    output logic [AXI_DATA_W-1:0]    S_AXI_RDATA,
    output logic [1:0]               S_AXI_RRESP,
    output logic                     S_AXI_RLAST,
    output logic                     S_AXI_RVALID,
    input  logic                     S_AXI_RREADY
);

    localparam int MEM_AW = $clog2(N);

    logic                    start_pulse;
    logic                    fft_done;
    logic                    fft_busy;

    logic                    mem_we;
    logic [MEM_AW-1:0]       mem_waddr;
    logic [31:0]             mem_wdata;
    logic [MEM_AW-1:0]       mem_raddr;
    logic [31:0]             mem_rdata;

    assign irq = fft_done;

    fft_ctrl_axil #(
        .AXI_ADDR_W(AXI_ADDR_W),
        .AXI_DATA_W(AXI_DATA_W)
    ) u_ctrl_axil (
        .clk         (clk),
        .rst_n       (rst_n),
        .fft_done    (fft_done),
        .fft_busy    (fft_busy),
        .start_pulse (start_pulse),

        .S_AXI_AWADDR (S_AXIL_AWADDR),
        .S_AXI_AWVALID(S_AXIL_AWVALID),
        .S_AXI_AWREADY(S_AXIL_AWREADY),

        .S_AXI_WDATA  (S_AXIL_WDATA),
        .S_AXI_WSTRB  (S_AXIL_WSTRB),
        .S_AXI_WVALID (S_AXIL_WVALID),
        .S_AXI_WREADY (S_AXIL_WREADY),

        .S_AXI_BRESP  (S_AXIL_BRESP),
        .S_AXI_BVALID (S_AXIL_BVALID),
        .S_AXI_BREADY (S_AXIL_BREADY),

        .S_AXI_ARADDR (S_AXIL_ARADDR),
        .S_AXI_ARVALID(S_AXIL_ARVALID),
        .S_AXI_ARREADY(S_AXIL_ARREADY),

        .S_AXI_RDATA  (S_AXIL_RDATA),
        .S_AXI_RRESP  (S_AXIL_RRESP),
        .S_AXI_RVALID (S_AXIL_RVALID),
        .S_AXI_RREADY (S_AXIL_RREADY)
    );

    fft_mem_axi4_slave #(
        .N          (N),
        .AXI_ADDR_W (AXI_ADDR_W),
        .AXI_DATA_W (AXI_DATA_W),
        .AXI_ID_W   (AXI_ID_W)
    ) u_mem_axi4_slave (
        .clk      (clk),
        .rst_n    (rst_n),
        .fft_busy (fft_busy),

        .mem_we   (mem_we),
        .mem_waddr(mem_waddr),
        .mem_wdata(mem_wdata),
        .mem_raddr(mem_raddr),
        .mem_rdata(mem_rdata),

        .S_AXI_AWID    (S_AXI_AWID),
        .S_AXI_AWADDR  (S_AXI_AWADDR),
        .S_AXI_AWLEN   (S_AXI_AWLEN),
        .S_AXI_AWSIZE  (S_AXI_AWSIZE),
        .S_AXI_AWBURST (S_AXI_AWBURST),
        .S_AXI_AWVALID (S_AXI_AWVALID),
        .S_AXI_AWREADY (S_AXI_AWREADY),

        .S_AXI_WDATA   (S_AXI_WDATA),
        .S_AXI_WSTRB   (S_AXI_WSTRB),
        .S_AXI_WLAST   (S_AXI_WLAST),
        .S_AXI_WVALID  (S_AXI_WVALID),
        .S_AXI_WREADY  (S_AXI_WREADY),

        .S_AXI_BID     (S_AXI_BID),
        .S_AXI_BRESP   (S_AXI_BRESP),
        .S_AXI_BVALID  (S_AXI_BVALID),
        .S_AXI_BREADY  (S_AXI_BREADY),

        .S_AXI_ARID    (S_AXI_ARID),
        .S_AXI_ARADDR  (S_AXI_ARADDR),
        .S_AXI_ARLEN   (S_AXI_ARLEN),
        .S_AXI_ARSIZE  (S_AXI_ARSIZE),
        .S_AXI_ARBURST (S_AXI_ARBURST),
        .S_AXI_ARVALID (S_AXI_ARVALID),
        .S_AXI_ARREADY (S_AXI_ARREADY),

        .S_AXI_RID     (S_AXI_RID),
        .S_AXI_RDATA   (S_AXI_RDATA),
        .S_AXI_RRESP   (S_AXI_RRESP),
        .S_AXI_RLAST   (S_AXI_RLAST),
        .S_AXI_RVALID  (S_AXI_RVALID),
        .S_AXI_RREADY  (S_AXI_RREADY)
    );

    fft_loadstore_wrapper #(
        .N(N)
    ) u_fft_loadstore_wrapper (
        .clk     (clk),
        .rst_n   (rst_n),
        .start   (start_pulse),
        .done    (fft_done),
        .busy    (fft_busy),

        .wr_en   (mem_we),
        .wr_addr (mem_waddr),
        .wr_data (mem_wdata),

        .rd_addr (mem_raddr),
        .rd_data (mem_rdata)
    );

endmodule