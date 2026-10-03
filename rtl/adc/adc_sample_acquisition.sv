`default_nettype none
module adc_sample_acquisition #(
  parameter integer ADC_RESOLUTION = 12
)(
  input logic clk,
  input logic rst_n,
  input logic i_start,
  output logic o_busy,
  output logic o_done,
  output logic [ADC_RESOLUTION-1:0] o_sample,
  input logic [ADC_RESOLUTION-1:0] sample_in,
  input logic sample_valid
);
  import adc_pkg::*;
  acq_state_t state;
  logic [ADC_RESOLUTION-1:0] sample_reg;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= ACQ_IDLE;
      o_busy     <= 1'b0;
      o_done     <= 1'b0;
      sample_reg <= '0;
    end else begin
      o_done <= 1'b0;
      case (state)
        ACQ_IDLE: begin
          o_busy <= 1'b0;
          if (i_start) begin
            o_busy <= 1'b1;
            state  <= ACQ_WAIT;
          end
        end

        ACQ_WAIT: begin
          if (sample_valid) begin
            sample_reg <= sample_in;
            state      <= ACQ_CAPTURE;
          end
        end

        ACQ_CAPTURE: begin
          // sample_reg was updated in the previous cycle, so o_sample is
          // stable and valid when o_done is asserted.
          o_done <= 1'b1;
          state  <= ACQ_DONE;
        end

        ACQ_DONE: begin
          o_busy <= 1'b0;
          state  <= ACQ_IDLE;
        end

        default: begin
          state  <= ACQ_IDLE;
          o_busy <= 1'b0;
        end
      endcase
    end
  end

  assign o_sample = sample_reg;
endmodule
`default_nettype wire
