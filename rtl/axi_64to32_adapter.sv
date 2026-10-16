// ============================================================================
// File: axi_64to32_adapter.sv
// Project: CBP-Spectrum_Analyzer
//
// Description:
//   AXI4 64-bit master -> 32-bit slave width converter.
//   Bridges VeeR EL2's 64-bit AXI master (IFU or LSU) to the 32-bit
//   interconnect.
//
// Design details:
//   - IFU READ (ARSIZE = 3, 8-byte aligned):
//       Performs two sequential 32-bit reads (low word, then high word)
//       and returns a single 64-bit RDATA beat.
//   - NARROW READ (ARSIZE <= 2):
//       Single 32-bit read; replicates 32-bit word across 64-bit lane.
//   - LSU WRITE (AWSIZE <= 2):
//       Single-beat write. Selects lower [31:0] or upper [63:32] based on
//       AWADDR[2] and WSTRB bits.
//   - Upstream bursts forwarded as sequential single-beat 32-bit transactions.
// ============================================================================

`timescale 1ns/1ps
`default_nettype none

module axi_64to32_adapter #(
    parameter M_ID_WIDTH = 3,   // VeeR AXI ID width
    parameter S_ID_WIDTH = 8    // Interconnect AXI ID width
)(
    input  wire        clk,
    input  wire        rst_l,  // active-low

    // -----------------------------------------------------------------------
    // 64-bit AXI4 slave port (connects to VeeR IFU or LSU)
    // -----------------------------------------------------------------------
    // Write address
    input  wire                     m_axi_awvalid,
    output wire                     m_axi_awready,
    input  wire [M_ID_WIDTH-1:0]   m_axi_awid,
    input  wire [31:0]             m_axi_awaddr,
    input  wire [7:0]              m_axi_awlen,
    input  wire [2:0]              m_axi_awsize,
    input  wire [1:0]              m_axi_awburst,
    input  wire                    m_axi_awlock,
    input  wire [3:0]              m_axi_awcache,
    input  wire [2:0]              m_axi_awprot,
    input  wire [3:0]              m_axi_awqos,
    input  wire [3:0]              m_axi_awregion,
    // Write data
    input  wire                    m_axi_wvalid,
    output wire                    m_axi_wready,
    input  wire [63:0]             m_axi_wdata,
    input  wire [7:0]              m_axi_wstrb,
    input  wire                    m_axi_wlast,
    // Write response
    output wire                    m_axi_bvalid,
    input  wire                    m_axi_bready,
    output wire [M_ID_WIDTH-1:0]   m_axi_bid,
    output wire [1:0]              m_axi_bresp,
    // Read address
    input  wire                    m_axi_arvalid,
    output wire                    m_axi_arready,
    input  wire [M_ID_WIDTH-1:0]   m_axi_arid,
    input  wire [31:0]             m_axi_araddr,
    input  wire [7:0]              m_axi_arlen,
    input  wire [2:0]              m_axi_arsize,
    input  wire [1:0]              m_axi_arburst,
    input  wire                    m_axi_arlock,
    input  wire [3:0]              m_axi_arcache,
    input  wire [2:0]              m_axi_arprot,
    input  wire [3:0]              m_axi_arqos,
    input  wire [3:0]              m_axi_arregion,
    // Read data
    output reg                     m_axi_rvalid,
    input  wire                    m_axi_rready,
    output reg  [M_ID_WIDTH-1:0]   m_axi_rid,
    output reg  [63:0]             m_axi_rdata,
    output reg  [1:0]              m_axi_rresp,
    output reg                     m_axi_rlast,

    // -----------------------------------------------------------------------
    // 32-bit AXI4 master port (connects to interconnect slave port)
    // -----------------------------------------------------------------------
    // Write address
    output wire                    s_axi_awvalid,
    input  wire                    s_axi_awready,
    output wire [S_ID_WIDTH-1:0]   s_axi_awid,
    output wire [31:0]             s_axi_awaddr,
    output wire [7:0]              s_axi_awlen,
    output wire [2:0]              s_axi_awsize,
    output wire [1:0]              s_axi_awburst,
    output wire                    s_axi_awlock,
    output wire [3:0]              s_axi_awcache,
    output wire [2:0]              s_axi_awprot,
    output wire [3:0]              s_axi_awqos,
    output wire [S_ID_WIDTH-1:0]   s_axi_awregion,
    // Write data
    output wire                    s_axi_wvalid,
    input  wire                    s_axi_wready,
    output wire [31:0]             s_axi_wdata,
    output wire [3:0]              s_axi_wstrb,
    output wire                    s_axi_wlast,
    // Write response
    input  wire                    s_axi_bvalid,
    output wire                    s_axi_bready,
    input  wire [S_ID_WIDTH-1:0]   s_axi_bid,
    input  wire [1:0]              s_axi_bresp,
    // Read address
    output reg                     s_axi_arvalid,
    input  wire                    s_axi_arready,
    output reg  [S_ID_WIDTH-1:0]   s_axi_arid,
    output reg  [31:0]             s_axi_araddr,
    output reg  [7:0]              s_axi_arlen,
    output reg  [2:0]              s_axi_arsize,
    output reg  [1:0]              s_axi_arburst,
    output reg                     s_axi_arlock,
    output reg  [3:0]              s_axi_arcache,
    output reg  [2:0]              s_axi_arprot,
    output reg  [3:0]              s_axi_arqos,
    output reg  [S_ID_WIDTH-1:0]   s_axi_arregion,
    // Read data
    input  wire                    s_axi_rvalid,
    output wire                    s_axi_rready,
    input  wire [S_ID_WIDTH-1:0]   s_axi_rid,
    input  wire [31:0]             s_axi_rdata,
    input  wire [1:0]              s_axi_rresp,
    input  wire                    s_axi_rlast
);

    // ========================================================================
    // READ PATH
    // ========================================================================
    typedef enum logic [2:0] {
        RD_IDLE        = 3'd0,
        RD_ADDR_LO     = 3'd1,
        RD_DATA_LO     = 3'd2,
        RD_ADDR_HI     = 3'd3,
        RD_DATA_HI     = 3'd4,
        RD_SINGLE_ADDR = 3'd5,
        RD_SINGLE_DATA = 3'd6,
        RD_RESP        = 3'd7
    } rd_state_t;

    rd_state_t rd_state;

    // Captured AR fields
    reg [M_ID_WIDTH-1:0] ar_id_q;
    reg [31:0]           ar_addr_q;
    reg [7:0]            ar_len_q;
    reg [2:0]            ar_size_q;
    reg [1:0]            ar_burst_q;
    reg                  ar_lock_q;
    reg [3:0]            ar_cache_q;
    reg [2:0]            ar_prot_q;
    reg [3:0]            ar_qos_q;
    reg [3:0]            ar_region_q;
    reg [7:0]            ar_beat_cnt;
    reg [31:0]           ar_cur_addr;

    // Data assembly
    reg [31:0]           rdata_lo_q;
    reg [31:0]           rdata_hi_q;
    reg [1:0]            rresp_q;

    wire wide_read = (ar_size_q == 3'd3);

    always_ff @(posedge clk or negedge rst_l) begin
        if (!rst_l) begin
            rd_state     <= RD_IDLE;
            ar_id_q      <= '0;
            ar_addr_q    <= '0;
            ar_len_q     <= '0;
            ar_size_q    <= '0;
            ar_burst_q   <= '0;
            ar_lock_q    <= '0;
            ar_cache_q   <= '0;
            ar_prot_q    <= '0;
            ar_qos_q     <= '0;
            ar_region_q  <= '0;
            ar_beat_cnt  <= '0;
            ar_cur_addr  <= '0;
            rdata_lo_q   <= '0;
            rresp_q      <= '0;
        end else begin
            case (rd_state)
                RD_IDLE: begin
                    if (m_axi_arvalid) begin
                        ar_id_q     <= m_axi_arid;
                        ar_addr_q   <= (m_axi_arsize == 3'd3) ? {m_axi_araddr[31:3], 3'b000} : m_axi_araddr;
                        ar_len_q    <= m_axi_arlen;
                        ar_size_q   <= m_axi_arsize;
                        ar_burst_q  <= m_axi_arburst;
                        ar_lock_q   <= m_axi_arlock;
                        ar_cache_q  <= m_axi_arcache;
                        ar_prot_q   <= m_axi_arprot;
                        ar_qos_q    <= m_axi_arqos;
                        ar_region_q <= m_axi_arregion;
                        ar_beat_cnt <= 8'd0;
                        ar_cur_addr <= (m_axi_arsize == 3'd3) ? {m_axi_araddr[31:3], 3'b000} : m_axi_araddr;
                        rresp_q     <= 2'b00;
                        if (m_axi_arsize == 3'd3)
                            rd_state <= RD_ADDR_LO;
                        else
                            rd_state <= RD_SINGLE_ADDR;
                    end
                end

                RD_ADDR_LO: begin
                    if (s_axi_arready)
                        rd_state <= RD_DATA_LO;
                end

                RD_DATA_LO: begin
                    if (s_axi_rvalid) begin
                        rdata_lo_q <= s_axi_rdata;
                        rresp_q    <= s_axi_rresp;
                        rd_state   <= RD_ADDR_HI;
                    end
                end

                RD_ADDR_HI: begin
                    if (s_axi_arready)
                        rd_state <= RD_DATA_HI;
                end

                RD_DATA_HI: begin
                    if (s_axi_rvalid) begin
                        rresp_q  <= (s_axi_rresp > rresp_q) ? s_axi_rresp : rresp_q;
                        rd_state <= RD_RESP;
                    end
                end

                RD_SINGLE_ADDR: begin
                    if (s_axi_arready)
                        rd_state <= RD_SINGLE_DATA;
                end

                RD_SINGLE_DATA: begin
                    if (s_axi_rvalid) begin
                        rdata_lo_q <= s_axi_rdata;
                        rresp_q    <= s_axi_rresp;
                        rd_state   <= RD_RESP;
                    end
                end

                RD_RESP: begin
                    if (m_axi_rready) begin
                        if (ar_beat_cnt == ar_len_q) begin
                            rd_state <= RD_IDLE;
                        end else begin
                            ar_beat_cnt <= ar_beat_cnt + 8'd1;
                            ar_cur_addr <= ar_cur_addr + (wide_read ? 32'd8 : (32'd1 << ar_size_q));
                            rresp_q     <= 2'b00;
                            if (wide_read)
                                rd_state <= RD_ADDR_LO;
                            else
                                rd_state <= RD_SINGLE_ADDR;
                        end
                    end
                end

                default: rd_state <= RD_IDLE;
            endcase
        end
    end

    assign m_axi_arready = (rd_state == RD_IDLE);

    always_comb begin
        s_axi_arvalid  = 1'b0;
        s_axi_arid     = {{(S_ID_WIDTH-M_ID_WIDTH){1'b0}}, ar_id_q};
        s_axi_araddr   = ar_cur_addr;
        s_axi_arlen    = 8'd0;
        s_axi_arsize   = 3'd2;
        s_axi_arburst  = ar_burst_q;
        s_axi_arlock   = ar_lock_q;
        s_axi_arcache  = ar_cache_q;
        s_axi_arprot   = ar_prot_q;
        s_axi_arqos    = ar_qos_q;
        s_axi_arregion = {{(S_ID_WIDTH-4){1'b0}}, ar_region_q};

        case (rd_state)
            RD_ADDR_LO: begin
                s_axi_arvalid = 1'b1;
                s_axi_araddr  = {ar_cur_addr[31:3], 3'b000};
            end
            RD_ADDR_HI: begin
                s_axi_arvalid = 1'b1;
                s_axi_araddr  = {ar_cur_addr[31:3], 3'b100};
            end
            RD_SINGLE_ADDR: begin
                s_axi_arvalid = 1'b1;
                s_axi_araddr  = {ar_cur_addr[31:2], 2'b00};
                s_axi_arsize  = (ar_size_q > 3'd2) ? 3'd2 : ar_size_q;
            end
            default:;
        endcase
    end

    assign s_axi_rready = (rd_state == RD_DATA_LO) ||
                          (rd_state == RD_DATA_HI)  ||
                          (rd_state == RD_SINGLE_DATA);

    always_comb begin
        m_axi_rvalid = 1'b0;
        m_axi_rid    = ar_id_q;
        m_axi_rdata  = 64'b0;
        m_axi_rresp  = rresp_q;
        m_axi_rlast  = (ar_beat_cnt == ar_len_q);

        if (rd_state == RD_RESP) begin
            m_axi_rvalid = 1'b1;
            if (wide_read) begin
                m_axi_rdata = {rdata_hi_q, rdata_lo_q};
            end else begin
                m_axi_rdata = {rdata_lo_q, rdata_lo_q};
            end
        end
    end

    always_ff @(posedge clk or negedge rst_l) begin
        if (!rst_l)
            rdata_hi_q <= '0;
        else if (rd_state == RD_DATA_HI && s_axi_rvalid)
            rdata_hi_q <= s_axi_rdata;
    end

    // ========================================================================
    // WRITE PATH
    // ========================================================================
    typedef enum logic [1:0] {
        WR_IDLE  = 2'd0,
        WR_ADDR  = 2'd1,
        WR_DATA  = 2'd2,
        WR_RESP  = 2'd3
    } wr_state_t;

    wr_state_t wr_state;

    reg [M_ID_WIDTH-1:0] aw_id_q;
    reg [31:0]           aw_addr_q;
    reg [7:0]            aw_len_q;
    reg [2:0]            aw_size_q;
    reg [1:0]            aw_burst_q;
    reg                  aw_lock_q;
    reg [3:0]            aw_cache_q;
    reg [2:0]            aw_prot_q;
    reg [3:0]            aw_qos_q;
    reg [3:0]            aw_region_q;
    reg [7:0]            aw_beat_cnt;
    reg [31:0]           aw_cur_addr;

    reg [31:0]           wdata_q;
    reg [3:0]            wstrb_q;
    reg                  wlast_q;
    reg                  w_captured;

    wire wr_is_upper  = m_axi_awaddr[2] || (m_axi_wvalid && (|m_axi_wstrb[7:4]));
    wire wr_cur_upper = aw_cur_addr[2]  || (|m_axi_wstrb[7:4]);

    always_ff @(posedge clk or negedge rst_l) begin
        if (!rst_l) begin
            wr_state     <= WR_IDLE;
            aw_id_q      <= '0;
            aw_addr_q    <= '0;
            aw_len_q     <= '0;
            aw_size_q    <= '0;
            aw_burst_q   <= '0;
            aw_lock_q    <= '0;
            aw_cache_q   <= '0;
            aw_prot_q    <= '0;
            aw_qos_q     <= '0;
            aw_region_q  <= '0;
            aw_beat_cnt  <= '0;
            aw_cur_addr  <= '0;
            wdata_q      <= '0;
            wstrb_q      <= '0;
            wlast_q      <= '0;
            w_captured   <= 1'b0;
        end else begin
            case (wr_state)
                WR_IDLE: begin
                    w_captured <= 1'b0;
                    if (m_axi_awvalid) begin
                        aw_id_q     <= m_axi_awid;
                        aw_addr_q   <= {m_axi_awaddr[31:3], wr_is_upper, m_axi_awaddr[1:0]};
                        aw_len_q    <= m_axi_awlen;
                        aw_size_q   <= m_axi_awsize;
                        aw_burst_q  <= m_axi_awburst;
                        aw_lock_q   <= m_axi_awlock;
                        aw_cache_q  <= m_axi_awcache;
                        aw_prot_q   <= m_axi_awprot;
                        aw_qos_q    <= m_axi_awqos;
                        aw_region_q <= m_axi_awregion;
                        aw_beat_cnt <= 8'd0;
                        aw_cur_addr <= {m_axi_awaddr[31:3], wr_is_upper, m_axi_awaddr[1:0]};
                        wr_state    <= WR_ADDR;
                    end
                    if (m_axi_wvalid) begin
                        w_captured <= 1'b1;
                        if (wr_is_upper) begin
                            wdata_q <= m_axi_wdata[63:32];
                            wstrb_q <= m_axi_wstrb[7:4];
                        end else begin
                            wdata_q <= m_axi_wdata[31:0];
                            wstrb_q <= m_axi_wstrb[3:0];
                        end
                        wlast_q <= m_axi_wlast;
                    end
                end

                WR_ADDR: begin
                    if (m_axi_wvalid && !w_captured) begin
                        w_captured <= 1'b1;
                        aw_cur_addr[2] <= wr_cur_upper;
                        if (wr_cur_upper) begin
                            wdata_q <= m_axi_wdata[63:32];
                            wstrb_q <= m_axi_wstrb[7:4];
                        end else begin
                            wdata_q <= m_axi_wdata[31:0];
                            wstrb_q <= m_axi_wstrb[3:0];
                        end
                        wlast_q <= m_axi_wlast;
                    end
                    if (s_axi_awready)
                        wr_state <= WR_DATA;
                end

                WR_DATA: begin
                    if (m_axi_wvalid && !w_captured) begin
                        w_captured <= 1'b1;
                        if (wr_cur_upper) begin
                            wdata_q <= m_axi_wdata[63:32];
                            wstrb_q <= m_axi_wstrb[7:4];
                        end else begin
                            wdata_q <= m_axi_wdata[31:0];
                            wstrb_q <= m_axi_wstrb[3:0];
                        end
                        wlast_q <= m_axi_wlast;
                    end
                    if (s_axi_wready && w_captured)
                        wr_state <= WR_RESP;
                end

                WR_RESP: begin
                    if (s_axi_bvalid) begin
                        if (aw_beat_cnt == aw_len_q) begin
                            wr_state <= WR_IDLE;
                        end else begin
                            aw_beat_cnt <= aw_beat_cnt + 8'd1;
                            aw_cur_addr <= aw_cur_addr + (32'd1 << aw_size_q);
                            w_captured  <= 1'b0;
                            wr_state    <= WR_ADDR;
                        end
                    end
                end

                default: wr_state <= WR_IDLE;
            endcase
        end
    end

    assign m_axi_awready = (wr_state == WR_IDLE);

    assign m_axi_wready = (wr_state == WR_IDLE || wr_state == WR_ADDR || wr_state == WR_DATA)
                          && !w_captured;

    assign s_axi_awvalid  = (wr_state == WR_ADDR);
    assign s_axi_awid     = {{(S_ID_WIDTH-M_ID_WIDTH){1'b0}}, aw_id_q};
    assign s_axi_awaddr   = {aw_cur_addr[31:2], 2'b00};
    assign s_axi_awlen    = 8'd0;
    assign s_axi_awsize   = (aw_size_q > 3'd2) ? 3'd2 : aw_size_q;
    assign s_axi_awburst  = aw_burst_q;
    assign s_axi_awlock   = aw_lock_q;
    assign s_axi_awcache  = aw_cache_q;
    assign s_axi_awprot   = aw_prot_q;
    assign s_axi_awqos    = aw_qos_q;
    assign s_axi_awregion = {{(S_ID_WIDTH-4){1'b0}}, aw_region_q};

    assign s_axi_wvalid = (wr_state == WR_DATA) && w_captured;
    assign s_axi_wdata  = wdata_q;
    assign s_axi_wstrb  = wstrb_q;
    assign s_axi_wlast  = 1'b1;

    assign s_axi_bready = (wr_state == WR_RESP);

    assign m_axi_bvalid = (wr_state == WR_RESP) && s_axi_bvalid
                          && (aw_beat_cnt == aw_len_q);
    assign m_axi_bresp  = s_axi_bresp;
    assign m_axi_bid    = aw_id_q;

endmodule

`default_nettype wire
