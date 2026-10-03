`timescale 1ns / 1ps

// ============================================================================
// Module Name : add_sub_sat_s1_q15
// File        : add_sub_sat_s1_q15.sv
// Author      : Soroush Javed Sulehri
//
// Description :
//   This module implements a butterfly add/subtract stage for signed 16-bit
//   fixed-point values with 15 fractional bits, including scaling and
//   saturation for FFT/IFFT datapaths.
//
//   Given complex inputs A = (a_real, a_imag) and T = (t_real, t_imag):
//
//     y0 = sat16( (A + T) >>> 1 )   // scaled sum
//     y1 = sat16( (A - T) >>> 1 )   // scaled difference
//
//   Key features:
//     - 16-bit signed arithmetic with 15 fractional bits
//     - Internal widening to 17 bits to preserve precision
//     - Arithmetic right shift by 1 for stage-wise scaling
//     - Saturation to prevent overflow (±32767 / -32768)
//     - Fully combinational (no clock, no latency)
//
//   This block is typically used after a complex multiply in radix-2
//   decimation-in-time (DIT) FFT architectures to control growth and
//   maintain numerical stability.
//
// ============================================================================

module add_sub_sat_s1_q15 (
    input  logic signed [15:0] a_real,
    input  logic signed [15:0] a_imag,
    input  logic signed [15:0] t_real,
    input  logic signed [15:0] t_imag,
    output logic signed [15:0] y0_real,
    output logic signed [15:0] y0_imag,
    output logic signed [15:0] y1_real,
    output logic signed [15:0] y1_imag
);

    // widen for sum/diff: 16-bit + 16-bit -> 17-bit
    logic signed [16:0] sum_real;
    logic signed [16:0] sum_imag;
    logic signed [16:0] diff_real;
    logic signed [16:0] diff_imag;

    assign sum_real  = {a_real[15], a_real} + {t_real[15], t_real};
    assign sum_imag  = {a_imag[15], a_imag} + {t_imag[15], t_imag};
    assign diff_real = {a_real[15], a_real} - {t_real[15], t_real};
    assign diff_imag = {a_imag[15], a_imag} - {t_imag[15], t_imag};

    // arithmetic shift right by 1 (divide by 2, sign-preserving)
    logic signed [16:0] sum_real_s1;
    logic signed [16:0] sum_imag_s1;
    logic signed [16:0] diff_real_s1;
    logic signed [16:0] diff_imag_s1;

    assign sum_real_s1  = sum_real  >>> 1;
    assign sum_imag_s1  = sum_imag  >>> 1;
    assign diff_real_s1 = diff_real >>> 1;
    assign diff_imag_s1 = diff_imag >>> 1;

    // sat16 for 17-bit input: only overflow if top two bits differ
    logic sum_real_ovf_pos,  sum_real_ovf_neg;
    logic sum_imag_ovf_pos,  sum_imag_ovf_neg;
    logic diff_real_ovf_pos, diff_real_ovf_neg;
    logic diff_imag_ovf_pos, diff_imag_ovf_neg;

    assign sum_real_ovf_pos  = (sum_real_s1[16] == 1'b0) && (sum_real_s1[15] == 1'b1);
    assign sum_real_ovf_neg  = (sum_real_s1[16] == 1'b1) && (sum_real_s1[15] == 1'b0);

    assign sum_imag_ovf_pos  = (sum_imag_s1[16] == 1'b0) && (sum_imag_s1[15] == 1'b1);
    assign sum_imag_ovf_neg  = (sum_imag_s1[16] == 1'b1) && (sum_imag_s1[15] == 1'b0);

    assign diff_real_ovf_pos = (diff_real_s1[16] == 1'b0) && (diff_real_s1[15] == 1'b1);
    assign diff_real_ovf_neg = (diff_real_s1[16] == 1'b1) && (diff_real_s1[15] == 1'b0);

    assign diff_imag_ovf_pos = (diff_imag_s1[16] == 1'b0) && (diff_imag_s1[15] == 1'b1);
    assign diff_imag_ovf_neg = (diff_imag_s1[16] == 1'b1) && (diff_imag_s1[15] == 1'b0);

    // Saturated outputs (pure combinational)
    assign y0_real = sum_real_ovf_pos  ?  16'sd32767 :
                     sum_real_ovf_neg  ? -16'sd32768 :
                     sum_real_s1[15:0];

    assign y0_imag = sum_imag_ovf_pos  ?  16'sd32767 :
                     sum_imag_ovf_neg  ? -16'sd32768 :
                     sum_imag_s1[15:0];

    assign y1_real = diff_real_ovf_pos ?  16'sd32767 :
                     diff_real_ovf_neg ? -16'sd32768 :
                     diff_real_s1[15:0];

    assign y1_imag = diff_imag_ovf_pos ?  16'sd32767 :
                     diff_imag_ovf_neg ? -16'sd32768 :
                     diff_imag_s1[15:0];

endmodule
