// ============================================================================
// File: veer_wrapper.sv
// Project: CBP-Spectrum_Analyzer
//
// Description:
//   VeeR EL2 RISC-V Processor Core Wrapper.
//   Wraps el2_veer_wrapper in AXI4 mode (ICCM/DCCM/icache disabled):
//     - Instantiates el2_mem_if modports required by core
//     - Exposes clean 64-bit AXI interfaces for IFU and LSU
//     - Safely ties off unused DMA, SB (system-bus/debug), JTAG, scan, MPC
//     - Maps core interrupts: timer_int, soft_int, extintsrc_req[8:1]
// ============================================================================

`timescale 1ns/1ps
`default_nettype none

`include "common_defines.vh"

module veer_wrapper
import el2_pkg::*;
#(
    `include "el2_param.vh"
)(
    // Clock and reset
    input  wire         clk,
    input  wire         rst_l,       // active-low reset (VeeR convention)

    // IFU AXI master (64-bit data, read-only)
    output wire                     ifu_axi_awvalid,
    input  wire                     ifu_axi_awready,
    output wire [2:0]              ifu_axi_awid,
    output wire [31:0]             ifu_axi_awaddr,
    output wire [3:0]              ifu_axi_awregion,
    output wire [7:0]              ifu_axi_awlen,
    output wire [2:0]              ifu_axi_awsize,
    output wire [1:0]              ifu_axi_awburst,
    output wire                    ifu_axi_awlock,
    output wire [3:0]              ifu_axi_awcache,
    output wire [2:0]              ifu_axi_awprot,
    output wire [3:0]              ifu_axi_awqos,

    output wire                    ifu_axi_wvalid,
    input  wire                    ifu_axi_wready,
    output wire [63:0]             ifu_axi_wdata,
    output wire [7:0]              ifu_axi_wstrb,
    output wire                    ifu_axi_wlast,

    input  wire                    ifu_axi_bvalid,
    output wire                    ifu_axi_bready,
    input  wire [1:0]              ifu_axi_bresp,
    input  wire [2:0]              ifu_axi_bid,

    output wire                    ifu_axi_arvalid,
    input  wire                    ifu_axi_arready,
    output wire [2:0]              ifu_axi_arid,
    output wire [31:0]             ifu_axi_araddr,
    output wire [3:0]              ifu_axi_arregion,
    output wire [7:0]              ifu_axi_arlen,
    output wire [2:0]              ifu_axi_arsize,
    output wire [1:0]              ifu_axi_arburst,
    output wire                    ifu_axi_arlock,
    output wire [3:0]              ifu_axi_arcache,
    output wire [2:0]              ifu_axi_arprot,
    output wire [3:0]              ifu_axi_arqos,

    input  wire                    ifu_axi_rvalid,
    output wire                    ifu_axi_rready,
    input  wire [2:0]              ifu_axi_rid,
    input  wire [63:0]             ifu_axi_rdata,
    input  wire [1:0]              ifu_axi_rresp,
    input  wire                    ifu_axi_rlast,

    // LSU AXI master (64-bit data, read/write)
    output wire                    lsu_axi_awvalid,
    input  wire                    lsu_axi_awready,
    output wire [2:0]              lsu_axi_awid,
    output wire [31:0]             lsu_axi_awaddr,
    output wire [3:0]              lsu_axi_awregion,
    output wire [7:0]              lsu_axi_awlen,
    output wire [2:0]              lsu_axi_awsize,
    output wire [1:0]              lsu_axi_awburst,
    output wire                    lsu_axi_awlock,
    output wire [3:0]              lsu_axi_awcache,
    output wire [2:0]              lsu_axi_awprot,
    output wire [3:0]              lsu_axi_awqos,

    output wire                    lsu_axi_wvalid,
    input  wire                    lsu_axi_wready,
    output wire [63:0]             lsu_axi_wdata,
    output wire [7:0]              lsu_axi_wstrb,
    output wire                    lsu_axi_wlast,

    input  wire                    lsu_axi_bvalid,
    output wire                    lsu_axi_bready,
    input  wire [1:0]              lsu_axi_bresp,
    input  wire [2:0]              lsu_axi_bid,

    output wire                    lsu_axi_arvalid,
    input  wire                    lsu_axi_arready,
    output wire [2:0]              lsu_axi_arid,
    output wire [31:0]             lsu_axi_araddr,
    output wire [3:0]              lsu_axi_arregion,
    output wire [7:0]              lsu_axi_arlen,
    output wire [2:0]              lsu_axi_arsize,
    output wire [1:0]              lsu_axi_arburst,
    output wire                    lsu_axi_arlock,
    output wire [3:0]              lsu_axi_arcache,
    output wire [2:0]              lsu_axi_arprot,
    output wire [3:0]              lsu_axi_arqos,

    input  wire                    lsu_axi_rvalid,
    output wire                    lsu_axi_rready,
    input  wire [2:0]              lsu_axi_rid,
    input  wire [63:0]             lsu_axi_rdata,
    input  wire [1:0]              lsu_axi_rresp,
    input  wire                    lsu_axi_rlast,

    // Interrupts
    input  wire                    timer_int,
    input  wire                    soft_int,
    input  wire [8:1]              extintsrc_req
);

    // Interface instances for memory export ports (unused with ICCM/DCCM disabled)
    el2_mem_if #(.pt(pt)) el2_mem_export   ();
    el2_mem_if #(.pt(pt)) el2_icache_export();

    // SB (System Bus / debug) tie-offs
    wire        sb_axi_awready_i = 1'b0;
    wire        sb_axi_wready_i  = 1'b0;
    wire        sb_axi_bvalid_i  = 1'b0;
    wire [1:0]  sb_axi_bresp_i   = 2'b00;
    wire [0:0]  sb_axi_bid_i     = 1'b0;
    wire        sb_axi_arready_i = 1'b0;
    wire        sb_axi_rvalid_i  = 1'b0;
    wire [0:0]  sb_axi_rid_i     = 1'b0;
    wire [63:0] sb_axi_rdata_i   = 64'b0;
    wire [1:0]  sb_axi_rresp_i   = 2'b00;
    wire        sb_axi_rlast_i   = 1'b0;

    // DMA slave tie-offs
    wire        dma_axi_bready_i = 1'b0;
    wire        dma_axi_rready_i = 1'b0;

    // Core wrapper instantiation
    el2_veer_wrapper #(.pt(pt)) veer_core (
        .clk                     (clk),
        .rst_l                   (rst_l),
        .dbg_rst_l               (rst_l),
        .rst_vec                 (31'h0),
        .nmi_int                 (1'b0),
        .nmi_vec                 (31'h0),
        .jtag_id                 (31'h0),

        // Trace outputs
        .trace_rv_i_insn_ip      (),
        .trace_rv_i_address_ip   (),
        .trace_rv_i_valid_ip     (),
        .trace_rv_i_exception_ip (),
        .trace_rv_i_ecause_ip    (),
        .trace_rv_i_interrupt_ip (),
        .trace_rv_i_tval_ip      (),

        // IFU AXI
        .ifu_axi_awvalid         (ifu_axi_awvalid),
        .ifu_axi_awready         (ifu_axi_awready),
        .ifu_axi_awid            (ifu_axi_awid),
        .ifu_axi_awaddr          (ifu_axi_awaddr),
        .ifu_axi_awregion        (ifu_axi_awregion),
        .ifu_axi_awlen           (ifu_axi_awlen),
        .ifu_axi_awsize          (ifu_axi_awsize),
        .ifu_axi_awburst         (ifu_axi_awburst),
        .ifu_axi_awlock          (ifu_axi_awlock),
        .ifu_axi_awcache         (ifu_axi_awcache),
        .ifu_axi_awprot          (ifu_axi_awprot),
        .ifu_axi_awqos           (ifu_axi_awqos),

        .ifu_axi_wvalid          (ifu_axi_wvalid),
        .ifu_axi_wready          (ifu_axi_wready),
        .ifu_axi_wdata           (ifu_axi_wdata),
        .ifu_axi_wstrb           (ifu_axi_wstrb),
        .ifu_axi_wlast           (ifu_axi_wlast),

        .ifu_axi_bvalid          (ifu_axi_bvalid),
        .ifu_axi_bready          (ifu_axi_bready),
        .ifu_axi_bresp           (ifu_axi_bresp),
        .ifu_axi_bid             (ifu_axi_bid),

        .ifu_axi_arvalid         (ifu_axi_arvalid),
        .ifu_axi_arready         (ifu_axi_arready),
        .ifu_axi_arid            (ifu_axi_arid),
        .ifu_axi_araddr          (ifu_axi_araddr),
        .ifu_axi_arregion        (ifu_axi_arregion),
        .ifu_axi_arlen           (ifu_axi_arlen),
        .ifu_axi_arsize          (ifu_axi_arsize),
        .ifu_axi_arburst         (ifu_axi_arburst),
        .ifu_axi_arlock          (ifu_axi_arlock),
        .ifu_axi_arcache         (ifu_axi_arcache),
        .ifu_axi_arprot          (ifu_axi_arprot),
        .ifu_axi_arqos           (ifu_axi_arqos),

        .ifu_axi_rvalid          (ifu_axi_rvalid),
        .ifu_axi_rready          (ifu_axi_rready),
        .ifu_axi_rid             (ifu_axi_rid),
        .ifu_axi_rdata           (ifu_axi_rdata),
        .ifu_axi_rresp           (ifu_axi_rresp),
        .ifu_axi_rlast           (ifu_axi_rlast),

        // LSU AXI
        .lsu_axi_awvalid         (lsu_axi_awvalid),
        .lsu_axi_awready         (lsu_axi_awready),
        .lsu_axi_awid            (lsu_axi_awid),
        .lsu_axi_awaddr          (lsu_axi_awaddr),
        .lsu_axi_awregion        (lsu_axi_awregion),
        .lsu_axi_awlen           (lsu_axi_awlen),
        .lsu_axi_awsize          (lsu_axi_awsize),
        .lsu_axi_awburst         (lsu_axi_awburst),
        .lsu_axi_awlock          (lsu_axi_awlock),
        .lsu_axi_awcache         (lsu_axi_awcache),
        .lsu_axi_awprot          (lsu_axi_awprot),
        .lsu_axi_awqos           (lsu_axi_awqos),

        .lsu_axi_wvalid          (lsu_axi_wvalid),
        .lsu_axi_wready          (lsu_axi_wready),
        .lsu_axi_wdata           (lsu_axi_wdata),
        .lsu_axi_wstrb           (lsu_axi_wstrb),
        .lsu_axi_wlast           (lsu_axi_wlast),

        .lsu_axi_bvalid          (lsu_axi_bvalid),
        .lsu_axi_bready          (lsu_axi_bready),
        .lsu_axi_bresp           (lsu_axi_bresp),
        .lsu_axi_bid             (lsu_axi_bid),

        .lsu_axi_arvalid         (lsu_axi_arvalid),
        .lsu_axi_arready         (lsu_axi_arready),
        .lsu_axi_arid            (lsu_axi_arid),
        .lsu_axi_araddr          (lsu_axi_araddr),
        .lsu_axi_arregion        (lsu_axi_arregion),
        .lsu_axi_arlen           (lsu_axi_arlen),
        .lsu_axi_arsize          (lsu_axi_arsize),
        .lsu_axi_arburst         (lsu_axi_arburst),
        .lsu_axi_arlock          (lsu_axi_arlock),
        .lsu_axi_arcache         (lsu_axi_arcache),
        .lsu_axi_arprot          (lsu_axi_arprot),
        .lsu_axi_arqos           (lsu_axi_arqos),

        .lsu_axi_rvalid          (lsu_axi_rvalid),
        .lsu_axi_rready          (lsu_axi_rready),
        .lsu_axi_rid             (lsu_axi_rid),
        .lsu_axi_rdata           (lsu_axi_rdata),
        .lsu_axi_rresp           (lsu_axi_rresp),
        .lsu_axi_rlast           (lsu_axi_rlast),

        // SB AXI (tied off)
        .sb_axi_awvalid          (),
        .sb_axi_awready          (sb_axi_awready_i),
        .sb_axi_awid             (),
        .sb_axi_awaddr           (),
        .sb_axi_awregion         (),
        .sb_axi_awlen            (),
        .sb_axi_awsize           (),
        .sb_axi_awburst          (),
        .sb_axi_awlock           (),
        .sb_axi_awcache          (),
        .sb_axi_awprot           (),
        .sb_axi_awqos            (),

        .sb_axi_wvalid           (),
        .sb_axi_wready           (sb_axi_wready_i),
        .sb_axi_wdata            (),
        .sb_axi_wstrb            (),
        .sb_axi_wlast            (),

        .sb_axi_bvalid           (sb_axi_bvalid_i),
        .sb_axi_bready           (),
        .sb_axi_bresp            (sb_axi_bresp_i),
        .sb_axi_bid              (sb_axi_bid_i),

        .sb_axi_arvalid          (),
        .sb_axi_arready          (sb_axi_arready_i),
        .sb_axi_arid             (),
        .sb_axi_araddr           (),
        .sb_axi_arregion         (),
        .sb_axi_arlen            (),
        .sb_axi_arsize           (),
        .sb_axi_arburst          (),
        .sb_axi_arlock           (),
        .sb_axi_arcache          (),
        .sb_axi_arprot           (),
        .sb_axi_arqos            (),

        .sb_axi_rvalid           (sb_axi_rvalid_i),
        .sb_axi_rready           (),
        .sb_axi_rid              (sb_axi_rid_i),
        .sb_axi_rdata            (sb_axi_rdata_i),
        .sb_axi_rresp            (sb_axi_rresp_i),
        .sb_axi_rlast            (sb_axi_rlast_i),

        // DMA AXI slave (tied off)
        .dma_axi_awvalid         (1'b0),
        .dma_axi_awready         (),
        .dma_axi_awid            (1'b0),
        .dma_axi_awaddr          (32'b0),
        .dma_axi_awsize          (3'b0),
        .dma_axi_awprot          (3'b0),
        .dma_axi_awlen           (8'b0),
        .dma_axi_awburst         (2'b0),

        .dma_axi_wvalid          (1'b0),
        .dma_axi_wready          (),
        .dma_axi_wdata           (64'b0),
        .dma_axi_wstrb           (8'b0),
        .dma_axi_wlast           (1'b0),

        .dma_axi_bvalid          (),
        .dma_axi_bready          (dma_axi_bready_i),
        .dma_axi_bresp           (),
        .dma_axi_bid             (),

        .dma_axi_arvalid         (1'b0),
        .dma_axi_arready         (),
        .dma_axi_arid            (1'b0),
        .dma_axi_araddr          (32'b0),
        .dma_axi_arsize          (3'b0),
        .dma_axi_arprot          (3'b0),
        .dma_axi_arlen           (8'b0),
        .dma_axi_arburst         (2'b0),

        .dma_axi_rvalid          (),
        .dma_axi_rready          (dma_axi_rready_i),
        .dma_axi_rid             (),
        .dma_axi_rdata           (),
        .dma_axi_rresp           (),
        .dma_axi_rlast           (),

        // Clock enables (tie to 1 — single-clock design)
        .lsu_bus_clk_en          (1'b1),
        .ifu_bus_clk_en          (1'b1),
        .dbg_bus_clk_en          (1'b1),
        .dma_bus_clk_en          (1'b1),

        // ECC status outputs (unused)
        .iccm_ecc_single_error   (),
        .iccm_ecc_double_error   (),
        .dccm_ecc_single_error   (),
        .dccm_ecc_double_error   (),
        .dccm_write_readback_error (),

        // Performance counters (unused)
        .dec_tlu_perfcnt0        (),
        .dec_tlu_perfcnt1        (),
        .dec_tlu_perfcnt2        (),
        .dec_tlu_perfcnt3        (),

        // Core Interrupts
        .timer_int               (timer_int),
        .soft_int                (soft_int),
        .extintsrc_req           (extintsrc_req),

        // Core ID
        .core_id                 (28'b0),

        // el2_mem_if exports
        .el2_mem_export          (el2_mem_export.veer_sram_src),
        .el2_icache_export       (el2_icache_export.veer_icache_src),

        // MPC halt/run interface (tied to run)
        .mpc_debug_halt_req      (1'b0),
        .mpc_debug_run_req       (1'b1),
        .mpc_reset_run_req       (1'b1),
        .mpc_debug_halt_ack      (),
        .mpc_debug_run_ack       (),
        .debug_brkpt_status      (),

        // CPU halt/run
        .i_cpu_halt_req          (1'b0),
        .o_cpu_halt_ack          (),
        .o_cpu_halt_status       (),
        .o_debug_mode_status     (),
        .i_cpu_run_req           (1'b0),
        .o_cpu_run_ack           (),

        // Scan / MBIST tie-offs
        .scan_mode               (1'b0),
        .mbist_mode              (1'b0),

        // DMI core/uncore control
        .dmi_core_enable         (1'b0),
        .dmi_uncore_enable       (1'b0),
        .dmi_uncore_en           (),
        .dmi_uncore_wr_en        (),
        .dmi_uncore_addr         (),
        .dmi_uncore_wdata        (),
        .dmi_uncore_rdata        (32'h0),
        .dmi_active              (),

        // JTAG tie-offs
        .jtag_tck                (1'b0),
        .jtag_tms                (1'b0),
        .jtag_tdi                (1'b0),
        .jtag_trst_n             (rst_l),
        .jtag_tdo                ()
    );

endmodule

`default_nettype wire
