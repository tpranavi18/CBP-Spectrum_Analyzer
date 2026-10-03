//------------------------------------------------------------------------------
// Module: gpio_bit
// Description: Bidirectional GPIO Bit module with advanced I/O control.
//
// How it operates:
// This module provides the low-level logic for a single GPIO pin. It supports
// standard push-pull, open-drain mode, and configurable pull-up/pull-down
// resistors. It manages the 'inout' tri-state logic based on direction
// and mode settings.
//
// Author: Gemini-3 AI
// License: MIT
//------------------------------------------------------------------------------

module gpio_bit (
    input  logic clk,
    input  logic reset_n,
    
    // Core logic side
    input  logic o,      // Output data
    input  logic oe,     // Output enable (1=output, 0=input)
    output logic i,      // Input data (synchronized)
    
    // Physical configuration side
    input  logic open_drain,   // 1 = Open-drain mode
    input  logic pull_up_en,   // 1 = Internal pull-up enabled
    input  logic pull_down_en, // 1 = Internal pull-down enabled

    // External Pad side
`ifndef FORMAL
    inout  wire  pad
`else
    input  wire  pad
`endif
);

    // Internal driven signal
    logic oe_actual;
    assign oe_actual = open_drain ? (oe && !o) : oe;
    
    // Drive the pad
`ifndef FORMAL
    assign pad = oe_actual ? o : 1'bz;
`else
    // For Formal, we verify logic driving 'o' and 'oe'.
    // 'pad' is treated as input (modelled by solver constraints if needed)
    // We explicitly don't drive it to avoid SMT2 issues with Z state.
`endif

    // Simulation-only: Handle Pulls if supported by simulator
    // In actual hardware, these would be ports connected to IO pad control signals.
    `ifdef SIMULATION
        assign (weak1, weak0) pad = pull_up_en ? 1'b1 : (pull_down_en ? 1'b0 : 1'bz);
    `endif

    // Validation
    always_comb begin
        if (pull_up_en && pull_down_en) begin
            // This is a logic error that should be caught
            // No action in logic, but tools might complain
        end
    end

    // Input Synchronization (2-stage)
    logic [1:0] sync_reg;
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            sync_reg <= 2'b0;
        end else begin
            sync_reg <= {sync_reg[0], pad};
        end
    end

    assign i = sync_reg[1];

endmodule
