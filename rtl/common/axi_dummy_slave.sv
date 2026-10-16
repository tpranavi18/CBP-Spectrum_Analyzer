// ============================================================================
// File: axi_dummy_slave.sv
// Project: CBP-Spectrum_Analyzer
//
// Description:
//   Generic AXI4 Dummy Slave module.
//   Terminates unmapped / reserved interconnect master ports safely:
//     - Responds with configurable response (default DECERR = 2'b11).
//     - Read data driven to 0x0000_0000.
//     - Correct AXI4 handshaking on AW, W, B, AR, R channels.
//     - Prevents bus stalls or deadlocks on unassigned address access.
// ============================================================================

`timescale 1ns/1ps
`default_nettype none

module axi_dummy_slave #(
    parameter DATA_WIDTH   = 32,
    parameter ADDR_WIDTH   = 32,
    parameter STRB_WIDTH   = DATA_WIDTH / 8,
    parameter ID_WIDTH     = 8,
    parameter AWUSER_WIDTH = 1,
    parameter WUSER_WIDTH  = 1,
    parameter BUSER_WIDTH  = 1,
    parameter ARUSER_WIDTH = 1,
    parameter RUSER_WIDTH  = 1,
    parameter [1:0] RESP   = 2'b11   // 2'b11: DECERR (Decode Error)
)(
    input  wire                     clk,
    input  wire                     rst,

    // AXI4 Write Address Channel
    input  wire [ID_WIDTH-1:0]      s_axi_awid,
    input  wire [ADDR_WIDTH-1:0]    s_axi_awaddr,
    input  wire [7:0]               s_axi_awlen,
    input  wire [2:0]               s_axi_awsize,
    input  wire [1:0]               s_axi_awburst,
    input  wire                     s_axi_awlock,
    input  wire [3:0]               s_axi_awcache,
    input  wire [2:0]               s_axi_awprot,
    input  wire [3:0]               s_axi_awqos,
    input  wire [3:0]               s_axi_awregion,
    input  wire [AWUSER_WIDTH-1:0]  s_axi_awuser,
    input  wire                     s_axi_awvalid,
    output reg                      s_axi_awready,

    // AXI4 Write Data Channel
    input  wire [DATA_WIDTH-1:0]    s_axi_wdata,
    input  wire [STRB_WIDTH-1:0]    s_axi_wstrb,
    input  wire                     s_axi_wlast,
    input  wire [WUSER_WIDTH-1:0]   s_axi_wuser,
    input  wire                     s_axi_wvalid,
    output reg                      s_axi_wready,

    // AXI4 Write Response Channel
    output reg  [ID_WIDTH-1:0]      s_axi_bid,
    output reg  [1:0]               s_axi_bresp,
    output reg  [BUSER_WIDTH-1:0]   s_axi_buser,
    output reg                      s_axi_bvalid,
    input  wire                     s_axi_bready,

    // AXI4 Read Address Channel
    input  wire [ID_WIDTH-1:0]      s_axi_arid,
    input  wire [ADDR_WIDTH-1:0]    s_axi_araddr,
    input  wire [7:0]               s_axi_arlen,
    input  wire [2:0]               s_axi_arsize,
    input  wire [1:0]               s_axi_arburst,
    input  wire                     s_axi_arlock,
    input  wire [3:0]               s_axi_arcache,
    input  wire [2:0]               s_axi_arprot,
    input  wire [3:0]               s_axi_arqos,
    input  wire [3:0]               s_axi_arregion,
    input  wire [ARUSER_WIDTH-1:0]  s_axi_aruser,
    input  wire                     s_axi_arvalid,
    output reg                      s_axi_arready,

    // AXI4 Read Data Channel
    output reg  [ID_WIDTH-1:0]      s_axi_rid,
    output reg  [DATA_WIDTH-1:0]    s_axi_rdata,
    output reg  [1:0]               s_axi_rresp,
    output reg                      s_axi_rlast,
    output reg  [RUSER_WIDTH-1:0]   s_axi_ruser,
    output reg                      s_axi_rvalid,
    input  wire                     s_axi_rready
);

    // =========================================================================
    // Write Channel Logic
    // =========================================================================
    reg [ID_WIDTH-1:0] awid_reg;
    reg                aw_done;
    reg                w_done;

    wire aw_fire = s_axi_awvalid && s_axi_awready;
    wire w_fire  = s_axi_wvalid  && s_axi_wready && s_axi_wlast;
    wire b_fire  = s_axi_bvalid  && s_axi_bready;

    always @(posedge clk) begin
        if (rst) begin
            s_axi_awready <= 1'b1;
            s_axi_wready  <= 1'b1;
            s_axi_bvalid  <= 1'b0;
            s_axi_bid     <= {ID_WIDTH{1'b0}};
            s_axi_bresp   <= RESP;
            s_axi_buser   <= {BUSER_WIDTH{1'b0}};
            awid_reg      <= {ID_WIDTH{1'b0}};
            aw_done       <= 1'b0;
            w_done        <= 1'b0;
        end else begin
            // Track AW handshake
            if (aw_fire) begin
                awid_reg      <= s_axi_awid;
                aw_done       <= 1'b1;
                s_axi_awready <= 1'b0;
            end

            // Track W handshake (final beat)
            if (w_fire) begin
                w_done       <= 1'b1;
                s_axi_wready <= 1'b0;
            end

            // Issue BVALID when both AW and W completed
            if ((aw_done || aw_fire) && (w_done || w_fire) && !s_axi_bvalid) begin
                s_axi_bvalid <= 1'b1;
                s_axi_bid    <= (aw_fire) ? s_axi_awid : awid_reg;
                s_axi_bresp  <= RESP;
                aw_done      <= 1'b0;
                w_done       <= 1'b0;
            end

            // Clear BVALID on BREADY
            if (b_fire) begin
                s_axi_bvalid  <= 1'b0;
                s_axi_awready <= 1'b1;
                s_axi_wready  <= 1'b1;
            end
        end
    end

    // =========================================================================
    // Read Channel Logic
    // =========================================================================
    reg [ID_WIDTH-1:0] arid_reg;
    reg [7:0]          arlen_reg;
    reg [7:0]          beat_count;
    reg                r_busy;

    wire ar_fire = s_axi_arvalid && s_axi_arready;
    wire r_fire  = s_axi_rvalid  && s_axi_rready;

    always @(posedge clk) begin
        if (rst) begin
            s_axi_arready <= 1'b1;
            s_axi_rvalid  <= 1'b0;
            s_axi_rid     <= {ID_WIDTH{1'b0}};
            s_axi_rdata   <= {DATA_WIDTH{1'b0}};
            s_axi_rresp   <= RESP;
            s_axi_rlast   <= 1'b0;
            s_axi_ruser   <= {RUSER_WIDTH{1'b0}};
            arid_reg      <= {ID_WIDTH{1'b0}};
            arlen_reg     <= 8'd0;
            beat_count    <= 8'd0;
            r_busy        <= 1'b0;
        end else begin
            if (ar_fire) begin
                s_axi_arready <= 1'b0;
                arid_reg      <= s_axi_arid;
                arlen_reg     <= s_axi_arlen; // burst length
                beat_count    <= 8'd0;
                r_busy        <= 1'b1;

                // First read beat
                s_axi_rvalid  <= 1'b1;
                s_axi_rid     <= s_axi_arid;
                s_axi_rdata   <= {DATA_WIDTH{1'b0}};
                s_axi_rresp   <= RESP;
                s_axi_rlast   <= (s_axi_arlen == 8'd0);
            end else if (r_busy) begin
                if (r_fire) begin
                    if (s_axi_rlast) begin
                        s_axi_rvalid  <= 1'b0;
                        s_axi_rlast   <= 1'b0;
                        r_busy        <= 1'b0;
                        s_axi_arready <= 1'b1;
                    end else begin
                        beat_count  <= beat_count + 8'd1;
                        s_axi_rdata <= {DATA_WIDTH{1'b0}};
                        s_axi_rresp <= RESP;
                        if (beat_count + 8'd1 == arlen_reg)
                            s_axi_rlast <= 1'b1;
                    end
                end
            end
        end
    end

endmodule

`default_nettype wire
