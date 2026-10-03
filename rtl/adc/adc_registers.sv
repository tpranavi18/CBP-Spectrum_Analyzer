`default_nettype none
module adc_registers #(
  parameter integer ADC_RESOLUTION = 12
)(
  input  logic clk,
  input  logic rst_n,

  input  logic        reg_wr_en,
  input  logic [31:0] reg_wr_addr,
  input  logic [31:0] reg_wr_data,
  input  logic [3:0]  reg_wr_strb,
  input  logic        reg_rd_en,
  input  logic [31:0] reg_rd_addr,
  output logic [31:0] reg_rd_data,
  output logic        reg_wr_slverr,
  output logic        reg_rd_slverr,

  input  logic                         i_busy,
  input  logic                         i_fifo_empty,
  input  logic                         i_fifo_full,
  input  logic [ADC_RESOLUTION-1:0]   i_sample_data,
  input  logic                         i_fifo_rd_data_valid,
  input  logic [ADC_RESOLUTION-1:0]   i_fifo_rd_data,
  input  logic                         i_done_pulse,
  input  logic                         i_overrun_pulse,
  input  logic                         i_reqerr_pulse,

  output logic o_enable,
  output logic o_start,
  output logic o_irq_sample_en,
  output logic o_irq_overrun_en,
  output logic o_fifo_pop,

  output logic irq_sample,
  output logic irq_overrun
);
  import adc_pkg::*;

  logic r_enable;
  logic r_irq_sample_en, r_irq_overrun_en;
  logic r_done, r_overrun, r_reqerr;

  function automatic logic [31:0] merge_strb(
    input logic [31:0] oldv,
    input logic [31:0] newv,
    input logic [3:0] strb
  );
    logic [31:0] tmp;
    begin
      tmp = oldv;
      for (int i=0; i<4; i++)
        if (strb[i]) tmp[i*8 +: 8] = newv[i*8 +: 8];
      return tmp;
    end
  endfunction

  function automatic logic valid_read_addr(input logic [31:0] a);
    return (a == OFFSET_CTRL) ||
           (a == OFFSET_STATUS) ||
           (a == OFFSET_SAMPLE_DATA) ||
           (a == OFFSET_FIFO_DATA) ||
           (a == OFFSET_IRQ_EN);
  endfunction

  function automatic logic valid_write_addr(input logic [31:0] a);
    return (a == OFFSET_CTRL) ||
           (a == OFFSET_STATUS) ||
           (a == OFFSET_IRQ_EN);
  endfunction

  assign reg_wr_slverr = reg_wr_en && !valid_write_addr(reg_wr_addr);
  assign reg_rd_slverr = reg_rd_en && !valid_read_addr(reg_rd_addr);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      r_enable         <= 1'b0;
      r_irq_sample_en  <= 1'b0;
      r_irq_overrun_en <= 1'b0;
      r_done           <= 1'b0;
      r_overrun        <= 1'b0;
      r_reqerr         <= 1'b0;
      o_start          <= 1'b0;
      o_fifo_pop       <= 1'b0;
    end else begin
      logic [31:0] merged;
      o_start    <= 1'b0;
      o_fifo_pop <= 1'b0;

      // W1C first; a new event in the same cycle wins so it is not lost.
      if (reg_wr_en && reg_wr_addr == OFFSET_STATUS) begin
        if (reg_wr_strb[0] && reg_wr_data[STAT_DONE_BIT])    r_done    <= 1'b0;
        if (reg_wr_strb[0] && reg_wr_data[STAT_OVERRUN_BIT]) r_overrun <= 1'b0;
        if (reg_wr_strb[0] && reg_wr_data[STAT_REQERR_BIT])  r_reqerr  <= 1'b0;
      end

      if (i_done_pulse)    r_done    <= 1'b1;
      if (i_overrun_pulse) r_overrun <= 1'b1;
      if (i_reqerr_pulse)  r_reqerr  <= 1'b1;

      if (reg_wr_en) begin
        case (reg_wr_addr)
          OFFSET_CTRL: begin
            merged = merge_strb({31'b0,r_enable}, reg_wr_data, reg_wr_strb);
            r_enable <= merged[CTRL_ENABLE_BIT];
            if (merged[CTRL_START_BIT]) o_start <= 1'b1;
          end
          OFFSET_IRQ_EN: begin
            merged = merge_strb({30'b0,r_irq_overrun_en,r_irq_sample_en},
                                reg_wr_data, reg_wr_strb);
            r_irq_sample_en  <= merged[IRQ_SAMPLE_EN_BIT];
            r_irq_overrun_en <= merged[IRQ_OVERRUN_EN_BIT];
          end
          default: begin end
        endcase
      end

      // FIFO_DATA read causes exactly one pop only when data exists.
      if (reg_rd_en && (reg_rd_addr == OFFSET_FIFO_DATA) &&
          i_fifo_rd_data_valid)
        o_fifo_pop <= 1'b1;
    end
  end

  always_comb begin
    reg_rd_data = 32'h0;
    case (reg_rd_addr)
      OFFSET_CTRL: begin
        reg_rd_data[CTRL_ENABLE_BIT] = r_enable;
        // START is a write-one pulse and always reads as zero.
      end
      OFFSET_STATUS: begin
        reg_rd_data[STAT_BUSY_BIT]    = i_busy;
        reg_rd_data[STAT_DONE_BIT]    = r_done;
        reg_rd_data[STAT_FEMPTY_BIT]  = i_fifo_empty;
        reg_rd_data[STAT_FFULL_BIT]   = i_fifo_full;
        reg_rd_data[STAT_OVERRUN_BIT] = r_overrun;
        reg_rd_data[STAT_REQERR_BIT]  = r_reqerr;
      end
      OFFSET_SAMPLE_DATA:
        reg_rd_data[ADC_RESOLUTION-1:0] = i_sample_data;
      OFFSET_FIFO_DATA: begin
        if (i_fifo_rd_data_valid)
          reg_rd_data[ADC_RESOLUTION-1:0] = i_fifo_rd_data;
      end
      OFFSET_IRQ_EN: begin
        reg_rd_data[IRQ_SAMPLE_EN_BIT]  = r_irq_sample_en;
        reg_rd_data[IRQ_OVERRUN_EN_BIT] = r_irq_overrun_en;
      end
      default: reg_rd_data = 32'h0;
    endcase
  end

  assign o_enable         = r_enable;
  assign o_irq_sample_en  = r_irq_sample_en;
  assign o_irq_overrun_en = r_irq_overrun_en;

  assign irq_sample  = r_done    & r_irq_sample_en;
  assign irq_overrun = r_overrun & r_irq_overrun_en;
endmodule
`default_nettype wire
