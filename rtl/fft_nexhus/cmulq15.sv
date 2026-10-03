`timescale 1ns / 1ps

// ============================================================================
// Module Name : cmulq15
// Author      : Soroush Javed Sulehri
//
// Description :
//   Complex multiply for signed 16-bit fixed-point values with 15 fractional
//   bits, producing the same format at the output with rounding and
//   saturation.
//   A = a_real + j*a_imag
//   B = b_real + j*b_imag
//
//   real_acc = arbr - aibi
//   imag_acc = arbi + aibr
//   y_real   = sat16(real_acc >>> 15)
//   y_imag   = sat16(imag_acc >>> 15)
//
//   NOTE: The implementation adds + (1<<14) before >>> 15, so the reduction
//         back to 15 fractional bits is rounded instead of truncated.
// ============================================================================

module cmulq15 (
    input  logic signed [15:0] a_real,
    input  logic signed [15:0] a_imag,
    input  logic signed [15:0] b_real,
    input  logic signed [15:0] b_imag,
    output logic signed [15:0] y_real,
    output logic signed [15:0] y_imag
);

    // 16x16 -> 32-bit signed products
    logic signed [31:0] arbr;
    logic signed [31:0] aibi;
    logic signed [31:0] arbi;
    logic signed [31:0] aibr;

    assign arbr = a_real * b_real;
    assign aibi = a_imag * b_imag;
    assign arbi = a_real * b_imag;
    assign aibr = a_imag * b_real;

    // 33-bit accumulators (sign-extended)
    logic signed [32:0] real_acc;
    logic signed [32:0] imag_acc;

    assign real_acc = {arbr[31], arbr} - {aibi[31], aibi};
    assign imag_acc = {arbi[31], arbi} + {aibr[31], aibr};

    // Add + (1<<14) before shifting to round back to 15 fractional bits.

    logic signed [32:0] real_acc_rnd, imag_acc_rnd;
    logic signed [32:0] real_q15_wide, imag_q15_wide;

    assign real_acc_rnd = real_acc + 33'sd16384; // 1<<14
    assign imag_acc_rnd = imag_acc + 33'sd16384; // 1<<14

    assign real_q15_wide = real_acc_rnd >>> 15;
    assign imag_q15_wide = imag_acc_rnd >>> 15;

    // Saturation to signed 16-bit
    function automatic logic signed [15:0] sat16 (input logic signed [32:0] x);
        begin
            if (x > 33'sd32767)
                sat16 = 16'sd32767;
            else if (x < -33'sd32768)
                sat16 = -16'sd32768;
            else
                sat16 = x[15:0];
        end
    endfunction

    assign y_real = sat16(real_q15_wide);
    assign y_imag = sat16(imag_q15_wide);

endmodule
