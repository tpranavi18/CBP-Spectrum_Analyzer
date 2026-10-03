//
// General Purpose Timer Wishbone B4 Wrapper
//
// Description:
//   Wishbone Interface wrapper for the General Timer.
//

module timer_wb (
    input  logic        wb_clk_i,
    input  logic        wb_rst_i,

    // Wishbone Interface
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic [31:0] wb_adr_i,
    /* verilator lint_on UNUSEDSIGNAL */
    input  logic [31:0] wb_dat_i,
    input  logic        wb_we_i,
    input  logic        wb_stb_i,
    input  logic        wb_cyc_i,
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic [3:0]  wb_sel_i,
    /* verilator lint_on UNUSEDSIGNAL */
    output logic [31:0] wb_dat_o,
    output logic        wb_ack_o,
    output logic        wb_err_o,
    output logic        wb_stall_o,

    // External IO
    input  logic        ext_meas_i,
    input  logic        capture_i,
    output logic        pwm_o,
    output logic        trigger_o,

    output logic        irq
);

    // Internal Signals
    logic        cs, we, presetn;
    logic [5:0]  addr;
    logic [31:0] rdata;
    
    /* verilator lint_off UNUSEDSIGNAL */
    logic        en, mode, dir, pwm_en, ext_en, cap_en, pre_en, load_cmd;
    /* verilator lint_on UNUSEDSIGNAL */
    logic        core_irq_pulse, capture_stb, core_intr;
    logic [15:0] pre_val;
    logic [31:0] load_val, cmp_val, current_val, capture_val;

    assign presetn = ~wb_rst_i;
    // Wishbone Slave Adapter
    /* verilator lint_off UNUSEDSIGNAL */
    logic reg_we, reg_re;
    logic [31:0] reg_addr_wire;
    logic [31:0] reg_wdata;
    /* verilator lint_on UNUSEDSIGNAL */

    /* verilator lint_off PINCONNECTEMPTY */
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
        // .wb_rty_o  (), // Not supported by adapter
        .reg_addr  (reg_addr_wire),
        .reg_wdata (reg_wdata),
        .reg_rdata (rdata),
        .reg_we    (reg_we),
        .reg_re    (reg_re),
        .reg_be    ()
        // .reg_ack   (ack_q) // Adapter generates Ack internally
    );
    /* verilator lint_on PINCONNECTEMPTY */

    
    // Internal Wiring
    assign addr = reg_addr_wire[5:0];
    assign cs   = reg_we || reg_re;
    assign we   = reg_we;
    

    // ACK Logic (Handled by u_wb_adapter)
    // always_ff @(posedge wb_clk_i or posedge wb_rst_i) begin ... end

    // Register Instantiation
    assign irq = core_intr;

    timer_regs u_timer_regs (
        .clk(wb_clk_i),
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
        .cap_en(cap_en),
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
        .clk        (wb_clk_i),
        .rst_n      (presetn),
        .en         (en),
        .mode       (mode),
        .dir        (dir),
        .pwm_en     (pwm_en),
        .ext_en     (ext_en),
        .pre_en     (pre_en),
        .pre_val    (pre_val),
        .load_val   (load_val),
        .cmp_val    (cmp_val),
        .load_cmd   (load_cmd),
        .ext_meas_i (ext_meas_i),
        .capture_i  (capture_i),
        .current_val(current_val),
        .capture_val(capture_val),
        .capture_stb(capture_stb),
        .pwm_o      (pwm_o),
        .trigger_o  (trigger_o),
        .irq        (core_irq_pulse)
    );

endmodule
