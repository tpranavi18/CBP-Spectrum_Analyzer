`timescale 1ns/1ps

module twiddle_rom #(
    parameter int N = 16
)(
    input  logic                     clk,
    input  logic [$clog2(N)-1:0]     tw_addr,
    output logic signed [31:0]       tw_data
);

    (* rom_style = "block" *) logic signed [31:0] rom [0:N-1];

    initial begin
        $readmemh("twiddle1024.mem", rom);
    end

    always_ff @(posedge clk) begin
        tw_data <= rom[tw_addr];
    end

endmodule