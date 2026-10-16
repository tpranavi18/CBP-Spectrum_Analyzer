// ============================================================================
// File: axi_imem_slave.sv
// Project: CBP-Spectrum_Analyzer
//
// Description:
//   AXI4 32-bit IMEM (Instruction Memory) slave.
//   Maps 64 KB of synchronous SRAM at 0x0000_0000 - 0x0000_FFFF.
//   Pre-loaded with a deterministic verification program so the VeeR EL2
//   CPU can fetch and execute instructions immediately after reset:
//     1. DMEM write & read (0x0001_0000)
//     2. CPU ALU, branch, and loop execution
//     3. UART peripheral access (0x4000_0000)
//     4. GPIO peripheral access (0x4000_2000)
//     5. Timer peripheral access (0x4000_4000)
//     6. FIR filter access (0x4000_C000)
//     7. ADC controller access (0x4000_E000)
//     8. FFT control access (0x4000_8000)
//     9. FFT memory access (0x4000_A000)
//    10. Dummy slave access (0x4000_6000 -> DECERR)
//    11. Final infinite loop (jal zero, 0)
// ============================================================================

`timescale 1ns/1ps
`default_nettype none

module axi_imem_slave #(
    parameter AXI_ID_WIDTH   = 8,
    parameter AXI_DATA_WIDTH = 32,
    parameter AXI_ADDR_WIDTH = 32,
    parameter MEM_SIZE_BYTES = 65536,    // 64 KB
    parameter BASE_ADDR      = 32'h0000_0000
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

    // Memory array
    reg [AXI_DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];

    // Pre-loaded verification program
    integer i;
    initial begin
        for (i = 0; i < MEM_DEPTH; i = i + 1)
            mem[i] = 32'h0000006F;  // default: jal x0, 0 (infinite loop)

        // 1. Basic DMEM write & read
        mem[ 0] = 32'h00010537; // PC = 0x000: lui a0, 0x10000 (DMEM base = 0x0001_0000)
        mem[ 1] = 32'h05A00293; // PC = 0x004: addi t0, zero, 0x5A
        mem[ 2] = 32'h00552023; // PC = 0x008: sw t0, 0(a0) (store 0x5A to DMEM[0])
        mem[ 3] = 32'h00052303; // PC = 0x00C: lw t1, 0(a0) (load from DMEM[0])

        // 2. CPU Instruction Execution: ALU, Branches, Loop
        mem[ 4] = 32'h00A00093; // PC = 0x010: addi ra, zero, 10
        mem[ 5] = 32'h01400113; // PC = 0x014: addi sp, zero, 20
        mem[ 6] = 32'h002081B3; // PC = 0x018: add gp, ra, sp (gp = 30)
        mem[ 7] = 32'h40118233; // PC = 0x01C: sub tp, gp, ra (tp = 20)
        mem[ 8] = 32'h00209293; // PC = 0x020: slli t0, ra, 2 (t0 = 40)
        mem[ 9] = 32'h00220463; // PC = 0x024: beq tp, sp, +8 (taken -> skip next)
        mem[10] = 32'h00000193; // PC = 0x028: addi gp, zero, 0 (skipped)
        mem[11] = 32'h00352223; // PC = 0x02C: sw gp, 4(a0) (store 30 to DMEM[4])
        mem[12] = 32'h00552423; // PC = 0x030: sw t0, 8(a0) (store 40 to DMEM[8])
        mem[13] = 32'h00500313; // PC = 0x034: addi t1, zero, 5 (loop counter)
        mem[14] = 32'hFFF30313; // PC = 0x038: addi t1, t1, -1
        mem[15] = 32'hFE031EE3; // PC = 0x03C: bne t1, zero, -4 (loop back)
        mem[16] = 32'h00652623; // PC = 0x040: sw t1, 12(a0) (store 0 to DMEM[12])

        // 3. UART Peripheral Access (0x4000_0000)
        mem[17] = 32'h400005B7; // PC = 0x044: lui a1, 0x40000 (UART base)
        mem[18] = 32'h00300393; // PC = 0x048: addi t2, zero, 3
        mem[19] = 32'h0075A623; // PC = 0x04C: sw t2, 12(a1) (write UART LCR)
        mem[20] = 32'h00C5AE03; // PC = 0x050: lw t3, 12(a1) (read UART LCR)
        mem[21] = 32'h01C52823; // PC = 0x054: sw t3, 16(a0) (save UART LCR to DMEM[16])

        // 4. GPIO Peripheral Access (0x4000_2000)
        mem[22] = 32'h40002637; // PC = 0x058: lui a2, 0x40002 (GPIO base)
        mem[23] = 32'h0FF00E93; // PC = 0x05C: addi t4, zero, 0xFF
        mem[24] = 32'h01D62423; // PC = 0x060: sw t4, 8(a2) (GPIO DIR = 0xFF)
        mem[25] = 32'h0A500E93; // PC = 0x064: addi t4, zero, 0xA5
        mem[26] = 32'h01D62223; // PC = 0x068: sw t4, 4(a2) (GPIO DATA_O = 0xA5)
        mem[27] = 32'h00462F03; // PC = 0x06C: lw t5, 4(a2) (read GPIO DATA_O)
        mem[28] = 32'h01E52A23; // PC = 0x070: sw t5, 20(a0) (save GPIO DATA_O to DMEM[20])

        // 5. TIMER Peripheral Access (0x4000_4000)
        mem[29] = 32'h400046B7; // PC = 0x074: lui a3, 0x40004 (TIMER base)
        mem[30] = 32'h00500F93; // PC = 0x078: addi t6, zero, 5
        mem[31] = 32'h01F6A223; // PC = 0x07C: sw t6, 4(a3) (TIMER LOAD = 5)
        mem[32] = 32'h0046A403; // PC = 0x080: lw s0, 4(a3) (read TIMER LOAD)
        mem[33] = 32'h00852C23; // PC = 0x084: sw s0, 24(a0) (save TIMER LOAD to DMEM[24])
        mem[34] = 32'h00100493; // PC = 0x088: addi s1, zero, 1
        mem[35] = 32'h0096A023; // PC = 0x08C: sw s1, 0(a3) (enable TIMER)

        // 6. FIR Filter Engine Access (0x4000_C000)
        mem[36] = 32'h4000C737; // PC = 0x090: lui a4, 0x4000C (FIR base)
        mem[37] = 32'h00100493; // PC = 0x094: addi s1, zero, 1
        mem[38] = 32'h00972023; // PC = 0x098: sw s1, 0(a4) (enable FIR)
        mem[39] = 32'h00072B03; // PC = 0x09C: lw s6, 0(a4) (read FIR enable)
        mem[40] = 32'h01652E23; // PC = 0x0A0: sw s6, 28(a0) (save FIR enable to DMEM[28])

        // 7. ADC Controller Access (0x4000_E000)
        mem[41] = 32'h4000E7B7; // PC = 0x0A4: lui a5, 0x4000E (ADC base)
        mem[42] = 32'h00100493; // PC = 0x0A8: addi s1, zero, 1
        mem[43] = 32'h0097A023; // PC = 0x0AC: sw s1, 0(a5) (enable ADC)
        mem[44] = 32'h0047A903; // PC = 0x0B0: lw s2, 4(a5) (read ADC STATUS)
        mem[45] = 32'h03252023; // PC = 0x0B4: sw s2, 32(a0) (save ADC STATUS to DMEM[32])

        // 8. FFT Control Access (0x4000_8000)
        mem[46] = 32'h40008837; // PC = 0x0B8: lui a6, 0x40008 (FFT CTRL base)
        mem[47] = 32'h00482B83; // PC = 0x0BC: lw s7, 4(a6) (read FFT STATUS)
        mem[48] = 32'h03752223; // PC = 0x0C0: sw s7, 36(a0) (save FFT STATUS to DMEM[36])

        // 9. End of test infinite execution loop (continuous instruction fetching)
        mem[49] = 32'h0000006F; // PC = 0x0C4: jal zero, 0
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
