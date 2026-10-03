//
// General Purpose Timer Registers
//
// Description:
//   Register file for the General Timer.
//   Handles Read/Write access and provides control signals to core.
//

module timer_regs (
    input  logic        clk,
    input  logic        rst_n,

    // Bus Interface (Generic)
    input  logic        cs,
    input  logic        we,
    input  logic [5:0]  addr,
    input  logic [31:0] wdata,
    output logic [31:0] rdata,

    // Core Interface
    output logic        en,
    output logic        mode,
    output logic        dir,
    output logic        pwm_en,
    output logic        ext_en,
    output logic        cap_en,
    output logic        pre_en,
    output logic [15:0] pre_val,
    output logic [31:0] load_val,
    output logic [31:0] cmp_val,
    output logic        load_cmd,
    input  logic [31:0] current_val,
    input  logic [31:0] capture_val,
    input  logic        capture_stb,
    input  logic        core_irq,

    // System Interface
    output logic        intr_o
);

    // Register Map Offsets
    localparam ADDR_CTRL    = 6'h00;
    localparam ADDR_LOAD    = 6'h04;
    localparam ADDR_VAL     = 6'h08;
    localparam ADDR_PRE     = 6'h0C;
    localparam ADDR_INT_EN  = 6'h10;
    localparam ADDR_INT_STS = 6'h14;
    localparam ADDR_CMP     = 6'h18; // New compare
    localparam ADDR_CAP     = 6'h1C; // New capture

    // Registers
    logic [31:0] reg_ctrl;
    logic [31:0] reg_load;
    logic [31:0] reg_pre;
    logic [31:0] reg_cmp;
    logic [31:0] reg_cap;
    logic [31:0] reg_int_en;
    logic [31:0] reg_int_sts;

    // Control Assignments
    assign en       = reg_ctrl[0];
    assign mode     = reg_ctrl[1];
    assign pre_en   = reg_ctrl[2];
    assign dir      = reg_ctrl[3];
    assign pwm_en   = reg_ctrl[4];
    assign ext_en   = reg_ctrl[5];
    assign cap_en   = reg_ctrl[6];

    assign pre_val  = reg_pre[15:0];
    assign cmp_val  = reg_cmp;
    
    // Load command is a strobe when writing to LOAD register
    assign load_cmd = (cs && we && (addr == ADDR_LOAD));
    
    // Bypass load_val with wdata during write to ensure immediate load of new value
    assign load_val = (load_cmd) ? wdata : reg_load;

    // Interrupt Output
    // [0] = Timer Expire, [1] = Capture Event
    assign intr_o = |(reg_int_sts & reg_int_en);

    // Read Logic
    always_comb begin
        rdata = '0;
        if (cs) begin
            case (addr)
                ADDR_CTRL:    rdata = reg_ctrl;
                ADDR_LOAD:    rdata = reg_load;
                ADDR_VAL:     rdata = current_val;
                ADDR_PRE:     rdata = reg_pre;
                ADDR_INT_EN:  rdata = reg_int_en;
                ADDR_INT_STS: rdata = reg_int_sts;
                ADDR_CMP:     rdata = reg_cmp;
                ADDR_CAP:     rdata = reg_cap;
                default:      rdata = '0;
            endcase
        end
    end

    // Write Logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_ctrl    <= '0;
            reg_load    <= '0;
            reg_pre     <= '0;
            reg_cmp     <= '0;
            reg_cap     <= '0;
            reg_int_en  <= '0;
            reg_int_sts <= '0;
        end else begin
            // Sticky Interrupt Status
            if (core_irq)      reg_int_sts[0] <= 1'b1; // Expire
            if (capture_stb)   reg_int_sts[1] <= 1'b1; // Capture

            // Capture Register Update (Hardware)
            // Latch current capture value when strobe fires (if enabled)
            if (capture_stb && cap_en) begin
                reg_cap <= capture_val;
            end

            // Bus Writes
            if (cs && we) begin
                case (addr)
                    ADDR_CTRL:    reg_ctrl <= wdata;
                    ADDR_LOAD:    reg_load <= wdata;
                    ADDR_PRE:     reg_pre  <= wdata;
                    ADDR_CMP:     reg_cmp  <= wdata;
                    ADDR_INT_EN:  reg_int_en <= wdata;
                    ADDR_INT_STS: begin
                        // W1C (Write 1 to Clear)
                        if (wdata[0]) reg_int_sts[0] <= 1'b0;
                        if (wdata[1]) reg_int_sts[1] <= 1'b0;
                    end
                    default: ;
                endcase
            end
        end
    end

endmodule
