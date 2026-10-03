`default_nettype none
module adc_sampling_scheduler #(
  parameter integer CLK_FREQ_HZ    = 50_000_000,
  parameter integer SAMPLE_RATE_HZ = 250
)(
  input logic clk,
  input logic rst_n,
  input logic i_enable,
  input logic i_acq_done,
  output logic o_periodic_req
);
  import adc_pkg::*;
  initial begin
    if (CLK_FREQ_HZ <= 0 || SAMPLE_RATE_HZ <= 0)
      $error("adc_sampling_scheduler: frequencies must be > 0");
    if (CLK_FREQ_HZ < SAMPLE_RATE_HZ)
      $error("adc_sampling_scheduler: CLK_FREQ_HZ must be >= SAMPLE_RATE_HZ");
  end

  localparam integer CYCLES_PER_SAMPLE_RAW = CLK_FREQ_HZ / SAMPLE_RATE_HZ;
  localparam integer CYCLES_PER_SAMPLE =
      (CYCLES_PER_SAMPLE_RAW < 1) ? 1 : CYCLES_PER_SAMPLE_RAW;
  localparam integer CTR_W = (CYCLES_PER_SAMPLE <= 1) ? 1 : $clog2(CYCLES_PER_SAMPLE);

  sched_state_t state;
  logic [CTR_W-1:0] count;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state          <= SCHED_IDLE;
      count          <= '0;
      o_periodic_req <= 1'b0;
    end else begin
      o_periodic_req <= 1'b0;
      case (state)
        SCHED_IDLE: begin
          count <= '0;
          if (i_enable) state <= SCHED_COUNT;
        end
        SCHED_COUNT: begin
          if (!i_enable) begin
            count <= '0;
            state <= SCHED_IDLE;
          end else if (CYCLES_PER_SAMPLE == 1) begin
            o_periodic_req <= 1'b1;
            state <= SCHED_WAIT;
            count <= '0;
          end else if (count == CYCLES_PER_SAMPLE-1) begin
            count <= '0;
            o_periodic_req <= 1'b1;
            state <= SCHED_WAIT;
          end else begin
            count <= count + 1'b1;
          end
        end
        SCHED_WAIT: begin
          if (!i_enable) begin
            state <= SCHED_IDLE;
            count <= '0;
          end else if (i_acq_done) begin
            state <= SCHED_COUNT;
            count <= '0;
          end
        end
        default: begin
          state <= SCHED_IDLE;
          count <= '0;
        end
      endcase
    end
  end
endmodule
`default_nettype wire
