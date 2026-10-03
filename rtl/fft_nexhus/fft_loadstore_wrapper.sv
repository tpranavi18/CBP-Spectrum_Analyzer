`timescale 1ns / 1ps

module fft_loadstore_wrapper #(
    parameter int N = 1024
)(
    input  logic                 clk,
    input  logic                 rst_n,

    input  logic                 start,
    output logic                 done,
    output logic                 busy,

    input  logic                 wr_en,
    input  logic [$clog2(N)-1:0] wr_addr,
    input  logic [31:0]          wr_data,

    input  logic [$clog2(N)-1:0] rd_addr,
    output logic [31:0]          rd_data
);

    logic core_wr_en;
    logic [31:0] core_rd_data;

    assign core_wr_en = wr_en & ~busy;
    assign rd_data    = core_rd_data;

    fft_top #(
        .N(N)
    ) u_fft_top (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (start),
        .done     (done),
        .busy     (busy),

        .ext_we   (core_wr_en),
        .ext_waddr(wr_addr),
        .ext_wdata(wr_data),
        .ext_raddr(rd_addr),
        .ext_rdata(core_rd_data)
    );

endmodule
