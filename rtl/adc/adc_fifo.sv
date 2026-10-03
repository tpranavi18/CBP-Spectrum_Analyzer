`default_nettype none
module adc_fifo #(
  parameter integer DATA_WIDTH = 12,
  parameter integer DEPTH      = 32
)(
  input logic clk,
  input logic rst_n,
  input logic wr_en,
  input logic [DATA_WIDTH-1:0] wr_data,
  input logic rd_en,
  output logic [DATA_WIDTH-1:0] rd_data,
  input logic clr,
  output logic empty,
  output logic full,
  output logic overflow
);
  initial begin
    if (DEPTH < 2 || (DEPTH & (DEPTH-1)) != 0)
      $error("adc_fifo: DEPTH must be a power of 2 and >= 2");
  end

  localparam integer PTR_W = $clog2(DEPTH);
  logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
  logic [PTR_W:0] wr_ptr, rd_ptr;

  assign empty = (wr_ptr == rd_ptr);
  assign full  = (wr_ptr[PTR_W] != rd_ptr[PTR_W]) &&
                 (wr_ptr[PTR_W-1:0] == rd_ptr[PTR_W-1:0]);

  // Head is continuously visible. A FIFO_DATA AXI read captures this value
  // and simultaneously causes rd_en/pop, so the returned word is the word
  // that was oldest immediately before the pop.
  always_comb begin
    if (empty) rd_data = '0;
    else       rd_data = mem[rd_ptr[PTR_W-1:0]];
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_ptr   <= '0;
      overflow <= 1'b0;
    end else if (clr) begin
      wr_ptr   <= '0;
      overflow <= 1'b0;
    end else if (wr_en) begin
      if (!full) begin
        mem[wr_ptr[PTR_W-1:0]] <= wr_data;
        wr_ptr <= wr_ptr + 1'b1;
      end else begin
        overflow <= 1'b1;
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rd_ptr <= '0;
    end else if (clr) begin
      rd_ptr <= '0;
    end else if (rd_en && !empty) begin
      rd_ptr <= rd_ptr + 1'b1;
    end
  end
endmodule
`default_nettype wire
