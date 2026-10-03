`default_nettype none
package adc_pkg;
  localparam int AXI_ADDR_WIDTH = 32;
  localparam int AXI_DATA_WIDTH = 32;
  localparam int AXI_STRB_WIDTH = 4;

  localparam logic [31:0] OFFSET_CTRL        = 32'h0000_0000;
  localparam logic [31:0] OFFSET_STATUS      = 32'h0000_0004;
  localparam logic [31:0] OFFSET_SAMPLE_DATA = 32'h0000_0008;
  localparam logic [31:0] OFFSET_FIFO_DATA   = 32'h0000_000C;
  localparam logic [31:0] OFFSET_IRQ_EN      = 32'h0000_0010;

  localparam int CTRL_ENABLE_BIT = 0;
  localparam int CTRL_START_BIT  = 1;

  localparam int STAT_BUSY_BIT    = 0;
  localparam int STAT_DONE_BIT    = 1;
  localparam int STAT_FEMPTY_BIT  = 2;
  localparam int STAT_FFULL_BIT   = 3;
  localparam int STAT_OVERRUN_BIT = 4;
  localparam int STAT_REQERR_BIT  = 5;

  localparam int IRQ_SAMPLE_EN_BIT  = 0;
  localparam int IRQ_OVERRUN_EN_BIT = 1;

  localparam logic [1:0] AXI_RESP_OKAY   = 2'b00;
  localparam logic [1:0] AXI_RESP_SLVERR = 2'b10;

  typedef enum logic [1:0] {
    ACQ_IDLE    = 2'b00,
    ACQ_WAIT    = 2'b01,
    ACQ_CAPTURE = 2'b10,
    ACQ_DONE    = 2'b11
  } acq_state_t;

  typedef enum logic [1:0] {
    SCHED_IDLE  = 2'b00,
    SCHED_COUNT = 2'b01,
    SCHED_WAIT  = 2'b10
  } sched_state_t;
endpackage
`default_nettype wire
