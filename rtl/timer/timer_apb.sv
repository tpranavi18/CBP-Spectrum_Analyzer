//
// General Purpose Timer APB4 Wrapper
//
// Description:
//   APB4 Interface wrapper for the General Timer.
//   Bridges APB bus signals to the generic internal register interface.
//

module timer_apb (
    input  logic        pclk,
    input  logic        presetn,

    // APB Interface
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic [31:0] paddr,
    input  logic [2:0]  pprot,
    input  logic        psel,
    input  logic        penable,
    input  logic        pwrite,
    input  logic [31:0] pwdata,
    input  logic [3:0]  pstrb,
    /* verilator lint_on UNUSEDSIGNAL */
    output logic        pready,
    output logic [31:0] prdata,
    output logic        pslverr,

    // External IO
    input  logic        ext_meas_i,
    input  logic        capture_i,
    output logic        pwm_o,
    output logic        trigger_o,

    output logic        irq
);

    // Internal Signals
    logic        cs, we;
    logic [5:0]  addr;
    logic [31:0] rdata;
    
    // Core/Reg Interconnect
    logic        en, mode, dir, pwm_en, ext_en, pre_en, load_cmd;
    logic [15:0] pre_val;
    logic [31:0] load_val, cmp_val, current_val, capture_val;
    logic        core_irq_pulse, capture_stb;
    
    /* verilator lint_off UNUSEDSIGNAL */
    logic        unused_cap_en;
    /* verilator lint_on UNUSEDSIGNAL */
    logic        core_intr;

    // APB Slave Adapter
    /* verilator lint_off UNUSEDSIGNAL */
    logic [31:0] reg_addr;
    logic [31:0] reg_wdata;
    logic        reg_we;
    logic        reg_re;
    /* verilator lint_on UNUSEDSIGNAL */
    
    /* verilator lint_off PINCONNECTEMPTY */
    apb_slave_adapter #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32)
    ) u_apb_adapter (
        .pclk      (pclk),
        .presetn   (presetn),
        .paddr     (paddr),
        .pprot     (pprot),
        .psel      (psel),
        .penable   (penable),
        .pwrite    (pwrite),
        .pwdata    (pwdata),
        .pstrb     (pstrb),
        .pready    (pready),
        .prdata    (prdata),
        .pslverr   (pslverr),
        .reg_addr  (reg_addr),
        .reg_wdata (reg_wdata),
        .reg_rdata (rdata),
        .reg_we    (reg_we),
        .reg_re    (reg_re),
        .reg_be    ()
    );
    /* verilator lint_on PINCONNECTEMPTY */

    // Map Adapter outputs to Timer Regs inputs
    assign cs   = reg_we || reg_re;
    assign we   = reg_we;
    assign addr = reg_addr[5:0];
    
    // Note: Timer Regs uses pwdata directly? 
    // In original: .wdata(pwdata).
    // Adapter provides reg_wdata (which is pwdata).
    // Let's use reg_wdata from Adapter for cleanliness? 
    // But reg_wdata output from adapter is logic.
    // I need to connect it.
    // Let's modify instantiation above to bind reg_wdata.
    // And update timer_regs instantiation.
    // Actually, timer_regs takes .wdata(pwdata).
    // I can leave it or change it.
    // I'll leave it as pwdata to minimize diffs in instantiation, 
    // OR change it to use reg_wdata to be strictly utilizing the adapter.
    // Let's leave it as pwdata (adapter pass-through is just assign reg_wdata = pwdata).
    
    // No, wait. I should use reg_wdata from adapter to be clean.
    // But timer_regs instantiation is below this block.
    // I am replacing lines 52-60.
    // timer_regs instantiation starts line 62.
    // I cannot change timer_regs instantiation in this edit.
    // So I must stick to using pwdata in timer_regs (which is fine).
    // So reg_wdata from adapter can be unused or open.
    // I'll leave it open.

    // Register Block Instantiation
    assign irq = core_intr;

    timer_regs u_timer_regs (
        .clk(pclk),
        .rst_n(presetn),
        .cs(cs),
        .we(we),
        .addr(addr),
        .wdata(reg_wdata),
        .rdata(rdata),
        
        .en(en),
        .mode(mode),
        .dir(dir),
        .pwm_en(pwm_en),
        .ext_en(ext_en),
        .cap_en(unused_cap_en),
        .pre_en(pre_en),
        .pre_val(pre_val),
        .load_val(load_val),
        .cmp_val(cmp_val),
        .load_cmd(load_cmd),
        .current_val(current_val),
        .capture_val(capture_val),
        .capture_stb(capture_stb),
        .core_irq(core_irq_pulse),
        
        .intr_o(core_intr)
    );
        
    // Core Instantiation
    timer_core u_timer_core (
        .clk(pclk),
        .rst_n(presetn),
        
        .en(en),
        .mode(mode),
        .dir(dir),
        .pwm_en(pwm_en),
        .ext_en(ext_en),
        .pre_en(pre_en),
        .pre_val(pre_val),
        .load_val(load_val),
        .cmp_val(cmp_val),
        .load_cmd(load_cmd),
        
        .ext_meas_i(ext_meas_i),
        .capture_i(capture_i),
        
        .current_val(current_val),
        .capture_val(capture_val),
        .capture_stb(capture_stb),
        .pwm_o(pwm_o),
        .trigger_o(trigger_o),
        .irq(core_irq_pulse)
    );

endmodule

