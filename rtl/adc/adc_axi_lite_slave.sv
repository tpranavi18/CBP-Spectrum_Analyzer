`default_nettype none
module adc_axi_lite_slave (
  input logic aclk,
  input logic aresetn,

  input logic [31:0] s_axi_awaddr,
  input logic        s_axi_awvalid,
  output logic       s_axi_awready,

  input logic [31:0] s_axi_wdata,
  input logic [3:0]  s_axi_wstrb,
  input logic        s_axi_wvalid,
  output logic       s_axi_wready,

  output logic [1:0] s_axi_bresp,
  output logic       s_axi_bvalid,
  input logic        s_axi_bready,

  input logic [31:0] s_axi_araddr,
  input logic        s_axi_arvalid,
  output logic       s_axi_arready,

  output logic [31:0] s_axi_rdata,
  output logic [1:0]  s_axi_rresp,
  output logic        s_axi_rvalid,
  input logic         s_axi_rready,

  output logic        reg_wr_en,
  output logic [31:0] reg_wr_addr,
  output logic [31:0] reg_wr_data,
  output logic [3:0]  reg_wr_strb,
  output logic        reg_rd_en,
  output logic [31:0] reg_rd_addr,
  input logic [31:0]  reg_rd_data,
  input logic         reg_wr_slverr,
  input logic         reg_rd_slverr
);
  import adc_pkg::*;

  typedef enum logic [1:0] {WR_IDLE, WR_COLLECT, WR_ISSUE, WR_RESP} wr_state_t;
  typedef enum logic [1:0] {RD_IDLE, RD_ISSUE, RD_RESP} rd_state_t;

  wr_state_t wr_state;
  rd_state_t rd_state;

  logic        aw_hold, w_hold;
  logic [31:0] awaddr_lat, wdata_lat;
  logic [3:0]  wstrb_lat;
  logic        wr_err_lat;

  logic [31:0] araddr_lat;
  logic [31:0] rdata_lat;
  logic [1:0]  rresp_lat;

  wire aw_hs = s_axi_awvalid && s_axi_awready;
  wire w_hs  = s_axi_wvalid  && s_axi_wready;
  wire ar_hs = s_axi_arvalid && s_axi_arready;

  always_comb begin
    s_axi_awready = 1'b0;
    s_axi_wready  = 1'b0;
    case (wr_state)
      WR_IDLE: begin
        s_axi_awready = 1'b1;
        s_axi_wready  = 1'b1;
      end
      WR_COLLECT: begin
        s_axi_awready = !aw_hold;
        s_axi_wready  = !w_hold;
      end
      default: begin end
    endcase
  end

  assign reg_wr_en   = (wr_state == WR_ISSUE);
  assign reg_wr_addr = awaddr_lat;
  assign reg_wr_data = wdata_lat;
  assign reg_wr_strb = wstrb_lat;

  assign s_axi_bvalid = (wr_state == WR_RESP);
  assign s_axi_bresp  = wr_err_lat ? AXI_RESP_SLVERR : AXI_RESP_OKAY;

  assign s_axi_arready = (rd_state == RD_IDLE);
  assign reg_rd_en     = (rd_state == RD_ISSUE);
  assign reg_rd_addr   = araddr_lat;

  assign s_axi_rvalid = (rd_state == RD_RESP);
  assign s_axi_rdata  = rdata_lat;
  assign s_axi_rresp  = rresp_lat;

  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      wr_state   <= WR_IDLE;
      aw_hold    <= 1'b0;
      w_hold     <= 1'b0;
      awaddr_lat <= '0;
      wdata_lat  <= '0;
      wstrb_lat  <= '0;
      wr_err_lat <= 1'b0;
    end else begin
      case (wr_state)
        WR_IDLE: begin
          aw_hold <= 1'b0;
          w_hold  <= 1'b0;
          if (aw_hs) begin
            awaddr_lat <= s_axi_awaddr;
            aw_hold <= 1'b1;
          end
          if (w_hs) begin
            wdata_lat <= s_axi_wdata;
            wstrb_lat <= s_axi_wstrb;
            w_hold <= 1'b1;
          end
          if (aw_hs && w_hs) begin
            wr_state <= WR_ISSUE;
          end else if (aw_hs || w_hs) begin
            wr_state <= WR_COLLECT;
          end
        end

        WR_COLLECT: begin
          if (aw_hs) begin
            awaddr_lat <= s_axi_awaddr;
            aw_hold <= 1'b1;
          end
          if (w_hs) begin
            wdata_lat <= s_axi_wdata;
            wstrb_lat <= s_axi_wstrb;
            w_hold <= 1'b1;
          end
          if ((aw_hold || aw_hs) && (w_hold || w_hs))
            wr_state <= WR_ISSUE;
        end

        WR_ISSUE: begin
          // reg_wr_en is high during this complete clock interval.
          // At this edge reg_wr_slverr reflects the issued transaction.
          wr_err_lat <= reg_wr_slverr;
          wr_state   <= WR_RESP;
        end

        WR_RESP: begin
          if (s_axi_bready) begin
            wr_state <= WR_IDLE;
            aw_hold  <= 1'b0;
            w_hold   <= 1'b0;
          end
        end
        default: wr_state <= WR_IDLE;
      endcase
    end
  end

  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      rd_state   <= RD_IDLE;
      araddr_lat <= '0;
      rdata_lat  <= '0;
      rresp_lat  <= AXI_RESP_OKAY;
    end else begin
      case (rd_state)
        RD_IDLE: begin
          if (ar_hs) begin
            araddr_lat <= s_axi_araddr;
            rd_state   <= RD_ISSUE;
          end
        end
        RD_ISSUE: begin
          // reg_rd_en is high during this interval; capture response now.
          rdata_lat <= reg_rd_slverr ? 32'h0 : reg_rd_data;
          rresp_lat <= reg_rd_slverr ? AXI_RESP_SLVERR : AXI_RESP_OKAY;
          rd_state  <= RD_RESP;
        end
        RD_RESP: begin
          if (s_axi_rready)
            rd_state <= RD_IDLE;
        end
        default: rd_state <= RD_IDLE;
      endcase
    end
  end
endmodule
`default_nettype wire
