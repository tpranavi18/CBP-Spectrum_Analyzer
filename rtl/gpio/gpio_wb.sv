// gpio_wb.sv
// 
// Wishbone Slave Adapter for GPIO IP.
//------------------------------------------------------------------------------
// Module: gpio_wb
// Description: Wishbone B4 Wrapper for Professional-Grade GPIO IP.
//
// How it operates:
// This module provides a Wishbone slave interface (Standard B4) to the GPIO 
// register block. It handles Wishbone signals (cyc, stb, we, ack) and 
// translates them into internal register accesses. It instantiates the 
// common GPIO register logic and the physical GPIO wrapper.
//
// Author: Gemini-3 AI
// License: MIT
//------------------------------------------------------------------------------

module gpio_wb #(
    parameter int NUM_BITS = 32
)(
    input  logic        wb_clk_i,
    input  logic        wb_rst_i,
    
    // Wishbone Interface
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic [2:0]  s_wb_cti,
    input  logic [1:0]  s_wb_bte,
    /* verilator lint_on UNUSEDSIGNAL */
    input  logic [31:0] wb_adr_i,
    input  logic [31:0] wb_dat_i,
    output logic [31:0] wb_dat_o,
    input  logic        wb_we_i,
    input  logic [3:0]  wb_sel_i,
    input  logic        wb_stb_i,
    input  logic        wb_cyc_i,
    output logic        wb_ack_o,
    output logic        wb_err_o,
    output logic        wb_stall_o,

    // GPIO Pins
`ifndef FORMAL
    inout  wire  [NUM_BITS-1:0] io,
`else
    input  wire  [NUM_BITS-1:0] io,
`endif

    // Interrupt
    output logic                intr
);

    // Internal Bus Signals
    logic [31:0] reg_addr;
    logic [31:0] reg_wdata;
    logic [31:0] reg_rdata;
    logic        reg_we;
    logic        reg_re;
    logic [3:0]  reg_be;
    /* verilator lint_off UNUSEDSIGNAL */
    logic        reg_ack;
    /* verilator lint_on UNUSEDSIGNAL */
    logic [NUM_BITS-1:0] reg_data_o;
    logic [NUM_BITS-1:0] reg_dir;
    logic [NUM_BITS-1:0] gpio_i;

    // Physical Config Signals
    logic [NUM_BITS-1:0] open_drain;
    logic [NUM_BITS-1:0] pull_up_en;
    logic [NUM_BITS-1:0] pull_down_en;

    // Wishbone Slave Adapter
    wb_slave_adapter #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32)
    ) u_wb_adapter (
        .wb_clk_i  (wb_clk_i),
        .wb_rst_i  (wb_rst_i),
        .wb_adr_i  (wb_adr_i),
        .wb_dat_i  (wb_dat_i),
        .wb_dat_o  (wb_dat_o),
        .wb_we_i   (wb_we_i),
        .wb_sel_i  (wb_sel_i),
        .wb_stb_i  (wb_stb_i),
        .wb_cyc_i  (wb_cyc_i),
        .wb_ack_o  (wb_ack_o),
        .wb_err_o  (wb_err_o),
        .wb_stall_o(wb_stall_o),
        // .wb_rty_o  (), // Not supported
        .reg_addr  (reg_addr),
        .reg_wdata (reg_wdata),
        .reg_rdata (reg_rdata),
        .reg_we    (reg_we),
        .reg_re    (reg_re),
        .reg_be    (reg_be)
        // .reg_ack   (reg_ack) // Adapter generates Ack internally
    );



    // Instantiate Internal Register Block
    gpio_regs #(
        .NUM_BITS(NUM_BITS)
    ) u_gpio_regs (
        .clk          (wb_clk_i),
        .reset_n      (~wb_rst_i),
        .addr         (reg_addr),
        .wdata        (reg_wdata),
        .rdata        (reg_rdata),
        .we           (reg_we),
        .re           (reg_re),
        .be           (reg_be),
        .ack          (reg_ack),
        .reg_data_o   (reg_data_o),
        .reg_dir      (reg_dir),
        .gpio_i       (gpio_i),
        .open_drain   (open_drain),
        .pull_up_en   (pull_up_en),
        .pull_down_en (pull_down_en),
        .intr         (intr)
    );

    // Instantiate GPIO Wrapper
    gpio_wrapper #(
        .NUM_BITS(NUM_BITS)
    ) u_gpio_wrapper (
        .clk          (wb_clk_i),
        .reset_n      (~wb_rst_i),
        .oe           (reg_dir),
        .o            (reg_data_o),
        .i            (gpio_i),
        .open_drain   (open_drain),
        .pull_up_en   (pull_up_en),
        .pull_down_en (pull_down_en),
        .io           (io)
    );

endmodule
