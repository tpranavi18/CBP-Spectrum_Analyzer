`timescale 1ns / 1ps

module bram_memeory#(
    parameter int N = 1024,
    parameter int DATA_W = 32,
    parameter int AW = $clog2(N)
)(
    input  logic              clk,

    // Port A
    input  logic              en_a,
    input  logic              we_a,
    input  logic [AW-1:0]     addr_a,
    input  logic [DATA_W-1:0] din_a,
    output logic [DATA_W-1:0] dout_a,

    // Port B
    input  logic              en_b,
    input  logic              we_b,
    input  logic [AW-1:0]     addr_b,
    input  logic [DATA_W-1:0] din_b,
    output logic [DATA_W-1:0] dout_b
);

    logic [DATA_W-1:0] dout_a_i;
    logic [DATA_W-1:0] dout_b_i;

    xpm_memory_tdpram #(
        .ADDR_WIDTH_A(AW),
        .ADDR_WIDTH_B(AW),
        .AUTO_SLEEP_TIME(0),
        .BYTE_WRITE_WIDTH_A(DATA_W),
        .BYTE_WRITE_WIDTH_B(DATA_W),
        //.CASCADE_HEIGHT(0),
        .CLOCKING_MODE("common_clock"),
        .ECC_MODE("no_ecc"),
        .MEMORY_INIT_FILE("none"),
        .MEMORY_INIT_PARAM("0"),
        .MEMORY_OPTIMIZATION("true"),
        .MEMORY_PRIMITIVE("block"),
        .MEMORY_SIZE(N * DATA_W),
        .MESSAGE_CONTROL(0),
        .READ_DATA_WIDTH_A(DATA_W),
        .READ_DATA_WIDTH_B(DATA_W),
        .READ_LATENCY_A(1),
        .READ_LATENCY_B(1),
        .READ_RESET_VALUE_A("0"),
        .READ_RESET_VALUE_B("0"),
        .RST_MODE_A("SYNC"),
        .RST_MODE_B("SYNC"),
        //.SIM_ASSERT_CHK(0),
        .USE_EMBEDDED_CONSTRAINT(0),
        .USE_MEM_INIT(0),
        .WAKEUP_TIME("disable_sleep"),
        .WRITE_DATA_WIDTH_A(DATA_W),
        .WRITE_DATA_WIDTH_B(DATA_W),
        .WRITE_MODE_A("read_first"),
        .WRITE_MODE_B("read_first")
    ) u_mem (
        .clka(clk),
        .clkb(clk),

        .ena(en_a),
        .enb(en_b),

        .addra(addr_a),
        .addrb(addr_b),

        .dina(din_a),
        .dinb(din_b),

        .wea(we_a),
        .web(we_b),

        .douta(dout_a_i),
        .doutb(dout_b_i),

        .rsta(1'b0),
        .rstb(1'b0),
        .regcea(1'b1),
        .regceb(1'b1),

        .injectdbiterra(1'b0),
        .injectsbiterra(1'b0),
        .injectdbiterrb(1'b0),
        .injectsbiterrb(1'b0),
        .sleep(1'b0),
        .sbiterra(),
        .dbiterra(),
        .sbiterrb(),
        .dbiterrb()
    );

    assign dout_a = dout_a_i;
    assign dout_b = dout_b_i;

endmodule
