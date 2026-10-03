`timescale 1ns / 1ps

module xpm_memory_tdpram #(
    parameter int ADDR_WIDTH_A = 10,
    parameter int ADDR_WIDTH_B = 10,
    parameter int BYTE_WRITE_WIDTH_A = 32,
    parameter int BYTE_WRITE_WIDTH_B = 32,
    parameter string CLOCKING_MODE = "common_clock",
    parameter string ECC_MODE = "no_ecc",
    parameter string MEMORY_INIT_FILE = "none",
    parameter string MEMORY_INIT_PARAM = "0",
    parameter string MEMORY_PRIMITIVE = "block",
    parameter int MEMORY_SIZE = 32768,
    parameter int READ_DATA_WIDTH_A = 32,
    parameter int READ_DATA_WIDTH_B = 32,
    parameter int READ_LATENCY_A = 1,
    parameter int READ_LATENCY_B = 1,
    parameter string READ_RESET_VALUE_A = "0",
    parameter string READ_RESET_VALUE_B = "0",
    parameter string RST_MODE_A = "SYNC",
    parameter string RST_MODE_B = "SYNC",
    parameter int USE_MEM_INIT = 0,
    parameter string WRITE_MODE_A = "read_first",
    parameter string WRITE_MODE_B = "read_first",
    parameter int AUTO_SLEEP_TIME = 0,
    parameter int MESSAGE_CONTROL = 0,
    parameter int USE_EMBEDDED_CONSTRAINT = 0,
    parameter string WAKEUP_TIME = "disable_sleep",
    parameter string MEMORY_OPTIMIZATION = "true"
)(
    input  logic clka,
    input  logic clkb,

    input  logic ena,
    input  logic enb,

    input  logic [ADDR_WIDTH_A-1:0] addra,
    input  logic [ADDR_WIDTH_B-1:0] addrb,

    input  logic [READ_DATA_WIDTH_A-1:0] dina,
    input  logic [READ_DATA_WIDTH_B-1:0] dinb,

    input  logic wea,
    input  logic web,

    output logic [READ_DATA_WIDTH_A-1:0] douta,
    output logic [READ_DATA_WIDTH_B-1:0] doutb,

    input  logic rsta,
    input  logic rstb,

    input  logic regcea,
    input  logic regceb,

    input  logic injectdbiterra,
    input  logic injectsbiterra,
    input  logic injectdbiterrb,
    input  logic injectsbiterrb,

    input  logic sleep,

    output logic sbiterra,
    output logic dbiterra,
    output logic sbiterrb,
    output logic dbiterrb
);

    localparam int DEPTH = MEMORY_SIZE / READ_DATA_WIDTH_A;

    logic [READ_DATA_WIDTH_A-1:0] mem [0:DEPTH-1];

    logic [READ_DATA_WIDTH_A-1:0] douta_reg;
    logic [READ_DATA_WIDTH_B-1:0] doutb_reg;

    integer i;

    /*
     * Simulation-only initialization.
     */
    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = '0;
    end

    /*
     * Port A
     * Common clock, synchronous read,
     * one-cycle read latency, read-first behavior.
     */
    always @(posedge clka) begin
        if (rsta) begin
            douta_reg <= '0;
        end
        else if (ena) begin
            if (wea) begin
                douta_reg <= mem[addra];
                mem[addra] <= dina;
            end
            else begin
                douta_reg <= mem[addra];
            end
        end
    end

    /*
     * Port B
     * Common clock, synchronous read,
     * one-cycle read latency, read-first behavior.
     */
    always @(posedge clkb) begin
        if (rstb) begin
            doutb_reg <= '0;
        end
        else if (enb) begin
            if (web) begin
                doutb_reg <= mem[addrb];
                mem[addrb] <= dinb;
            end
            else begin
                doutb_reg <= mem[addrb];
            end
        end
    end

    assign douta = douta_reg;
    assign doutb = doutb_reg;

    /*
     * ECC/error outputs are unused by NEXHUS.
     */
    assign sbiterra = 1'b0;
    assign dbiterra = 1'b0;
    assign sbiterrb = 1'b0;
    assign dbiterrb = 1'b0;

endmodule
