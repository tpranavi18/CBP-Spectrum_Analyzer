//
// General Purpose Timer Core
//
// Description:
//   32-bit down counter with prescaler and interrupt generation.
//   Supports One-Shot and Continuous (Repeat) modes.
//

module timer_core (
    input  logic        clk,
    input  logic        rst_n,

    // Control Signals
    input  logic        en,         // Enable Timer
    input  logic        mode,       // 0 = One-Shot, 1 = Repeat
    input  logic        dir,        // 0 = Down, 1 = Up
    input  logic        pwm_en,     // PWM Enable
    input  logic        ext_en,     // External Count Enable
    input  logic        pre_en,     // Prescaler Enable
    input  logic [15:0] pre_val,    // Prescaler Value
    input  logic [31:0] load_val,   // Load Value
    input  logic [31:0] cmp_val,    // PWM Compare Value
    input  logic        load_cmd,   // Force Load Command
    
    // External IO
    input  logic        ext_meas_i, // External Measure Input
    input  logic        capture_i,  // Capture Input

    // Status / Output Signals
    output logic [31:0] current_val, // Current Counter Value
    output logic [31:0] capture_val, // Captured Value
    output logic        capture_stb, // Capture Strobe (IRQ trigger)
    output logic        pwm_o,       // PWM Output
    output logic        trigger_o,   // Hardware Trigger Output
    output logic        irq          // Timer Expire IRQ
);

    // Internal Signals
    logic [31:0] counter;
    logic [15:0] prescaler;
    logic        tick;
    logic        clk_tick; // Generated from internal prescaler
    logic        ext_tick; // Generated from external input

    // Edge Detectors
    logic ext_meas_d, ext_meas_re;
    logic capture_d, capture_re;

    // Output assignments
    assign current_val = counter;

    // Edge Detection Logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ext_meas_d <= 1'b0;
            capture_d  <= 1'b0;
        end else begin
            ext_meas_d <= ext_meas_i;
            capture_d  <= capture_i;
        end
    end
    assign ext_meas_re = ext_meas_i && !ext_meas_d;
    assign capture_re  = capture_i && !capture_d;
    assign ext_tick    = ext_meas_re;

    // Capture Logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            capture_val <= '0;
            capture_stb <= 1'b0;
        end else if (capture_re) begin
            capture_val <= counter;
            capture_stb <= 1'b1;
        end else begin
            capture_stb <= 1'b0;
        end
    end

    // Prescaler Logic (Internal Clock)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prescaler <= '0;
            clk_tick  <= 1'b0;
        end else if (load_cmd) begin
            prescaler <= pre_val;
            clk_tick  <= 1'b0;
        end else if (en && !ext_en) begin // Only run prescaler if internal mode
            if (pre_en) begin
                if (prescaler == 0) begin
                    prescaler <= pre_val;
                    clk_tick  <= 1'b1;
                end else begin
                    prescaler <= prescaler - 1;
                    clk_tick  <= 1'b0;
                end
            end else begin
                // If prescaler disabled, tick every cycle
                prescaler <= '0;
                clk_tick  <= 1'b1;
            end
        end else begin
            clk_tick <= 1'b0;
        end
    end

    // Main Tick Selection
    assign tick = ext_en ? ext_tick : clk_tick;

    // One-Shot Done Logic
    logic op_done;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            op_done <= 1'b0;
        end else if (load_cmd || !en) begin
            op_done <= 1'b0; 
        end else if (en && tick && !mode && !op_done) begin
            if (dir == 1'b0 && counter == 0) op_done <= 1'b1;
            else if (dir == 1'b1 && counter == load_val) op_done <= 1'b1;
        end
    end

    // Counter & Trigger Logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter   <= '0;
            irq       <= 1'b0;
            trigger_o <= 1'b0;
        end else if (load_cmd) begin
            counter   <= load_val;
            irq       <= 1'b0;
            trigger_o <= 1'b0;
        end else if (en && tick && !op_done) begin
            if (dir == 1'b0) begin 
                // Down Counting
                if (counter == 0) begin
                    irq       <= 1'b1;
                    trigger_o <= 1'b1;
                    if (mode) counter <= load_val; // Repeat
                    else      counter <= 32'd0;    // One-Shot
                end else begin
                    counter   <= counter - 1;
                    irq       <= 1'b0;
                    trigger_o <= 1'b0;
                end
            end else begin 
                // Up Counting
                if (counter == load_val) begin
                    irq       <= 1'b1;
                    trigger_o <= 1'b1;
                    if (mode) counter <= 32'd0;    // Repeat
                    else      counter <= load_val; // One-Shot (Hold at Max)
                end else begin
                    counter   <= counter + 1;
                    irq       <= 1'b0;
                    trigger_o <= 1'b0;
                end
            end
        end else begin
            irq       <= 1'b0;
            trigger_o <= 1'b0;
        end
    end

    // PWM Logic
    // Simple PWM: High when counter < CMP (for Up count) or > CMP (for Down count)?
    // Common convention: Logic High when Counter < Compare Value (Up counting usually)
    // Let's implement standard variable duty cycle:
    // Down Mode:
    //   Period = LOAD
    //   Active Time = CMP
    //   PWM = 1 when counter < CMP (Low side) or > CMP?
    //   Let's say: PWM = 1 when counter <= CMP.
    // Up Mode:
    //   PWM = 1 when counter < CMP.
    
    always_comb begin
        if (!pwm_en) begin
            pwm_o = 1'b0;
        end else begin
            if (dir == 1'b0) begin
                // Down Counting: valid range [LOAD..0]
                // If CMP is threshold.
                // Example: LOAD=10, CMP=3. 10,9,8,7,6,5,4 -> 0. 3,2,1,0 -> 1.
                pwm_o = (counter <= cmp_val);
            end else begin
                // Up Counting: valid range [0..LOAD]
                // Example: LOAD=10, CMP=3. 0,1,2 -> 1. 3,4,5... -> 0.
                pwm_o = (counter < cmp_val);
            end
        end
    end
endmodule
