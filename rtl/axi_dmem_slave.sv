// ============================================================================
// File: axi_dmem_slave.sv
// Project: CBP-Spectrum_Analyzer
//
// Description:
//   AXI4 32-bit DMEM (Data Memory) slave.
//   Maps 64 KB of synchronous SRAM at 0x0001_0000 - 0x0001_FFFF.
//   Zero-initialized, supporting word, half-word, and byte write strobes.
// ============================================================================

`timescale 1ns/1ps
`default_nettype none

module axi_dmem_slave #(
    parameter AXI_ID_WIDTH   = 8,
    parameter AXI_DATA_WIDTH = 32,
    parameter AXI_ADDR_WIDTH = 32,
    parameter MEM_SIZE_BYTES = 65536,    // 64 KB
    parameter BASE_ADDR      = 32'h0001_0000
)(
    input  wire                        aclk,
    input  wire                        aresetn,  // active-low

    // AXI4 Write Address Channel
    input  wire [AXI_ID_WIDTH-1:0]     s_awid,
    input  wire [AXI_ADDR_WIDTH-1:0]   s_awaddr,
    input  wire [7:0]                  s_awlen,
    input  wire [2:0]                  s_awsize,
    input  wire [1:0]                  s_awburst,
    input  wire                        s_awlock,
    input  wire [3:0]                  s_awcache,
    input  wire [2:0]                  s_awprot,
    input  wire [3:0]                  s_awqos,
    input  wire [3:0]                  s_awregion,
    input  wire                        s_awvalid,
    output wire                        s_awready,

    // AXI4 Write Data Channel
    input  wire [AXI_DATA_WIDTH-1:0]   s_wdata,
    input  wire [AXI_DATA_WIDTH/8-1:0] s_wstrb,
    input  wire                        s_wlast,
    input  wire                        s_wvalid,
    output wire                        s_wready,

    // AXI4 Write Response Channel
    output wire [AXI_ID_WIDTH-1:0]     s_bid,
    output wire [1:0]                  s_bresp,
    output wire                        s_bvalid,
    input  wire                        s_bready,

    // AXI4 Read Address Channel
    input  wire [AXI_ID_WIDTH-1:0]     s_arid,
    input  wire [AXI_ADDR_WIDTH-1:0]   s_araddr,
    input  wire [7:0]                  s_arlen,
    input  wire [2:0]                  s_arsize,
    input  wire [1:0]                  s_arburst,
    input  wire                        s_arlock,
    input  wire [3:0]                  s_arcache,
    input  wire [2:0]                  s_arprot,
    input  wire [3:0]                  s_arqos,
    input  wire [3:0]                  s_arregion,
    input  wire                        s_arvalid,
    output wire                        s_arready,

    // AXI4 Read Data Channel
    output wire [AXI_ID_WIDTH-1:0]     s_rid,
    output wire [AXI_DATA_WIDTH-1:0]   s_rdata,
    output wire [1:0]                  s_rresp,
    output wire                        s_rlast,
    output wire                        s_rvalid,
    input  wire                        s_rready
);

    localparam MEM_DEPTH = MEM_SIZE_BYTES / (AXI_DATA_WIDTH/8); // 16384 words
    localparam ADDR_BITS = $clog2(MEM_DEPTH);                   // 14 bits

    reg [AXI_DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];

    integer i;
    initial begin
        for (i = 0; i < MEM_DEPTH; i = i + 1)
            mem[i] = 32'h0000_0000;
    end

    // ========================================================================
    // READ Path
    // ========================================================================
    typedef enum logic [1:0] {
        RD_IDLE = 2'd0,
        RD_RESP = 2'd1
    } rd_state_t;

    rd_state_t               rd_state;
    reg [AXI_ID_WIDTH-1:0]   r_id_q;
    reg [31:0]               r_addr_q;
    reg [7:0]                r_len_q;
    reg [7:0]                r_cnt;
    reg [1:0]                r_burst_q;
    reg                      r_range_err;

    function automatic logic [ADDR_BITS-1:0] word_addr(input logic [31:0] byte_addr);
        return byte_addr[ADDR_BITS+1:2];
    endfunction

    function automatic logic in_range(input logic [31:0] addr);
        return (addr >= BASE_ADDR) && (addr < (BASE_ADDR + MEM_SIZE_BYTES));
    endfunction

    function automatic logic [31:0] next_addr(
        input logic [31:0] addr,
        input logic [1:0]  burst,
        input logic [2:0]  size
    );
        if (burst == 2'b01)
            return addr + (32'd1 << size);
        else
            return addr;
    endfunction

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            rd_state    <= RD_IDLE;
            r_id_q      <= '0;
            r_addr_q    <= '0;
            r_len_q     <= '0;
            r_cnt       <= '0;
            r_burst_q   <= '0;
            r_range_err <= 1'b0;
        end else begin
            case (rd_state)
                RD_IDLE: begin
                    if (s_arvalid) begin
                        r_id_q      <= s_arid;
                        r_addr_q    <= s_araddr;
                        r_len_q     <= s_arlen;
                        r_cnt       <= 8'd0;
                        r_burst_q   <= s_arburst;
                        r_range_err <= !in_range(s_araddr);
                        rd_state    <= RD_RESP;
                    end
                end

                RD_RESP: begin
                    if (s_rready) begin
                        if (r_cnt == r_len_q) begin
                            rd_state <= RD_IDLE;
                        end else begin
                            r_cnt       <= r_cnt + 8'd1;
                            r_addr_q    <= next_addr(r_addr_q, r_burst_q, 3'd2);
                            r_range_err <= !in_range(next_addr(r_addr_q, r_burst_q, 3'd2));
                        end
                    end
                end
            endcase
        end
    end

    assign s_arready = (rd_state == RD_IDLE);
    assign s_rvalid  = (rd_state == RD_RESP);
    assign s_rid     = r_id_q;
    assign s_rresp   = r_range_err ? 2'b10 : 2'b00;
    assign s_rlast   = (r_cnt == r_len_q);
    assign s_rdata   = r_range_err ? 32'hDEAD_BEEF
                                   : mem[word_addr(r_addr_q)];

    // ========================================================================
    // WRITE Path
    // ========================================================================
    typedef enum logic [1:0] {
        WR_IDLE = 2'd0,
        WR_ADDR = 2'd1,
        WR_DATA = 2'd2,
        WR_RESP = 2'd3
    } wr_state_t;

    wr_state_t               wr_state;
    reg [AXI_ID_WIDTH-1:0]   w_id_q;
    reg [31:0]               w_addr_q;
    reg [7:0]                w_len_q;
    reg [7:0]                w_cnt;
    reg [1:0]                w_burst_q;
    reg [2:0]                w_size_q;
    reg                      w_range_err;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            wr_state    <= WR_IDLE;
            w_id_q      <= '0;
            w_addr_q    <= '0;
            w_len_q     <= '0;
            w_cnt       <= '0;
            w_burst_q   <= '0;
            w_size_q    <= '0;
            w_range_err <= 1'b0;
        end else begin
            case (wr_state)
                WR_IDLE: begin
                    if (s_awvalid) begin
                        w_id_q      <= s_awid;
                        w_addr_q    <= s_awaddr;
                        w_len_q     <= s_awlen;
                        w_cnt       <= 8'd0;
                        w_burst_q   <= s_awburst;
                        w_size_q    <= s_awsize;
                        w_range_err <= !in_range(s_awaddr);
                        wr_state    <= WR_DATA;
                    end
                end

                WR_DATA: begin
                    if (s_wvalid) begin
                        if (in_range(w_addr_q)) begin
                            for (int b = 0; b < AXI_DATA_WIDTH/8; b++) begin
                                if (s_wstrb[b])
                                    mem[word_addr(w_addr_q)][b*8 +: 8] <= s_wdata[b*8 +: 8];
                            end
                        end
                        if (s_wlast || w_cnt == w_len_q) begin
                            wr_state <= WR_RESP;
                        end else begin
                            w_cnt    <= w_cnt + 8'd1;
                            w_addr_q <= next_addr(w_addr_q, w_burst_q, w_size_q);
                        end
                    end
                end

                WR_RESP: begin
                    if (s_bready)
                        wr_state <= WR_IDLE;
                end

                default: wr_state <= WR_IDLE;
            endcase
        end
    end

    assign s_awready = (wr_state == WR_IDLE);
    assign s_wready  = (wr_state == WR_DATA);
    assign s_bvalid  = (wr_state == WR_RESP);
    assign s_bid     = w_id_q;
    assign s_bresp   = w_range_err ? 2'b10 : 2'b00;

endmodule

`default_nettype wire
