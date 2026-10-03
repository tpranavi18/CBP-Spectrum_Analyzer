`timescale 1ns/1ps

// ============================================================================
// AXI4-Lite Slave Adapter
//
// Purpose:
//   Converts an AXI4-Lite slave interface into a synchronous register bus
//   for GPIO and Timer peripherals.
//
// Register-bus interface:
//   reg_addr  - byte address of the access
//   reg_wdata - write data
//   reg_rdata - register read data
//   reg_we    - write-enable pulse
//   reg_re    - read-enable pulse
//   reg_be    - byte enables for writes
//
// Supports single-beat AXI4-Lite accesses.
// Read address setup and read-data capture occur in separate FSM states.
// ============================================================================

module axi4lite_slave_adapter #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter STRB_WIDTH = DATA_WIDTH / 8
)(
    input  wire                     aclk,
    input  wire                     aresetn,

    // Write Address Channel
    input  wire [ADDR_WIDTH-1:0]    s_axi_awaddr,
    input  wire [2:0]               s_axi_awprot,
    input  wire                     s_axi_awvalid,
    output reg                      s_axi_awready,

    // Write Data Channel
    input  wire [DATA_WIDTH-1:0]    s_axi_wdata,
    input  wire [STRB_WIDTH-1:0]    s_axi_wstrb,
    input  wire                     s_axi_wvalid,
    output reg                      s_axi_wready,

    // Write Response Channel
    output reg  [1:0]               s_axi_bresp,
    output reg                      s_axi_bvalid,
    input  wire                     s_axi_bready,

    // Read Address Channel
    input  wire [ADDR_WIDTH-1:0]    s_axi_araddr,
    input  wire [2:0]               s_axi_arprot,
    input  wire                     s_axi_arvalid,
    output reg                      s_axi_arready,

    // Read Data Channel
    output reg  [DATA_WIDTH-1:0]    s_axi_rdata,
    output reg  [1:0]               s_axi_rresp,
    output reg                      s_axi_rvalid,
    input  wire                     s_axi_rready,

    // Internal Register Bus
    output reg  [ADDR_WIDTH-1:0]    reg_addr,
    output reg  [DATA_WIDTH-1:0]    reg_wdata,
    input  wire [DATA_WIDTH-1:0]    reg_rdata,
    output reg                      reg_we,
    output reg                      reg_re,
    output reg  [STRB_WIDTH-1:0]    reg_be
);

    // ------------------------------------------------------------------------
    // FSM encoding
    // ------------------------------------------------------------------------
    localparam ST_IDLE  = 3'd0;
    localparam ST_WRITE = 3'd1;
    localparam ST_BRESP = 3'd2;
    localparam ST_READ  = 3'd3;
    localparam ST_RRESP = 3'd4;

    reg [2:0] state;

    // Captured transaction information
    reg [ADDR_WIDTH-1:0] aw_addr_q;
    reg [DATA_WIDTH-1:0] w_data_q;
    reg [STRB_WIDTH-1:0] w_strb_q;
    reg [ADDR_WIDTH-1:0] ar_addr_q;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            state          <= ST_IDLE;

            s_axi_awready  <= 1'b0;
            s_axi_wready   <= 1'b0;
            s_axi_bvalid   <= 1'b0;
            s_axi_bresp    <= 2'b00;

            s_axi_arready  <= 1'b0;
            s_axi_rvalid   <= 1'b0;
            s_axi_rdata    <= {DATA_WIDTH{1'b0}};
            s_axi_rresp    <= 2'b00;

            reg_addr       <= {ADDR_WIDTH{1'b0}};
            reg_wdata      <= {DATA_WIDTH{1'b0}};
            reg_we         <= 1'b0;
            reg_re         <= 1'b0;
            reg_be         <= {STRB_WIDTH{1'b0}};

            aw_addr_q      <= {ADDR_WIDTH{1'b0}};
            w_data_q       <= {DATA_WIDTH{1'b0}};
            w_strb_q       <= {STRB_WIDTH{1'b0}};
            ar_addr_q      <= {ADDR_WIDTH{1'b0}};
        end
        else begin
            // Default: deassert one-cycle control pulses and ready signals.
            reg_we        <= 1'b0;
            reg_re        <= 1'b0;
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
            s_axi_arready <= 1'b0;

            case (state)

                // ------------------------------------------------------------
                ST_IDLE: begin
                    // Accept a write when address and data are both valid.
                    if (s_axi_awvalid && s_axi_wvalid &&
                        !s_axi_bvalid && !s_axi_rvalid) begin

                        s_axi_awready <= 1'b1;
                        s_axi_wready  <= 1'b1;

                        aw_addr_q     <= s_axi_awaddr;
                        w_data_q      <= s_axi_wdata;
                        w_strb_q      <= s_axi_wstrb;

                        state         <= ST_WRITE;
                    end
                    else if (s_axi_arvalid &&
                             !s_axi_bvalid && !s_axi_rvalid) begin

                        s_axi_arready <= 1'b1;
                        ar_addr_q     <= s_axi_araddr;

                        state         <= ST_READ;
                    end
                end

                // ------------------------------------------------------------
                ST_WRITE: begin
                    // Issue the register write.
                    reg_addr  <= aw_addr_q;
                    reg_wdata <= w_data_q;
                    reg_be    <= w_strb_q;
                    reg_we    <= 1'b1;

                    state     <= ST_BRESP;
                end

                // ------------------------------------------------------------
                ST_BRESP: begin
                    // Hold the write response until the master accepts it.
                    s_axi_bresp  <= 2'b00;

                    if (!s_axi_bvalid) begin
                        s_axi_bvalid <= 1'b1;
                    end
                    else if (s_axi_bready) begin
                        s_axi_bvalid <= 1'b0;
                        state        <= ST_IDLE;
                    end
                end

                // ------------------------------------------------------------
                ST_READ: begin
                    // Present the requested register address and assert read.
                    // Read data is captured in the following state.
                    reg_addr <= ar_addr_q;
                    reg_re   <= 1'b1;

                    state    <= ST_RRESP;
                end

                // ------------------------------------------------------------
                ST_RRESP: begin
                    // Capture the register data after the address has settled.
                    // Hold RVALID and RDATA until the master accepts the data.
                    if (!s_axi_rvalid) begin
                        s_axi_rdata  <= reg_rdata;
                        s_axi_rresp  <= 2'b00;
                        s_axi_rvalid <= 1'b1;
                    end
                    else if (s_axi_rready) begin
                        s_axi_rvalid <= 1'b0;
                        state        <= ST_IDLE;
                    end
                end

                // ------------------------------------------------------------
                default: begin
                    state <= ST_IDLE;
                end

            endcase
        end
    end

endmodule
