`timescale 1ns/1ps

module axis_fifo #(
    parameter DATA_WIDTH = 16,
    parameter FIFO_DEPTH = 16
)(
    input clk,
    input rst_n,

    input s_axis_tvalid,
    output s_axis_tready,
    input [DATA_WIDTH-1:0] s_axis_tdata,

    output m_axis_tvalid,
    input m_axis_tready,
    output [DATA_WIDTH-1:0] m_axis_tdata,

    output full,
    output empty
);

    localparam PTR_WIDTH = (FIFO_DEPTH <= 1) ? 1 : $clog2(FIFO_DEPTH);
    localparam CNT_WIDTH = $clog2(FIFO_DEPTH + 1);

    reg [DATA_WIDTH-1:0] fifo [0:FIFO_DEPTH-1];
    reg [PTR_WIDTH-1:0] wr_ptr;
    reg [PTR_WIDTH-1:0] rd_ptr;
    reg [CNT_WIDTH-1:0] count;

    wire write_enable;
    wire read_enable;

    assign full = (count == FIFO_DEPTH);
    assign empty = (count == 0);

    // Permit a write on the same cycle as a read from a full FIFO.
    assign s_axis_tready = !full || (m_axis_tvalid && m_axis_tready);
    assign m_axis_tvalid = !empty;
    assign m_axis_tdata = fifo[rd_ptr];

    assign write_enable = s_axis_tvalid && s_axis_tready;
    assign read_enable = m_axis_tvalid && m_axis_tready;

    function [PTR_WIDTH-1:0] next_ptr;
        input [PTR_WIDTH-1:0] ptr;
        begin
            if (ptr == FIFO_DEPTH - 1)
                next_ptr = 0;
            else
                next_ptr = ptr + 1'b1;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            count <= 0;
        end else begin
            if (write_enable) begin
                fifo[wr_ptr] <= s_axis_tdata;
                wr_ptr <= next_ptr(wr_ptr);
            end

            if (read_enable)
                rd_ptr <= next_ptr(rd_ptr);

            case ({write_enable, read_enable})
                2'b10: count <= count + 1'b1;
                2'b01: count <= count - 1'b1;
                default: count <= count;
            endcase
        end
    end

endmodule
