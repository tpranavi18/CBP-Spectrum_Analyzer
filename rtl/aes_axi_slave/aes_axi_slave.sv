//=================================================================
// aes_axi_slave.sv
//
// AXI4-Lite slave wrapper around:
//   - aes_cipher_top      (AES Normal  Cipher, encryption)
//   - aes_inv_cipher_top  (AES Inverse Cipher, decryption)
//
// Register map: see AES_REGISTER_SET document.
//=================================================================

module aes_axi_slave #(
    parameter C_S_AXI_DATA_WIDTH   = 32,
    parameter C_S_AXI_ADDR_WIDTH   = 32,
    parameter CIPHER_BASE_ADDR     = 32'h0000_0000,
    parameter INV_CIPHER_BASE_ADDR = 32'h0000_0100
)(
    input  wire                              S_AXI_ACLK,
    input  wire                              S_AXI_ARESETN,

    // Write address channel
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     S_AXI_AWADDR,
    input  wire                              S_AXI_AWVALID,
    output reg                               S_AXI_AWREADY,

    // Write data channel
    input  wire [C_S_AXI_DATA_WIDTH-1:0]     S_AXI_WDATA,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
    input  wire                              S_AXI_WVALID,
    output reg                               S_AXI_WREADY,

    // Write response channel
    output reg  [1:0]                        S_AXI_BRESP,
    output reg                               S_AXI_BVALID,
    input  wire                              S_AXI_BREADY,

    // Read address channel
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     S_AXI_ARADDR,
    input  wire                              S_AXI_ARVALID,
    output reg                               S_AXI_ARREADY,

    // Read data channel
    output reg  [C_S_AXI_DATA_WIDTH-1:0]     S_AXI_RDATA,
    output reg  [1:0]                        S_AXI_RRESP,
    output reg                               S_AXI_RVALID,
    input  wire                              S_AXI_RREADY
);

    //=============================================================
    // Local register-offset map (byte offsets, common to both
    // the normal cipher block and the inverse cipher block)
    //=============================================================
    localparam OFS_CSR   = 8'h00;
    localparam OFS_KEY0  = 8'h04;
    localparam OFS_KEY1  = 8'h08;
    localparam OFS_KEY2  = 8'h0C;
    localparam OFS_KEY3  = 8'h10;
    localparam OFS_TIN0  = 8'h14;
    localparam OFS_TIN1  = 8'h18;
    localparam OFS_TIN2  = 8'h1C;
    localparam OFS_TIN3  = 8'h20;
    localparam OFS_TOUT0 = 8'h24;
    localparam OFS_TOUT1 = 8'h28;
    localparam OFS_TOUT2 = 8'h2C;
    localparam OFS_TOUT3 = 8'h30;

    localparam BLOCK_SPAN = 32'h34;   // 13 registers * 4 bytes

    //=============================================================
    // AES CIPHER (normal / encrypt) register storage
    //=============================================================
    reg [31:0] cipher_key0, cipher_key1, cipher_key2, cipher_key3;
    reg [31:0] cipher_tin0, cipher_tin1, cipher_tin2, cipher_tin3;
    reg [31:0] cipher_tout0, cipher_tout1, cipher_tout2, cipher_tout3;
    reg        cipher_done_status;

    wire [127:0] cipher_key     = {cipher_key3, cipher_key2, cipher_key1, cipher_key0};
    wire [127:0] cipher_text_in = {cipher_tin3, cipher_tin2, cipher_tin1, cipher_tin0};
    wire [127:0] cipher_text_out;
    wire         cipher_done;
    reg          cipher_ld;

    //=============================================================
    // AES INVERSE CIPHER (decrypt) register storage
    //=============================================================
    reg [31:0] inv_key0, inv_key1, inv_key2, inv_key3;
    reg [31:0] inv_tin0, inv_tin1, inv_tin2, inv_tin3;
    reg [31:0] inv_tout0, inv_tout1, inv_tout2, inv_tout3;
    reg        inv_done_status;
    reg        inv_kdone_status;

    wire [127:0] inv_key       = {inv_key3, inv_key2, inv_key1, inv_key0};
    wire [127:0] inv_text_in   = {inv_tin3, inv_tin2, inv_tin1, inv_tin0};
    wire [127:0] inv_text_out;
    wire         inv_done;
    reg          inv_ld;
    reg          inv_kld;

    // aes_inv_cipher_top has no "kdone" output port -- it only has an
    // internal `reg kdone` used to time the key-expansion buffer load.
    // Declared here (before use) and wired to the core instance's
    // internal signal via a hierarchical reference near the bottom
    // of this file, instead of modifying the original core source.
    wire         inv_kdone;

    //=============================================================
    // AXI WRITE ADDRESS / DATA CHANNEL HANDSHAKE
    //=============================================================
    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_awaddr;
    wire                         wr_en;

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            S_AXI_AWREADY <= 1'b0;
            S_AXI_WREADY  <= 1'b0;
            axi_awaddr    <= {C_S_AXI_ADDR_WIDTH{1'b0}};
        end
        else begin
            if (!S_AXI_AWREADY && S_AXI_AWVALID && S_AXI_WVALID) begin
                S_AXI_AWREADY <= 1'b1;
                S_AXI_WREADY  <= 1'b1;
                axi_awaddr    <= S_AXI_AWADDR;
            end
            else begin
                S_AXI_AWREADY <= 1'b0;
                S_AXI_WREADY  <= 1'b0;
            end
        end
    end

    // Single-cycle write-enable pulse: fires the cycle AWREADY/WREADY
    // are asserted together with AWVALID/WVALID.
    assign wr_en = S_AXI_AWREADY && S_AXI_AWVALID &&
                   S_AXI_WREADY  && S_AXI_WVALID;

    //=============================================================
    // AXI WRITE RESPONSE CHANNEL
    //=============================================================
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            S_AXI_BVALID <= 1'b0;
            S_AXI_BRESP  <= 2'b00;
        end
        else if (wr_en) begin
            S_AXI_BVALID <= 1'b1;
            S_AXI_BRESP  <= 2'b00;   // OKAY
        end
        else if (S_AXI_BVALID && S_AXI_BREADY) begin
            S_AXI_BVALID <= 1'b0;
        end
    end

    //=============================================================
    // WRITE-SIDE ADDRESS DECODE
    //=============================================================
    wire cipher_wr_sel = (axi_awaddr >= CIPHER_BASE_ADDR) &&
                         (axi_awaddr <  CIPHER_BASE_ADDR + BLOCK_SPAN);

    wire inv_wr_sel    = (axi_awaddr >= INV_CIPHER_BASE_ADDR) &&
                         (axi_awaddr <  INV_CIPHER_BASE_ADDR + BLOCK_SPAN);

    wire [7:0] wr_offset = axi_awaddr[7:0] -
                           (cipher_wr_sel ? CIPHER_BASE_ADDR[7:0] :
                                            INV_CIPHER_BASE_ADDR[7:0]);

    //=============================================================
    // REGISTER WRITE LOGIC
    //=============================================================
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            cipher_key0 <= 32'h0; cipher_key1 <= 32'h0;
            cipher_key2 <= 32'h0; cipher_key3 <= 32'h0;
            cipher_tin0 <= 32'h0; cipher_tin1 <= 32'h0;
            cipher_tin2 <= 32'h0; cipher_tin3 <= 32'h0;
            cipher_ld          <= 1'b0;
            cipher_done_status <= 1'b0;

            inv_key0 <= 32'h0; inv_key1 <= 32'h0;
            inv_key2 <= 32'h0; inv_key3 <= 32'h0;
            inv_tin0 <= 32'h0; inv_tin1 <= 32'h0;
            inv_tin2 <= 32'h0; inv_tin3 <= 32'h0;
            inv_ld           <= 1'b0;
            inv_kld          <= 1'b0;
            inv_done_status  <= 1'b0;
            inv_kdone_status <= 1'b0;
        end
        else begin

            // ---- default: LD/KLD pulses are single cycle ----
            cipher_ld <= 1'b0;
            inv_ld    <= 1'b0;
            inv_kld   <= 1'b0;

            // ---- capture core completion status (sticky) ----
            if (cipher_done) cipher_done_status <= 1'b1;
            if (inv_done)    inv_done_status    <= 1'b1;
            if (inv_kdone)   inv_kdone_status   <= 1'b1;

            // ---- Normal cipher register writes ----
            if (wr_en && cipher_wr_sel) begin
                case (wr_offset)
                    OFS_CSR : begin
                        // starting a new op clears the previous DONE flag
                        if (S_AXI_WDATA[0]) begin
                            cipher_ld          <= 1'b1;
                            cipher_done_status <= 1'b0;
                        end
                    end
                    OFS_KEY0 : if (S_AXI_WSTRB[0]) cipher_key0 <= S_AXI_WDATA;
                    OFS_KEY1 : if (S_AXI_WSTRB[0]) cipher_key1 <= S_AXI_WDATA;
                    OFS_KEY2 : if (S_AXI_WSTRB[0]) cipher_key2 <= S_AXI_WDATA;
                    OFS_KEY3 : if (S_AXI_WSTRB[0]) cipher_key3 <= S_AXI_WDATA;
                    OFS_TIN0 : if (S_AXI_WSTRB[0]) cipher_tin0 <= S_AXI_WDATA;
                    OFS_TIN1 : if (S_AXI_WSTRB[0]) cipher_tin1 <= S_AXI_WDATA;
                    OFS_TIN2 : if (S_AXI_WSTRB[0]) cipher_tin2 <= S_AXI_WDATA;
                    OFS_TIN3 : if (S_AXI_WSTRB[0]) cipher_tin3 <= S_AXI_WDATA;
                    default  : ; // TOUT* are read-only
                endcase
            end

            // ---- Inverse cipher register writes ----
            if (wr_en && inv_wr_sel) begin
                case (wr_offset)
                    OFS_CSR : begin
                        if (S_AXI_WDATA[1]) begin      // KLD
                            inv_kld          <= 1'b1;
                            inv_kdone_status <= 1'b0;
                        end
                        if (S_AXI_WDATA[0]) begin       // LD
                            inv_ld          <= 1'b1;
                            inv_done_status <= 1'b0;
                        end
                    end
                    OFS_KEY0 : if (S_AXI_WSTRB[0]) inv_key0 <= S_AXI_WDATA;
                    OFS_KEY1 : if (S_AXI_WSTRB[0]) inv_key1 <= S_AXI_WDATA;
                    OFS_KEY2 : if (S_AXI_WSTRB[0]) inv_key2 <= S_AXI_WDATA;
                    OFS_KEY3 : if (S_AXI_WSTRB[0]) inv_key3 <= S_AXI_WDATA;
                    OFS_TIN0 : if (S_AXI_WSTRB[0]) inv_tin0 <= S_AXI_WDATA;
                    OFS_TIN1 : if (S_AXI_WSTRB[0]) inv_tin1 <= S_AXI_WDATA;
                    OFS_TIN2 : if (S_AXI_WSTRB[0]) inv_tin2 <= S_AXI_WDATA;
                    OFS_TIN3 : if (S_AXI_WSTRB[0]) inv_tin3 <= S_AXI_WDATA;
                    default  : ; // TOUT* are read-only
                endcase
            end
        end
    end

    //=============================================================
    // LATCH CIPHER / INVERSE CIPHER OUTPUTS WHEN CORE FINISHES
    //=============================================================
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            cipher_tout0 <= 32'h0; cipher_tout1 <= 32'h0;
            cipher_tout2 <= 32'h0; cipher_tout3 <= 32'h0;
            inv_tout0 <= 32'h0; inv_tout1 <= 32'h0;
            inv_tout2 <= 32'h0; inv_tout3 <= 32'h0;
        end
        else begin
            if (cipher_done) begin
                cipher_tout0 <= cipher_text_out[31:0];
                cipher_tout1 <= cipher_text_out[63:32];
                cipher_tout2 <= cipher_text_out[95:64];
                cipher_tout3 <= cipher_text_out[127:96];
            end
            if (inv_done) begin
                inv_tout0 <= inv_text_out[31:0];
                inv_tout1 <= inv_text_out[63:32];
                inv_tout2 <= inv_text_out[95:64];
                inv_tout3 <= inv_text_out[127:96];
            end
        end
    end

    //=============================================================
    // AXI READ ADDRESS CHANNEL HANDSHAKE
    //=============================================================
    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_araddr;

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            S_AXI_ARREADY <= 1'b0;
            axi_araddr    <= {C_S_AXI_ADDR_WIDTH{1'b0}};
        end
        else begin
            if (!S_AXI_ARREADY && S_AXI_ARVALID) begin
                S_AXI_ARREADY <= 1'b1;
                axi_araddr    <= S_AXI_ARADDR;
            end
            else begin
                S_AXI_ARREADY <= 1'b0;
            end
        end
    end

    //=============================================================
    // READ-SIDE ADDRESS DECODE
    //=============================================================
    wire cipher_rd_sel = (axi_araddr >= CIPHER_BASE_ADDR) &&
                         (axi_araddr <  CIPHER_BASE_ADDR + BLOCK_SPAN);

    wire inv_rd_sel    = (axi_araddr >= INV_CIPHER_BASE_ADDR) &&
                         (axi_araddr <  INV_CIPHER_BASE_ADDR + BLOCK_SPAN);

    wire [7:0] rd_offset = axi_araddr[7:0] -
                           (cipher_rd_sel ? CIPHER_BASE_ADDR[7:0] :
                                            INV_CIPHER_BASE_ADDR[7:0]);

    reg [31:0] rd_data_comb;

    always @(*) begin
        rd_data_comb = 32'h0;

        if (cipher_rd_sel) begin
            case (rd_offset)
                OFS_CSR  : rd_data_comb = {cipher_done_status, 15'b0, 15'b0, 1'b0};
                OFS_KEY0 : rd_data_comb = cipher_key0;
                OFS_KEY1 : rd_data_comb = cipher_key1;
                OFS_KEY2 : rd_data_comb = cipher_key2;
                OFS_KEY3 : rd_data_comb = cipher_key3;
                OFS_TIN0 : rd_data_comb = cipher_tin0;
                OFS_TIN1 : rd_data_comb = cipher_tin1;
                OFS_TIN2 : rd_data_comb = cipher_tin2;
                OFS_TIN3 : rd_data_comb = cipher_tin3;
                OFS_TOUT0: rd_data_comb = cipher_tout0;
                OFS_TOUT1: rd_data_comb = cipher_tout1;
                OFS_TOUT2: rd_data_comb = cipher_tout2;
                OFS_TOUT3: rd_data_comb = cipher_tout3;
                default  : rd_data_comb = 32'h0;
            endcase
        end
        else if (inv_rd_sel) begin
            case (rd_offset)
                OFS_CSR  : rd_data_comb = {inv_done_status, inv_kdone_status,
                                            14'b0, 14'b0, 2'b0};
                OFS_KEY0 : rd_data_comb = inv_key0;
                OFS_KEY1 : rd_data_comb = inv_key1;
                OFS_KEY2 : rd_data_comb = inv_key2;
                OFS_KEY3 : rd_data_comb = inv_key3;
                OFS_TIN0 : rd_data_comb = inv_tin0;
                OFS_TIN1 : rd_data_comb = inv_tin1;
                OFS_TIN2 : rd_data_comb = inv_tin2;
                OFS_TIN3 : rd_data_comb = inv_tin3;
                OFS_TOUT0: rd_data_comb = inv_tout0;
                OFS_TOUT1: rd_data_comb = inv_tout1;
                OFS_TOUT2: rd_data_comb = inv_tout2;
                OFS_TOUT3: rd_data_comb = inv_tout3;
                default  : rd_data_comb = 32'h0;
            endcase
        end
    end

    //=============================================================
    // AXI READ DATA CHANNEL
    //=============================================================
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            S_AXI_RVALID <= 1'b0;
            S_AXI_RRESP  <= 2'b00;
            S_AXI_RDATA  <= 32'h0;
        end
        else if (S_AXI_ARREADY && S_AXI_ARVALID && !S_AXI_RVALID) begin
            S_AXI_RVALID <= 1'b1;
            S_AXI_RRESP  <= 2'b00;          // OKAY
            S_AXI_RDATA  <= rd_data_comb;
        end
        else if (S_AXI_RVALID && S_AXI_RREADY) begin
            S_AXI_RVALID <= 1'b0;
        end
    end

    //=============================================================
    // AES NORMAL CIPHER CORE INSTANCE
    //=============================================================
    aes_cipher_top u_aes_cipher_top (
        .clk      (S_AXI_ACLK),
        .rst      (S_AXI_ARESETN),   // core reset is active-low, synchronous
        .ld       (cipher_ld),
        .done     (cipher_done),
        .key      (cipher_key),
        .text_in  (cipher_text_in),
        .text_out (cipher_text_out)
    );

    //=============================================================
    // AES INVERSE CIPHER CORE INSTANCE
    //
    // NOTE: aes_inv_cipher_top (opencores aes_core) does NOT expose
    // a "kdone" output port on its module header -- it only has an
    // internal `reg kdone` used to time the key-expansion buffer
    // load. inv_kdone (declared above, before first use) is driven
    // from that internal signal via a hierarchical reference here,
    // instead of modifying the original core source.
    //=============================================================
    aes_inv_cipher_top u_aes_inv_cipher_top (
        .clk      (S_AXI_ACLK),
        .rst      (S_AXI_ARESETN),   // core reset is active-low, synchronous
        .kld      (inv_kld),
        .ld       (inv_ld),
        .done     (inv_done),
        .key      (inv_key),
        .text_in  (inv_text_in),
        .text_out (inv_text_out)
    );

    assign inv_kdone = u_aes_inv_cipher_top.kdone;

endmodule
