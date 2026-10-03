//------------------------------------------------------------------------------
// Module: gpio_regs
// Description: Common register block for Professional-Grade GPIO IP.
//
// Author: Gemini-3 AI
// License: MIT
//------------------------------------------------------------------------------

module gpio_regs #(
    parameter int NUM_BITS = 32
)(
    input  logic                clk,
    input  logic                reset_n,
    
    // Internal Bus Interface
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic [31:0]         addr,
    /* verilator lint_on UNUSEDSIGNAL */
    input  logic [31:0]         wdata,
    output logic [31:0]         rdata,
    input  logic                we,
    input  logic                re,
    input  logic [3:0]          be,
    output logic                ack,

    // Interface to GPIO Wrapper
    output logic [NUM_BITS-1:0] reg_data_o,
    output logic [NUM_BITS-1:0] reg_dir,
    input  logic [NUM_BITS-1:0] gpio_i,

    // Physical Configuration to Wrapper
    output logic [NUM_BITS-1:0] open_drain,
    output logic [NUM_BITS-1:0] pull_up_en,
    output logic [NUM_BITS-1:0] pull_down_en,

    // Interrupt Output
    output logic                intr
);

    // Parameter Validation
    generate
        if (NUM_BITS > 32) begin : gen_num_bits_error
            initial begin
                $error("FATAL: %m : NUM_BITS (%0d) must be <= 32", NUM_BITS);
                $fatal(1, "NUM_BITS exceeds 32 bits");
            end
        end
    endgenerate

    // Register Offsets
    localparam bit [6:0] ADDR_DATA_I   = 7'h00;
    localparam bit [6:0] ADDR_DATA_O   = 7'h04;
    localparam bit [6:0] ADDR_DIR      = 7'h08;
    localparam bit [6:0] ADDR_INT_EN   = 7'h0C;
    localparam bit [6:0] ADDR_INT_TYP  = 7'h10;
    localparam bit [6:0] ADDR_INT_POL  = 7'h14;
    localparam bit [6:0] ADDR_INT_ANY  = 7'h18;
    localparam bit [6:0] ADDR_INT_STS  = 7'h1C;
    localparam bit [6:0] ADDR_SET_O    = 7'h20;
    localparam bit [6:0] ADDR_CLR_O    = 7'h24;
    localparam bit [6:0] ADDR_TGL_O    = 7'h28;
    localparam bit [6:0] ADDR_DEB_TH   = 7'h2C;
    localparam bit [6:0] ADDR_DEB_EN   = 7'h30;
    localparam bit [6:0] ADDR_INV_IN   = 7'h34;
    localparam bit [6:0] ADDR_INV_OUT  = 7'h38;
    localparam bit [6:0] ADDR_OD_EN    = 7'h3C;
    localparam bit [6:0] ADDR_WR_MASK  = 7'h40;
    localparam bit [6:0] ADDR_PU_EN    = 7'h44;
    localparam bit [6:0] ADDR_PD_EN    = 7'h48;
    localparam bit [6:0] ADDR_PWM_EN   = 7'h4C;
    localparam bit [6:0] ADDR_PWM_CFG  = 7'h50;
    localparam bit [6:0] ADDR_PWM_DUTY = 7'h54;

    // Register State
    logic [NUM_BITS-1:0] s_reg_data_o;
    logic [NUM_BITS-1:0] s_reg_dir;
    logic [NUM_BITS-1:0] s_reg_int_en;
    logic [NUM_BITS-1:0] s_reg_int_typ;
    logic [NUM_BITS-1:0] s_reg_int_pol;
    logic [NUM_BITS-1:0] s_reg_int_any;
    logic [NUM_BITS-1:0] s_reg_int_sts;
    logic [31:0]         s_reg_deb_th;
    logic [NUM_BITS-1:0] s_reg_deb_en;
    logic [NUM_BITS-1:0] s_reg_inv_in;
    logic [NUM_BITS-1:0] s_reg_inv_out;
    logic [NUM_BITS-1:0] s_reg_od_en;
    logic [NUM_BITS-1:0] s_reg_wr_mask;
    logic [NUM_BITS-1:0] s_reg_pu_en;
    logic [NUM_BITS-1:0] s_reg_pd_en;
    logic [NUM_BITS-1:0] s_reg_pwm_en;
    logic [31:0]         s_reg_pwm_cfg;
    logic [15:0]         s_reg_pwm_duty [NUM_BITS];

    // PWM Engine
    logic [15:0] pwm_cnt;
    logic [15:0] pwm_prescaler;
    logic [NUM_BITS-1:0] pwm_val;

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            pwm_cnt <= '0;
            pwm_prescaler <= '0;
        end else begin
            if (pwm_prescaler >= s_reg_pwm_cfg[15:0]) begin
                pwm_prescaler <= '0;
                if (pwm_cnt >= s_reg_pwm_cfg[31:16]) pwm_cnt <= '0;
                else                                 pwm_cnt <= pwm_cnt + 1'b1;
            end else begin
                pwm_prescaler <= pwm_prescaler + 1'b1;
            end
        end
    end

    genvar p;
    generate
        for (p = 0; p < NUM_BITS; p++) begin : gen_pwm
            assign pwm_val[p] = (pwm_cnt < s_reg_pwm_duty[p]);
        end
    endgenerate

    // Physical Interface to Wrapper
    assign reg_data_o = (s_reg_pwm_en & pwm_val) | (~s_reg_pwm_en & (s_reg_data_o ^ s_reg_inv_out));
    assign reg_dir    = s_reg_dir;
    assign open_drain = s_reg_od_en;
    assign pull_up_en = s_reg_pu_en;
    assign pull_down_en = s_reg_pd_en;

    // Debouncing Logic
    logic [NUM_BITS-1:0] gpio_i_deb;
    genvar i;
    generate
        for (i = 0; i < NUM_BITS; i++) begin : gen_deb
            logic [31:0] deb_cnt;
            logic        gpio_i_sync;
            assign gpio_i_sync = gpio_i[i] ^ s_reg_inv_in[i];

            always_ff @(posedge clk or negedge reset_n) begin
                if (!reset_n) begin
                    deb_cnt <= '0;
                    gpio_i_deb[i] <= 1'b0;
                end else if (s_reg_deb_en[i]) begin
                    if (gpio_i_sync != gpio_i_deb[i]) begin
                        if (deb_cnt >= s_reg_deb_th) begin
                            gpio_i_deb[i] <= gpio_i_sync;
                            deb_cnt <= '0;
                        end else begin
                            deb_cnt <= deb_cnt + 1'b1;
                        end
                    end else begin
                        deb_cnt <= '0;
                    end
                end else begin
                    gpio_i_deb[i] <= gpio_i_sync;
                    deb_cnt <= '0;
                end
            end
        end
    endgenerate

    // Edge Detection
    logic [NUM_BITS-1:0] gpio_i_deb_q;
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) gpio_i_deb_q <= '0;
        else          gpio_i_deb_q <= gpio_i_deb;
    end

    wire [NUM_BITS-1:0] gpio_edge_pos =  gpio_i_deb & ~gpio_i_deb_q;
    wire [NUM_BITS-1:0] gpio_edge_neg = ~gpio_i_deb &  gpio_i_deb_q;
    wire [NUM_BITS-1:0] gpio_edge_any = gpio_edge_pos | gpio_edge_neg;

    // Interrupt Condition Per Bit
    logic [NUM_BITS-1:0] intr_cond;
    generate
        for (i = 0; i < NUM_BITS; i++) begin : gen_intr
            always_comb begin
                if (s_reg_int_typ[i]) begin // Edge
                    if (s_reg_int_any[i])      intr_cond[i] = gpio_edge_any[i];
                    else if (s_reg_int_pol[i]) intr_cond[i] = gpio_edge_pos[i];
                    else                       intr_cond[i] = gpio_edge_neg[i];
                end else begin // Level
                    if (s_reg_int_pol[i])      intr_cond[i] = gpio_i_deb[i];
                    else                       intr_cond[i] = ~gpio_i_deb[i];
                end
            end
        end
    endgenerate

    // PWM address helper variables to avoid latches
    logic [31:0] pwm_duty_idx;
    int          pwm_duty_int;

    // Combinational address mapping to avoid latches
    always_comb begin
        if (addr[6:0] >= ADDR_PWM_DUTY) begin
            pwm_duty_idx = ({25'b0, addr[6:0]} - {25'b0, ADDR_PWM_DUTY}) >> 2;
            pwm_duty_int = int'(pwm_duty_idx);
        end else begin
            pwm_duty_idx = '0;
            pwm_duty_int = 0;
        end
    end

    // Register Writes
    always_ff @(posedge clk or negedge reset_n) begin : proc_reg_write
        if (!reset_n) begin
            s_reg_data_o   <= '0;
            s_reg_dir      <= '0;
            s_reg_int_en   <= '0;
            s_reg_int_typ  <= '0;
            s_reg_int_pol  <= '0;
            s_reg_int_any  <= '0;
            s_reg_int_sts  <= '0;
            s_reg_deb_th   <= '0;
            s_reg_deb_en   <= '0;
            s_reg_inv_in   <= '0;
            s_reg_inv_out  <= '0;
            s_reg_od_en    <= '0;
            s_reg_wr_mask  <= '0;
            s_reg_pu_en    <= '0;
            s_reg_pd_en    <= '0;
            s_reg_pwm_en   <= '0;
            s_reg_pwm_cfg  <= '0;
            for (int r = 0; r < NUM_BITS; r++) s_reg_pwm_duty[r] <= '0;
        end else begin
            // Update Interrupt Status
            for (int r = 0; r < NUM_BITS; r++) begin
                if (s_reg_int_en[r] && s_reg_int_typ[r] && intr_cond[r]) begin
                    s_reg_int_sts[r] <= 1'b1;
                end
            end

            if (we) begin
                case (addr[6:0])
                    ADDR_DATA_O: begin
                        for (int k = 0; k < NUM_BITS; k++) begin
                            if (be[k/8] && !s_reg_wr_mask[k]) s_reg_data_o[k] <= wdata[k];
                        end
                    end
                    ADDR_DIR: begin
                        for (int k = 0; k < NUM_BITS; k++) begin
                            if (be[k/8]) s_reg_dir[k] <= wdata[k];
                        end
                    end
                    ADDR_INT_EN: begin
                        for (int k = 0; k < NUM_BITS; k++) begin
                            if (be[k/8]) s_reg_int_en[k] <= wdata[k];
                        end
                    end
                    ADDR_INT_TYP: begin
                        for (int k = 0; k < NUM_BITS; k++) begin
                            if (be[k/8]) s_reg_int_typ[k] <= wdata[k];
                        end
                    end
                    ADDR_INT_POL: begin
                        for (int k = 0; k < NUM_BITS; k++) begin
                            if (be[k/8]) s_reg_int_pol[k] <= wdata[k];
                        end
                    end
                    ADDR_INT_ANY: begin
                        for (int k = 0; k < NUM_BITS; k++) begin
                            if (be[k/8]) s_reg_int_any[k] <= wdata[k];
                        end
                    end
                    ADDR_INT_STS: begin
                        for (int k = 0; k < NUM_BITS; k++) begin
                            if (be[k/8]) s_reg_int_sts[k] <= s_reg_int_sts[k] & ~wdata[k];
                        end
                    end
                    ADDR_SET_O: begin
                        for (int k = 0; k < NUM_BITS; k++) begin
                            if (be[k/8]) s_reg_data_o[k] <= s_reg_data_o[k] | wdata[k];
                        end
                    end
                    ADDR_CLR_O: begin
                        for (int k = 0; k < NUM_BITS; k++) begin
                            if (be[k/8]) s_reg_data_o[k] <= s_reg_data_o[k] & ~wdata[k];
                        end
                    end
                    ADDR_TGL_O: begin
                        for (int k = 0; k < NUM_BITS; k++) begin
                            if (be[k/8]) s_reg_data_o[k] <= s_reg_data_o[k] ^ wdata[k];
                        end
                    end
                    ADDR_DEB_TH: begin
                        if (be[0]) s_reg_deb_th[7:0]   <= wdata[7:0];
                        if (be[1]) s_reg_deb_th[15:8]  <= wdata[15:8];
                        if (be[2]) s_reg_deb_th[23:16] <= wdata[23:16];
                        if (be[3]) s_reg_deb_th[31:24] <= wdata[31:24];
                    end
                    ADDR_DEB_EN: begin
                        for (int k = 0; k < NUM_BITS; k++) begin
                            if (be[k/8]) s_reg_deb_en[k] <= wdata[k];
                        end
                    end
                    ADDR_INV_IN: begin
                        for (int k = 0; k < NUM_BITS; k++) begin
                            if (be[k/8]) s_reg_inv_in[k] <= wdata[k];
                        end
                    end
                    ADDR_INV_OUT: begin
                        for (int k = 0; k < NUM_BITS; k++) begin
                            if (be[k/8]) s_reg_inv_out[k] <= wdata[k];
                        end
                    end
                    ADDR_OD_EN: begin
                        for (int k = 0; k < NUM_BITS; k++) begin
                            if (be[k/8]) s_reg_od_en[k] <= wdata[k];
                        end
                    end
                    ADDR_WR_MASK: begin
                        for (int k = 0; k < NUM_BITS; k++) begin
                            if (be[k/8]) s_reg_wr_mask[k] <= wdata[k];
                        end
                    end
                    ADDR_PU_EN: begin
                        for (int k = 0; k < NUM_BITS; k++) begin
                            if (be[k/8]) s_reg_pu_en[k] <= wdata[k];
                        end
                    end
                    ADDR_PD_EN: begin
                        for (int k = 0; k < NUM_BITS; k++) begin
                            if (be[k/8]) s_reg_pd_en[k] <= wdata[k];
                        end
                    end
                    ADDR_PWM_EN: begin
                        for (int k = 0; k < NUM_BITS; k++) begin
                            if (be[k/8]) s_reg_pwm_en[k] <= wdata[k];
                        end
                    end
                    ADDR_PWM_CFG: begin
                        if (be[0]) s_reg_pwm_cfg[7:0]   <= wdata[7:0];
                        if (be[1]) s_reg_pwm_cfg[15:8]  <= wdata[15:8];
                        if (be[2]) s_reg_pwm_cfg[23:16] <= wdata[23:16];
                        if (be[3]) s_reg_pwm_cfg[31:24] <= wdata[31:24];
                    end
                    default: begin
                        if (addr[6:0] >= ADDR_PWM_DUTY) begin
                            if (pwm_duty_idx < 32'd32) begin
                                if (pwm_duty_int < NUM_BITS) begin
                                    if (be[0]) s_reg_pwm_duty[pwm_duty_int][7:0]  <= wdata[7:0];
                                    if (be[1]) s_reg_pwm_duty[pwm_duty_int][15:8] <= wdata[15:8];
                                end
                            end
                        end
                    end
                endcase
            end
        end
    end

    // Register Reads
    always_comb begin : proc_reg_read
        rdata = '0;
        case (addr[6:0])
            ADDR_DATA_I:  rdata[NUM_BITS-1:0] = gpio_i_deb;
            ADDR_DATA_O:  rdata[NUM_BITS-1:0] = s_reg_data_o;
            ADDR_DIR   :  rdata[NUM_BITS-1:0] = s_reg_dir;
            ADDR_INT_EN:  rdata[NUM_BITS-1:0] = s_reg_int_en;
            ADDR_INT_TYP: rdata[NUM_BITS-1:0] = s_reg_int_typ;
            ADDR_INT_POL: rdata[NUM_BITS-1:0] = s_reg_int_pol;
            ADDR_INT_ANY: rdata[NUM_BITS-1:0] = s_reg_int_any;
            ADDR_INT_STS: begin
                for (int k = 0; k < NUM_BITS; k++) begin
                    if (s_reg_int_typ[k]) rdata[k] = s_reg_int_sts[k];
                    else                  rdata[k] = intr_cond[k];
                end
            end
            ADDR_DEB_TH:  rdata = s_reg_deb_th;
            ADDR_DEB_EN:  rdata[NUM_BITS-1:0] = s_reg_deb_en;
            ADDR_INV_IN:  rdata[NUM_BITS-1:0] = s_reg_inv_in;
            ADDR_INV_OUT: rdata[NUM_BITS-1:0] = s_reg_inv_out;
            ADDR_OD_EN:   rdata[NUM_BITS-1:0] = s_reg_od_en;
            ADDR_WR_MASK: rdata[NUM_BITS-1:0] = s_reg_wr_mask;
            ADDR_PU_EN:   rdata[NUM_BITS-1:0] = s_reg_pu_en;
            ADDR_PD_EN:   rdata[NUM_BITS-1:0] = s_reg_pd_en;
            ADDR_PWM_EN:  rdata[NUM_BITS-1:0] = s_reg_pwm_en;
            ADDR_PWM_CFG: rdata = s_reg_pwm_cfg;
            default: begin
                if (addr[6:0] >= ADDR_PWM_DUTY) begin
                    if (pwm_duty_idx < 32'd32) begin
                        if (pwm_duty_int < NUM_BITS) rdata[15:0] = s_reg_pwm_duty[pwm_duty_int];
                    end
                end else begin
                    rdata = 32'hDEADBEEF;
                end
            end
        endcase
    end

    // Combined Interrupt Output
    always_comb begin : proc_intr_out
        intr = 1'b0;
        for (int m = 0; m < NUM_BITS; m++) begin
            if (s_reg_int_en[m]) begin
                if (s_reg_int_typ[m]) begin
                    if (s_reg_int_sts[m]) intr = 1'b1;
                end else begin
                    if (intr_cond[m]) intr = 1'b1;
                end
            end
        end
    end

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) ack <= 1'b0;
        else          ack <= (we || re);
    end

endmodule
