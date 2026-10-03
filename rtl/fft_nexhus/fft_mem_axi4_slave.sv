`timescale 1ns/1ps

module fft_mem_axi4_slave #(
    parameter int N           = 1024,
    parameter int AXI_ADDR_W  = 16,
    parameter int AXI_DATA_W  = 32,
    parameter int AXI_ID_W    = 4
)(
    input  logic                     clk,
    input  logic                     rst_n,

    input  logic                     fft_busy,

    output logic                     mem_we,
    output logic [$clog2(N)-1:0]     mem_waddr,
    output logic [31:0]              mem_wdata,

    output logic [$clog2(N)-1:0]     mem_raddr,
    input  logic [31:0]              mem_rdata,

    input  logic [AXI_ID_W-1:0]      S_AXI_AWID,
    input  logic [AXI_ADDR_W-1:0]    S_AXI_AWADDR,
    input  logic [7:0]               S_AXI_AWLEN,
    input  logic [2:0]               S_AXI_AWSIZE,
    input  logic [1:0]               S_AXI_AWBURST,
    input  logic                     S_AXI_AWVALID,
    output logic                     S_AXI_AWREADY,

    input  logic [AXI_DATA_W-1:0]    S_AXI_WDATA,
    input  logic [AXI_DATA_W/8-1:0]  S_AXI_WSTRB,
    input  logic                     S_AXI_WLAST,
    input  logic                     S_AXI_WVALID,
    output logic                     S_AXI_WREADY,

    output logic [AXI_ID_W-1:0]      S_AXI_BID,
    output logic [1:0]               S_AXI_BRESP,
    output logic                     S_AXI_BVALID,
    input  logic                     S_AXI_BREADY,

    input  logic [AXI_ID_W-1:0]      S_AXI_ARID,
    input  logic [AXI_ADDR_W-1:0]    S_AXI_ARADDR,
    input  logic [7:0]               S_AXI_ARLEN,
    input  logic [2:0]               S_AXI_ARSIZE,
    input  logic [1:0]               S_AXI_ARBURST,
    input  logic                     S_AXI_ARVALID,
    output logic                     S_AXI_ARREADY,

    output logic [AXI_ID_W-1:0]      S_AXI_RID,
    output logic [AXI_DATA_W-1:0]    S_AXI_RDATA,
    output logic [1:0]               S_AXI_RRESP,
    output logic                     S_AXI_RLAST,
    output logic                     S_AXI_RVALID,
    input  logic                     S_AXI_RREADY
);

    localparam int MEM_AW = $clog2(N);

    localparam logic [AXI_ADDR_W-1:0] MEM_BASE = 'h1000;
    localparam logic [AXI_ADDR_W-1:0] MEM_LAST = MEM_BASE + (N*4) - 4;

    localparam logic [1:0] AXI_RESP_OKAY   = 2'b00;
    localparam logic [1:0] AXI_RESP_SLVERR = 2'b10;

    function automatic logic addr_is_valid_word(
        input logic [AXI_ADDR_W-1:0] addr
    );
        begin
            addr_is_valid_word = (addr >= MEM_BASE) &&
                                 (addr <= MEM_LAST) &&
                                 (addr[1:0] == 2'b00);
        end
    endfunction

    function automatic logic [MEM_AW-1:0] mem_index(
        input logic [AXI_ADDR_W-1:0] addr
    );
        begin
            mem_index = (addr - MEM_BASE) >> 2;
        end
    endfunction

    function automatic logic [AXI_ADDR_W-1:0] next_axi_addr(
        input logic [AXI_ADDR_W-1:0] addr,
        input logic [2:0]            size,
        input logic [1:0]            burst
    );
        logic [AXI_ADDR_W-1:0] incr;
        begin
            incr = ({{(AXI_ADDR_W-1){1'b0}},1'b1} << size);
            case (burst)
                2'b00: next_axi_addr = addr;
                2'b01: next_axi_addr = addr + incr;
                default: next_axi_addr = addr;
            endcase
        end
    endfunction

    logic                    wr_active;
    logic [AXI_ID_W-1:0]     wr_id;
    logic [AXI_ADDR_W-1:0]   wr_addr;
    logic [7:0]              wr_beats_left;
    logic [2:0]              wr_size;
    logic [1:0]              wr_burst;

    logic                    rd_active;
    logic                    rd_pending;
    logic                    rd_pending2;
    logic [AXI_ID_W-1:0]     rd_id;
    logic [AXI_ADDR_W-1:0]   rd_addr;
    logic [7:0]              rd_beats_left;
    logic [2:0]              rd_size;
    logic [1:0]              rd_burst;

    always_comb begin
        mem_raddr = '0;
        if (rd_active && (rd_pending || rd_pending2) && addr_is_valid_word(rd_addr))
            mem_raddr = mem_index(rd_addr);
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_we        <= 1'b0;
            mem_waddr     <= '0;
            mem_wdata     <= '0;

            S_AXI_AWREADY <= 1'b1;
            S_AXI_WREADY  <= 1'b0;
            S_AXI_BID     <= '0;
            S_AXI_BRESP   <= AXI_RESP_OKAY;
            S_AXI_BVALID  <= 1'b0;

            wr_active     <= 1'b0;
            wr_id         <= '0;
            wr_addr       <= '0;
            wr_beats_left <= '0;
            wr_size       <= '0;
            wr_burst      <= '0;

            S_AXI_ARREADY <= 1'b1;
            S_AXI_RID     <= '0;
            S_AXI_RDATA   <= '0;
            S_AXI_RRESP   <= AXI_RESP_OKAY;
            S_AXI_RLAST   <= 1'b0;
            S_AXI_RVALID  <= 1'b0;

            rd_active     <= 1'b0;
            rd_pending    <= 1'b0;
            rd_pending2   <= 1'b0;
            rd_id         <= '0;
            rd_addr       <= '0;
            rd_beats_left <= '0;
            rd_size       <= '0;
            rd_burst      <= '0;
        end
        else begin
            mem_we <= 1'b0;

            // do not start a new AXI mem transaction while FFT owns memory
            if (!wr_active && !S_AXI_BVALID)
                S_AXI_AWREADY <= !fft_busy;

            if (!rd_active && !S_AXI_RVALID)
                S_AXI_ARREADY <= !fft_busy;

            // write address accept
            if (S_AXI_AWREADY && S_AXI_AWVALID) begin
                S_AXI_AWREADY <= 1'b0;
                S_AXI_WREADY  <= 1'b1;

                wr_active     <= 1'b1;
                wr_id         <= S_AXI_AWID;
                wr_addr       <= S_AXI_AWADDR;
                wr_beats_left <= S_AXI_AWLEN + 1'b1;
                wr_size       <= S_AXI_AWSIZE;
                wr_burst      <= S_AXI_AWBURST;
            end

            // write data handling
            if (wr_active && S_AXI_WREADY && S_AXI_WVALID) begin
                logic cur_write_ok;
                logic [1:0] cur_bresp;

                cur_write_ok = (!fft_busy) &&
                               (wr_size == 3'd2) &&
                               (wr_burst != 2'b10) &&
                               addr_is_valid_word(wr_addr);

                cur_bresp = cur_write_ok ? AXI_RESP_OKAY : AXI_RESP_SLVERR;

                if (cur_write_ok) begin
                    mem_we    <= 1'b1;
                    mem_waddr <= mem_index(wr_addr);
                    mem_wdata <= S_AXI_WDATA;
                end

                wr_beats_left <= wr_beats_left - 1'b1;

                if (wr_beats_left == 8'd1) begin
                    S_AXI_WREADY <= 1'b0;
                    S_AXI_BVALID <= 1'b1;
                    S_AXI_BID    <= wr_id;
                    S_AXI_BRESP  <= cur_bresp;
                    wr_active    <= 1'b0;
                end
                else begin
                    wr_addr <= next_axi_addr(wr_addr, wr_size, wr_burst);
                end
            end

            // write response completion
            if (S_AXI_BVALID && S_AXI_BREADY) begin
                S_AXI_BVALID <= 1'b0;
                S_AXI_BID    <= '0;
                S_AXI_BRESP  <= AXI_RESP_OKAY;
            end

            // read address accept
            if (S_AXI_ARREADY && S_AXI_ARVALID) begin
                S_AXI_ARREADY   <= 1'b0;

                rd_active       <= 1'b1;
                rd_pending      <= 1'b0;
                rd_pending2     <= 1'b0;
                rd_id           <= S_AXI_ARID;
                rd_addr         <= S_AXI_ARADDR;
                rd_beats_left   <= S_AXI_ARLEN + 1'b1;
                rd_size         <= S_AXI_ARSIZE;
                rd_burst        <= S_AXI_ARBURST;

                S_AXI_RID       <= S_AXI_ARID;
                S_AXI_RVALID    <= 1'b0;
                S_AXI_RLAST     <= 1'b0;
            end

            // read pipeline stage 1: launch memory address
            if (rd_active && !rd_pending && !rd_pending2 && !S_AXI_RVALID) begin
                rd_pending <= 1'b1;
            end
            // read pipeline stage 2: wait one more cycle for synchronous BRAM output
            else if (rd_active && rd_pending && !rd_pending2 && !S_AXI_RVALID) begin
                rd_pending  <= 1'b0;
                rd_pending2 <= 1'b1;
            end
            // read pipeline stage 3: return valid data
            else if (rd_active && !rd_pending && rd_pending2 && !S_AXI_RVALID) begin
                rd_pending2 <= 1'b0;

                if (fft_busy) begin
                    S_AXI_RRESP <= AXI_RESP_SLVERR;
                    S_AXI_RDATA <= 32'hDEAD_BEEF;
                end
                else if ((rd_size != 3'd2) ||
                         (rd_burst == 2'b10) ||
                         !addr_is_valid_word(rd_addr)) begin
                    S_AXI_RRESP <= AXI_RESP_SLVERR;
                    S_AXI_RDATA <= 32'hDEAD_BEEF;
                end
                else begin
                    S_AXI_RRESP <= AXI_RESP_OKAY;
                    S_AXI_RDATA <= mem_rdata;
                end

                S_AXI_RID    <= rd_id;
                S_AXI_RLAST  <= (rd_beats_left == 8'd1);
                S_AXI_RVALID <= 1'b1;
            end

            // read beat accepted
            if (S_AXI_RVALID && S_AXI_RREADY) begin
                S_AXI_RVALID <= 1'b0;
                S_AXI_RLAST  <= 1'b0;

                rd_beats_left <= rd_beats_left - 1'b1;

                if (rd_beats_left == 8'd1) begin
                    rd_active   <= 1'b0;
                    rd_pending  <= 1'b0;
                    rd_pending2 <= 1'b0;
                end
                else begin
                    rd_pending  <= 1'b0;
                    rd_pending2 <= 1'b0;
                    rd_addr <= next_axi_addr(rd_addr, rd_size, rd_burst);
                end
            end
        end
    end

endmodule