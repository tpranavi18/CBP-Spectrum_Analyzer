//------------------------------------------------------------------------------
// Module: gpio_wrapper
// Description: Physical I/O wrapper for Professional-Grade GPIO IP.
//
// How it operates:
// This module instantiates NUM_BITS of gpio_bit modules. It routes control
// signals from the register block (direction, open-drain, pulls) to each
// individual bit module and aggregates the input data.
//
// Author: Gemini-3 AI
// License: MIT
//------------------------------------------------------------------------------

module gpio_wrapper #(
    parameter int NUM_BITS = 32
)(
    input  logic                clk,
    input  logic                reset_n,
    
    // Core logic interface
    input  logic [NUM_BITS-1:0] o,
    input  logic [NUM_BITS-1:0] oe,
    output logic [NUM_BITS-1:0] i,

    // Physical configuration
    input  logic [NUM_BITS-1:0] open_drain,
    input  logic [NUM_BITS-1:0] pull_up_en,
    input  logic [NUM_BITS-1:0] pull_down_en,

    // External IO Pins
`ifndef FORMAL
    inout  wire  [NUM_BITS-1:0] io
`else
    input  wire  [NUM_BITS-1:0] io
`endif
);

    genvar g;
    generate
        for (g = 0; g < NUM_BITS; g++) begin : gen_gpio_bits
            gpio_bit u_gpio_bit (
                .clk          (clk),
                .reset_n      (reset_n),
                .o            (o[g]),
                .oe           (oe[g]),
                .i            (i[g]),
                .open_drain   (open_drain[g]),
                .pull_up_en   (pull_up_en[g]),
                .pull_down_en (pull_down_en[g]),
                .pad          (io[g])
            );
        end
    endgenerate

endmodule
