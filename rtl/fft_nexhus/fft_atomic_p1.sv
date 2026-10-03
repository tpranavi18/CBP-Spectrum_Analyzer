`timescale 1ns / 1ps

module fft_atomic_p1 (
    input  logic               clk,
    input  logic               rst_n,      // active-low reset
    input  logic               in_valid,

    // INPUTS
    input  logic signed [15:0] a_real,
    input  logic signed [15:0] a_imag,
    input  logic signed [15:0] b_real,
    input  logic signed [15:0] b_imag,
    input  logic signed [15:0] W_real,
    input  logic signed [15:0] W_imag,

    // OUTPUTS
    output logic signed [15:0] a_real_out,
    output logic signed [15:0] a_imag_out,
    output logic signed [15:0] b_real_out,
    output logic signed [15:0] b_imag_out,
    output logic               out_valid
);

    // -------------------------
    // Stage 0: combinational cmul
    // t = b * W using signed 16-bit fixed-point values with 15 fractional bits
    // -------------------------
    logic signed [15:0] t_real_c;
    logic signed [15:0] t_imag_c;

    cmulq15 u_cmul_q15 (
        .a_real (b_real),
        .a_imag (b_imag),
        .b_real (W_real),
        .b_imag (W_imag),
        .y_real (t_real_c),
        .y_imag (t_imag_c)
    );

    // -------------------------
    // Pipeline register (1-cycle)
    // Register t and a for alignment with the butterfly add/sub stage.
    // -------------------------
    logic signed [15:0] t_real_r, t_imag_r;
    logic signed [15:0] a_real_r, a_imag_r;
    logic               v_r;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            t_real_r <= 16'sd0;
            t_imag_r <= 16'sd0;
            a_real_r <= 16'sd0;
            a_imag_r <= 16'sd0;
            v_r      <= 1'b0;
        end else begin
            // valid pipeline
            v_r <= in_valid;

            // You can optionally gate these with in_valid to reduce toggling:
            // if (in_valid) begin ... end
            t_real_r <= t_real_c;
            t_imag_r <= t_imag_c;
            a_real_r <= a_real;
            a_imag_r <= a_imag;
        end
    end

    assign out_valid = v_r;

    // -------------------------
    // Stage 1: butterfly add/sub with saturation and >>>1 scaling
    //
    // y0 = sat16((a + t) >>> 1)
    // y1 = sat16((a - t) >>> 1)
    // -------------------------
    add_sub_sat_s1_q15 u_addsub (
        .a_real (a_real_r),
        .a_imag (a_imag_r),
        .t_real (t_real_r),
        .t_imag (t_imag_r),
        .y0_real(a_real_out),
        .y0_imag(a_imag_out),
        .y1_real(b_real_out),
        .y1_imag(b_imag_out)
    );

endmodule
