`timescale 1ns/1ps

module fft_ctrl_axil #(
    parameter int AXI_ADDR_W = 16,
    parameter int AXI_DATA_W = 32
)(
    input  logic                      clk,
    input  logic                      rst_n,
    input  logic                      fft_done,
    input  logic                      fft_busy,
    output logic                      start_pulse,

    input  logic [AXI_ADDR_W-1:0]     S_AXI_AWADDR,
    input  logic                      S_AXI_AWVALID,
    output logic                      S_AXI_AWREADY,

    input  logic [AXI_DATA_W-1:0]     S_AXI_WDATA,
    input  logic [AXI_DATA_W/8-1:0]   S_AXI_WSTRB,
    input  logic                      S_AXI_WVALID,
    output logic                      S_AXI_WREADY,

    output logic [1:0]                S_AXI_BRESP,
    output logic                      S_AXI_BVALID,
    input  logic                      S_AXI_BREADY,

    input  logic [AXI_ADDR_W-1:0]     S_AXI_ARADDR,
    input  logic                      S_AXI_ARVALID,
    output logic                      S_AXI_ARREADY,

    output logic [AXI_DATA_W-1:0]     S_AXI_RDATA,
    output logic [1:0]                S_AXI_RRESP,
    output logic                      S_AXI_RVALID,
    input  logic                      S_AXI_RREADY
);

    localparam logic [AXI_ADDR_W-1:0] CTRL_ADDR   = 'h0000;
    localparam logic [AXI_ADDR_W-1:0] STATUS_ADDR = 'h0004;

    localparam logic [1:0] AXI_RESP_OKAY   = 2'b00;
    localparam logic [1:0] AXI_RESP_SLVERR = 2'b10;

    logic done_sticky;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            S_AXI_AWREADY <= 1'b1;
            S_AXI_WREADY  <= 1'b1;
            S_AXI_BVALID  <= 1'b0;
            S_AXI_BRESP   <= AXI_RESP_OKAY;

            S_AXI_ARREADY <= 1'b1;
            S_AXI_RVALID  <= 1'b0;
            S_AXI_RRESP   <= AXI_RESP_OKAY;
            S_AXI_RDATA   <= '0;

            start_pulse   <= 1'b0;
            done_sticky   <= 1'b0;
        end
        else begin
            start_pulse <= 1'b0;

            if (fft_done)
                done_sticky <= 1'b1;

            if (S_AXI_BVALID && S_AXI_BREADY) begin
                S_AXI_BVALID  <= 1'b0;
                S_AXI_AWREADY <= 1'b1;
                S_AXI_WREADY  <= 1'b1;
            end

            if (S_AXI_RVALID && S_AXI_RREADY) begin
                S_AXI_RVALID  <= 1'b0;
                S_AXI_ARREADY <= 1'b1;
            end

            if (S_AXI_AWREADY && S_AXI_WREADY && S_AXI_AWVALID && S_AXI_WVALID) begin
                S_AXI_AWREADY <= 1'b0;
                S_AXI_WREADY  <= 1'b0;
                S_AXI_BVALID  <= 1'b1;
                S_AXI_BRESP   <= AXI_RESP_OKAY;

                if (S_AXI_AWADDR == CTRL_ADDR) begin
                    if (S_AXI_WSTRB[0] && S_AXI_WDATA[0]) begin
                        if (!fft_busy) begin
                            start_pulse <= 1'b1;
                            done_sticky <= 1'b0;
                        end
                        else begin
                            S_AXI_BRESP <= AXI_RESP_SLVERR;
                        end
                    end
                end
                else begin
                    S_AXI_BRESP <= AXI_RESP_SLVERR;
                end
            end

            if (S_AXI_ARREADY && S_AXI_ARVALID) begin
                S_AXI_ARREADY <= 1'b0;
                S_AXI_RVALID  <= 1'b1;
                S_AXI_RRESP   <= AXI_RESP_OKAY;

                if (S_AXI_ARADDR == STATUS_ADDR)
                    S_AXI_RDATA <= {30'd0, fft_busy, done_sticky};
                else if (S_AXI_ARADDR == CTRL_ADDR)
                    S_AXI_RDATA <= 32'd0;
                else begin
                    S_AXI_RDATA <= 32'hDEAD_BEEF;
                    S_AXI_RRESP <= AXI_RESP_SLVERR;
                end
            end
        end
    end

endmodule