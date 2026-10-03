// ============================================================================
// AXI4 -> AXI4-Lite single-beat bridge
//
// Purpose:
//   Provides a clean protocol boundary between the CARDIOEDGE AXI4
//   interconnect and native AXI4-Lite peripherals such as GPIO and Timer.
//
// Design assumptions for this integration:
//   - One outstanding transaction at a time per bridge.
//   - Only single-beat AXI4 transactions are accepted (AWLEN/ARLEN ignored;
//     the CARDIOEDGE integration issues single-beat accesses).
//   - AXI IDs are preserved on B/R responses.
//   - AXI4-only USER fields are not forwarded to AXI4-Lite.
//   - WLAST is not required by the AXI4-Lite side.
// ============================================================================

module axi4_to_axi4lite_bridge #(
    parameter DATA_WIDTH   = 32,
    parameter ADDR_WIDTH   = 32,
    parameter STRB_WIDTH   = 4,
    parameter ID_WIDTH     = 8,
    parameter USER_WIDTH   = 1
)(
    input  wire                     aclk,
    input  wire                     aresetn,

    // ------------------------------------------------------------------------
    // AXI4 side: upstream interconnect master port
    // ------------------------------------------------------------------------
    input  wire [ID_WIDTH-1:0]      s_awid,
    input  wire [ADDR_WIDTH-1:0]    s_awaddr,
    input  wire [7:0]               s_awlen,
    input  wire [2:0]               s_awsize,
    input  wire [1:0]               s_awburst,
    input  wire                     s_awlock,
    input  wire [3:0]               s_awcache,
    input  wire [2:0]               s_awprot,
    input  wire [3:0]               s_awqos,
    input  wire [3:0]               s_awregion,
    input  wire [USER_WIDTH-1:0]     s_awuser,
    input  wire                     s_awvalid,
    output wire                     s_awready,

    input  wire [DATA_WIDTH-1:0]    s_wdata,
    input  wire [STRB_WIDTH-1:0]    s_wstrb,
    input  wire                     s_wlast,
    input  wire [USER_WIDTH-1:0]     s_wuser,
    input  wire                     s_wvalid,
    output wire                     s_wready,

    output wire [ID_WIDTH-1:0]      s_bid,
    output wire [1:0]               s_bresp,
    output wire [USER_WIDTH-1:0]     s_buser,
    output wire                     s_bvalid,
    input  wire                     s_bready,

    input  wire [ID_WIDTH-1:0]      s_arid,
    input  wire [ADDR_WIDTH-1:0]    s_araddr,
    input  wire [7:0]               s_arlen,
    input  wire [2:0]               s_arsize,
    input  wire [1:0]               s_arburst,
    input  wire                     s_arlock,
    input  wire [3:0]               s_arcache,
    input  wire [2:0]               s_arprot,
    input  wire [3:0]               s_arqos,
    input  wire [3:0]               s_arregion,
    input  wire [USER_WIDTH-1:0]     s_aruser,
    input  wire                     s_arvalid,
    output wire                     s_arready,

    output wire [ID_WIDTH-1:0]      s_rid,
    output wire [DATA_WIDTH-1:0]    s_rdata,
    output wire [1:0]               s_rresp,
    output wire                     s_rlast,
    output wire [USER_WIDTH-1:0]     s_ruser,
    output wire                     s_rvalid,
    input  wire                     s_rready,

    // ------------------------------------------------------------------------
    // AXI4-Lite side: downstream GPIO/Timer
    // ------------------------------------------------------------------------
    output wire [ADDR_WIDTH-1:0]    m_awaddr,
    output wire [2:0]               m_awprot,
    output wire                     m_awvalid,
    input  wire                     m_awready,

    output wire [DATA_WIDTH-1:0]    m_wdata,
    output wire [STRB_WIDTH-1:0]    m_wstrb,
    output wire                     m_wvalid,
    input  wire                     m_wready,

    input  wire [1:0]               m_bresp,
    input  wire                     m_bvalid,
    output wire                     m_bready,

    output wire [ADDR_WIDTH-1:0]    m_araddr,
    output wire [2:0]               m_arprot,
    output wire                     m_arvalid,
    input  wire                     m_arready,

    input  wire [DATA_WIDTH-1:0]    m_rdata,
    input  wire [1:0]               m_rresp,
    input  wire                     m_rvalid,
    output wire                     m_rready
);

    localparam ST_IDLE      = 3'd0;
    localparam ST_WRITE     = 3'd1;
    localparam ST_BRESP     = 3'd2;
    localparam ST_READ      = 3'd3;
    localparam ST_RRESP     = 3'd4;

    reg [2:0] state_reg;

    reg                  aw_hold;
    reg                  w_hold;
    reg                  aw_sent;
    reg                  w_sent;
    reg [ID_WIDTH-1:0]   awid_reg;
    reg [ADDR_WIDTH-1:0] awaddr_reg;
    reg [2:0]            awprot_reg;
    reg [DATA_WIDTH-1:0] wdata_reg;
    reg [STRB_WIDTH-1:0] wstrb_reg;

    reg [ID_WIDTH-1:0]   arid_reg;
    reg [ADDR_WIDTH-1:0] araddr_reg;
    reg [2:0]            arprot_reg;

    reg [ID_WIDTH-1:0]   bid_reg;
    reg [1:0]            bresp_reg;
    reg                  bvalid_reg;

    reg [ID_WIDTH-1:0]   rid_reg;
    reg [DATA_WIDTH-1:0] rdata_reg;
    reg [1:0]            rresp_reg;
    reg                  rvalid_reg;

    // ------------------------------------------------------------------------
    // Upstream ready signals.
    //
    // AW and W are accepted independently while the bridge is idle. This is
    // legal AXI behavior and also supports masters that issue the channels on
    // different cycles. Once both are captured, the bridge performs one
    // AXI4-Lite write.
    // ------------------------------------------------------------------------
    wire ar_hold_busy = 1'b0;

    assign s_awready = aresetn &&
                       (state_reg == ST_IDLE) && !aw_hold && !ar_hold_busy;

    assign s_wready  = aresetn &&
                       (state_reg == ST_IDLE) && !w_hold && !ar_hold_busy;

    // AXI4-Lite read is accepted only when there is no partial write.
    assign s_arready = aresetn &&
                       (state_reg == ST_IDLE) && !aw_hold && !w_hold;

    // ------------------------------------------------------------------------
    // Downstream AXI4-Lite write channel.
    // Hold VALID until READY. This is important for registered AXI4-Lite
    // slaves such as the supplied Gemini GPIO/Timer adapters.
    // ------------------------------------------------------------------------
    assign m_awaddr  = awaddr_reg;
    assign m_awprot  = awprot_reg;
    assign m_awvalid = (state_reg == ST_WRITE) && aw_hold && w_hold && !aw_sent;

    assign m_wdata   = wdata_reg;
    assign m_wstrb   = wstrb_reg;
    assign m_wvalid  = (state_reg == ST_WRITE) && aw_hold && w_hold && !w_sent;

    assign m_bready  = (state_reg == ST_BRESP);

    // ------------------------------------------------------------------------
    // Downstream AXI4-Lite read channel.
    // ------------------------------------------------------------------------
    assign m_araddr  = araddr_reg;
    assign m_arprot  = arprot_reg;
    assign m_arvalid = (state_reg == ST_READ);
    assign m_rready  = (state_reg == ST_RRESP);

    // ------------------------------------------------------------------------
    // Upstream responses.
    // ------------------------------------------------------------------------
    assign s_bid     = bid_reg;
    assign s_bresp   = bresp_reg;
    assign s_buser   = {USER_WIDTH{1'b0}};
    assign s_bvalid  = bvalid_reg;

    assign s_rid     = rid_reg;
    assign s_rdata   = rdata_reg;
    assign s_rresp   = rresp_reg;
    assign s_rlast   = 1'b1;
    assign s_ruser   = {USER_WIDTH{1'b0}};
    assign s_rvalid  = rvalid_reg;

    // ------------------------------------------------------------------------
    // Sequential controller.
    // ------------------------------------------------------------------------
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            state_reg  <= ST_IDLE;

            aw_hold    <= 1'b0;
            w_hold     <= 1'b0;
            aw_sent    <= 1'b0;
            w_sent     <= 1'b0;
            awid_reg   <= {ID_WIDTH{1'b0}};
            awaddr_reg <= {ADDR_WIDTH{1'b0}};
            awprot_reg <= 3'b000;
            wdata_reg  <= {DATA_WIDTH{1'b0}};
            wstrb_reg  <= {STRB_WIDTH{1'b0}};

            arid_reg   <= {ID_WIDTH{1'b0}};
            araddr_reg <= {ADDR_WIDTH{1'b0}};
            arprot_reg <= 3'b000;

            bid_reg    <= {ID_WIDTH{1'b0}};
            bresp_reg  <= 2'b00;
            bvalid_reg <= 1'b0;

            rid_reg    <= {ID_WIDTH{1'b0}};
            rdata_reg  <= {DATA_WIDTH{1'b0}};
            rresp_reg  <= 2'b00;
            rvalid_reg <= 1'b0;
        end
        else begin
            case (state_reg)

                ST_IDLE: begin
                    // Default: response valid flags remain cleared after
                    // their handshake.
                    bvalid_reg <= 1'b0;
                    rvalid_reg <= 1'b0;

                    // Capture AW channel.
                    if (s_awvalid && s_awready) begin
                        aw_hold    <= 1'b1;
                        aw_sent    <= 1'b0;
                        awid_reg   <= s_awid;
                        awaddr_reg <= s_awaddr;
                        awprot_reg <= s_awprot;
                    end

                    // Capture W channel.
                    if (s_wvalid && s_wready) begin
                        w_hold    <= 1'b1;
                        w_sent    <= 1'b0;
                        wdata_reg <= s_wdata;
                        wstrb_reg <= s_wstrb;
                    end

                    // A read can be accepted only when no write channel is
                    // being collected.
                    if (s_arvalid && s_arready) begin
                        arid_reg   <= s_arid;
                        araddr_reg <= s_araddr;
                        arprot_reg <= s_arprot;
                        state_reg  <= ST_READ;
                    end
                    else if ((aw_hold || (s_awvalid && s_awready)) &&
                             (w_hold  || (s_wvalid  && s_wready))) begin
                        state_reg <= ST_WRITE;
                    end
                end

                ST_WRITE: begin
                    // AW and W are independent AXI4-Lite channels. Hold each
                    // VALID until its corresponding READY handshake occurs.
                    if (m_awvalid && m_awready) begin
                        aw_sent <= 1'b1;
                    end

                    if (m_wvalid && m_wready) begin
                        w_sent <= 1'b1;
                    end

                    if ((aw_sent || (m_awvalid && m_awready)) &&
                        (w_sent  || (m_wvalid  && m_wready))) begin
                        aw_hold <= 1'b0;
                        w_hold  <= 1'b0;
                        state_reg <= ST_BRESP;
                    end
                end

                ST_BRESP: begin
                    if (m_bvalid) begin
                        bid_reg    <= awid_reg;
                        bresp_reg  <= m_bresp;
                        bvalid_reg <= 1'b1;
                    end

                    if (bvalid_reg && s_bready) begin
                        bvalid_reg <= 1'b0;
                        state_reg  <= ST_IDLE;
                    end
                end

                ST_READ: begin
                    if (m_arvalid && m_arready) begin
                        state_reg <= ST_RRESP;
                    end
                end

                ST_RRESP: begin
                    if (m_rvalid) begin
                        rid_reg    <= arid_reg;
                        rdata_reg  <= m_rdata;
                        rresp_reg  <= m_rresp;
                        rvalid_reg <= 1'b1;
                    end

                    if (rvalid_reg && s_rready) begin
                        rvalid_reg <= 1'b0;
                        state_reg  <= ST_IDLE;
                    end
                end

                default: begin
                    state_reg <= ST_IDLE;
                    aw_hold   <= 1'b0;
                    w_hold    <= 1'b0;
                    aw_sent   <= 1'b0;
                    w_sent    <= 1'b0;
                    bvalid_reg <= 1'b0;
                    rvalid_reg <= 1'b0;
                end
            endcase
        end
    end

endmodule
